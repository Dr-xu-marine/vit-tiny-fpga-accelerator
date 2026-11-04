"""Standalone full12 INTEGER inference. No torch, floating runtime or fixtures.
All learned/scaling constants are integer npz arrays. Host preprocessing is external.
"""
from pathlib import Path
import importlib.util,json,hashlib
import numpy as np
_sp=importlib.util.spec_from_file_location('canonical_ln',Path(__file__).with_name('integer_ln.py'));LN=importlib.util.module_from_spec(_sp);_sp.loader.exec_module(LN)
def rne_shift(x,shift):
 x=np.asarray(x,dtype=np.int64);s=np.asarray(shift,dtype=np.int64)
 if np.any(s<0)or np.any(s>62)or np.any(x==np.iinfo(np.int64).min):raise OverflowError('RNE domain')
 mag=np.abs(x);q=mag>>s;rem=mag-(q<<s);half=np.left_shift(np.ones_like(s),np.maximum(s-1,0));up=(s>0)&((rem>half)|((rem==half)&((q&1)!=0)))
 return np.where(x<0,-(q+up),q+up)
def rq_raw(x,m,shift,z=0):
 x=np.asarray(x,dtype=np.int64);m=np.asarray(m,dtype=np.int64)
 if np.any(x==np.iinfo(np.int64).min):raise OverflowError('INT64_MIN operand')
 if np.any(m<=0)or np.any(m>=1<<31):raise ValueError('U31 multiplier')
 # Prove before multiplication, not after an int64 wrap.
 if x.ndim>1:bound=np.abs(x).max(axis=0)
 else:bound=np.abs(x)
 bb,mm=np.broadcast_arrays(bound,m)
 if any(int(a)*int(b)>=1<<63 for a,b in zip(bb.flat,mm.flat)):raise OverflowError('requant product64')
 return rne_shift(x*m,shift)+np.asarray(z,dtype=np.int64)
def sat8(x):return np.clip(x,-128,127).astype(np.int8)
def div_rne(n,d):
 n=np.asarray(n,dtype=np.int64);d=np.asarray(d,dtype=np.int64)
 if np.any(n<0)or np.any(d<=0):raise ValueError('positive division')
 q,r=np.divmod(n,d);return q+((2*r>d)|((2*r==d)&((q&1)!=0)))
def load(directory):
 directory=Path(directory);meta=json.loads((directory/'contract.json').read_text(encoding='utf-8'));raw=directory/'integer_parameters.npz'
 with raw.open('rb')as f:assert hashlib.file_digest(f,'sha256').hexdigest()==meta['arrays_sha256']
 with np.load(raw,allow_pickle=False)as z:arrays={k:z[k].copy()for k in z.files}
 assert all(v.dtype.kind in 'iu'for v in arrays.values())
 return Model(meta,arrays)
class Model:
 def __init__(self,meta,arrays):self.meta=meta;self.a=arrays;self.trace={};self.counters={}
 def record(self,k,x):
  assert np.asarray(x).dtype.kind in 'iu',k
  self.trace[k]=np.asarray(x).copy();return x
 def linear(self,x,name):
  assert x.dtype==np.int8 and self.a[name+'.W'].dtype==np.int8
  acc=x.astype(np.int64)@self.a[name+'.W'].astype(np.int64).T
  if np.any(acc<-(1<<31))or np.any(acc>=1<<31):raise OverflowError('MAC32')
  total=acc+self.a[name+'.B']
  if np.any(total<-(1<<31))or np.any(total>=1<<31):raise OverflowError('Bias32')
  self.record(name+'.acc',acc.astype(np.int32))
  y=sat8(rq_raw(total,self.a[name+'.M'],self.a[name+'.R'],self.a[name+'.Z']))
  return self.record(name,y)
 def norm(self,x,index,name):
  a=self.a;prefix=name+'.';q=rq_raw(x.astype(np.int64),a[prefix+'MI'],a[prefix+'RI'])
  if np.any(q<-(1<<23))or np.any(q>=1<<23):raise OverflowError('LN Q13 input')
  ys=[]
  for row in q.tolist():
   y,_,_=LN.row(row,a[prefix+'G'].tolist(),a[prefix+'B'].tolist(),2473901,13,1,0,0);ys.append(y)
  y=np.asarray(ys,dtype=np.int64);out=sat8(rq_raw(y,a[prefix+'MO'],a[prefix+'RO'],a[prefix+'Z']))
  self.record(name+'.grid',q.astype(np.int32));return self.record(name,out)
 def residual(self,left,right,index):
  a=self.a;p=f'res{index}.';wide=left.astype(np.int64)*a[p+'A20']+right.astype(np.int64)*a[p+'B20']
  if np.any(wide<-(1<<39))or np.any(wide>=1<<39):raise OverflowError('Residual Q20')
  return self.record(f'residual{index}',sat8(rq_raw(wide,a[p+'M'],a[p+'R'])))
 def softmax(self,score,block,head):
  a=self.a;p=f'attn{block}.{head}.';scaled=rq_raw(score,a[p+'SM'],a[p+'SR'])
  if np.any(scaled<-(1<<31))or np.any(scaled>=1<<31):raise OverflowError('score Q10')
  diff=scaled.max(axis=-1,keepdims=True)-scaled;idx=np.minimum(diff,16384)
  exp=a['exp_Q30'][idx];exp=np.where(diff<=16384,exp,0).astype(np.int64);total=exp.sum(axis=-1,keepdims=True)
  out=div_rne(exp*255,total).astype(np.uint8)
  self.record(p+'score',score.astype(np.int32));return self.record(p+'prob',out)
 def infer(self,patches,capture=True):
  if patches.dtype!=np.int8 or patches.shape!=(196,768):raise ValueError('signed8 CHW patch matrix')
  self.trace={};a=self.a
  y=self.linear(patches,'patch_embed.proj');wide=np.zeros((197,192),dtype=np.int64);wide[1:]=y.astype(np.int64)*a['patch_Q20'];wide+=a['position_Q20']
  x=self.record('frontend',sat8(rq_raw(wide,a['front_M'],a['front_R'])))
  for i in range(12):
   n=f'blocks.{i}';v=self.norm(x,2*i,n+'.norm1');qkv=self.linear(v,n+'.attn.qkv').reshape(197,3,3,64);avs=[]
   for h in range(3):
    q=qkv[:,0,h,:].astype(np.int64);k=qkv[:,1,h,:].astype(np.int64);value=qkv[:,2,h,:].astype(np.int64)
    raw=q@k.T;prob=self.softmax(raw,i,h);av=prob.astype(np.int64)@value;p=f'attn{i}.{h}.'
    # Hardware uses signed(P-128) MAC plus EXACT dynamic 128*sum(V).
    signed_dot=(prob.astype(np.int64)-128)@value;assert np.array_equal(av,signed_dot+128*value.sum(axis=0))
    self.record(p+'av_acc',av.astype(np.int32));avs.append(self.record(p+'av',sat8(rq_raw(av,a[p+'AM'],a[p+'AR'],a[p+'AZ']))))
   projected=self.linear(np.concatenate(avs,axis=1),n+'.attn.proj');x=self.residual(x,projected,2*i)
   norm=self.norm(x,2*i+1,n+'.norm2');hidden=self.linear(norm,n+'.mlp.fc1');lut=a[n+'.gelu'];gelu=lut[np.arange(768)[None,:],hidden.astype(np.int16)+128]
   self.record(n+'.gelu',gelu);branch=self.linear(gelu,n+'.mlp.fc2');x=self.residual(x,branch,2*i+1)
  out=self.norm(x,24,'norm');logits=self.linear(out[:1],'head')[0]
  if not capture:self.trace={}
  return logits
