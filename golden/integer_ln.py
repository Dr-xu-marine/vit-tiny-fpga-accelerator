"""Integer-only runtime kernel. Floating conversions belong in offline/run.py.
Explicit errors, no wrap; Python int avoids accidental machine INT64 overflow.
"""
from math import isqrt
from fractions import Fraction
N=192
SCHEMES=[{'name':'S16_F10','bits':16,'frac':10},{'name':'S16_F12','bits':16,'frac':12},{'name':'S24_F16','bits':24,'frac':16}]
def rne(n,d):
    if d<=0:raise ValueError('positive denominator required')
    q,r=divmod(abs(int(n)),int(d))
    q+=int(2*r>d or (2*r==d and q&1))
    return -q if n<0 else q
def sqrt_restoring(n):
    if n<0:raise ValueError('negative variance')
    root=rem=0
    for pair in range((n.bit_length()+1)//2-1,-1,-1):
        rem=(rem<<2)|((n>>(2*pair))&3)
        trial=(root<<2)|1
        root<<=1
        if rem>=trial:rem-=trial;root+=1
    return root
def fit(v,bits):
    if not -(1<<(bits-1))<=v<(1<<(bits-1)):raise OverflowError((v,bits))
    return v
def note(stats,k,v):stats[k]=max(stats.get(k,0),abs(v))
def row(q,gamma,beta,epsilon_code,frac,mult,shift,zp,stats=None):
    if len(q)!=N or len(gamma)!=N or len(beta)!=N:raise ValueError('LN shape')
    if epsilon_code<1:raise ValueError('epsilon encoding must be positive')
    stats={}if stats is None else stats
    q=list(map(int,q));total=sum(q);sum2=sum(v*v for v in q)
    variance=N*sum2-total*total
    if variance<0:raise ArithmeticError('negative exact variance')
    w=variance+epsilon_code;root=sqrt_restoring(w<<16)
    inv=rne(1<<(frac+40),root)
    for key,v in [('sum',total),('sum_squares',sum2),('variance',variance),('variance_epsilon',w),('sqrt_operand',w<<16),('root',root),('inv',inv)]:note(stats,key,v)
    values=[];codes=[];saturations=0
    for x,g,b in zip(q,gamma,beta):
        d=N*x-total;np=d*inv
        norm=rne(np,1<<(frac+12)) # R=F+32, norm fractional bits20
        affine_product=norm*fit(int(g),32)
        y=fit(rne(affine_product,1<<20)+fit(int(b),32),40)
        product=y*mult;unbounded=rne(product,1<<shift)+zp
        code=max(-128,min(127,unbounded));saturations+=code!=unbounded
        values.append(y);codes.append(code)
        for key,v in [('centered_n',d),('normalize_product',np),('norm_q20',norm),('affine_product',affine_product),('ln_q20',y),('qkv_requant_product',product)]:note(stats,key,v)
    return values,codes,saturations
def audit_row(q,g,b,e,frac,m,shift,zp):
    # Independent standard-library isqrt and Fraction rounding, no row()/rne().
    t=sum(map(int,q));v=N*sum(int(x)**2 for x in q)-t*t+e
    r=isqrt(v<<16);inv=round(Fraction(1<<(frac+40),r))
    y=[round(Fraction(round(Fraction((N*int(x)-t)*inv,1<<(frac+12)))*int(a),1<<20))+int(bb)for x,a,bb in zip(q,g,b)]
    c=[max(-128,min(127,round(Fraction(x*m,1<<shift))+zp))for x in y]
    return y,c
