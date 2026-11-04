"""Host CPU image preprocessing; no inference/nonlinear arithmetic on Host.
Create a NEW DDR image by replacing ONLY the input blob of the frozen package.
"""
from pathlib import Path
import argparse,ctypes,json,hashlib
import numpy as np
from PIL import Image
R=Path(__file__).resolve().parents[1]
def sha(path):
 with Path(path).open('rb')as f:return hashlib.file_digest(f,'sha256').hexdigest()
def encode(normalized_patches):
 x=np.asarray(normalized_patches,np.float64)
 if x.shape!=(196,768)or not np.isfinite(x).all():raise ValueError('Expected frozen196x768 patch layout')
 p=np.rint((x+1)*127.5).astype(np.int64)
 if np.any(p<0)or np.any(p>255)or np.max(np.abs(p*(2/255)-1-x))>2e-7:raise ValueError('Not the frozen RGB8 normalization grid')
 return(p-128).astype(np.int8)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('image',type=Path);ap.add_argument('output',type=Path);args=ap.parse_args();output=args.output.resolve()
 if not output.is_relative_to(R):raise ValueError('Host outputs must stay within this independent candidate')
 contract=json.loads((R/'data/contract.json').read_text(encoding='utf-8'));config=json.loads((R/'data/preprocess.json').read_text(encoding='utf-8'))['config']
 assert contract['input_encoding']=='rgb_u8_minus_128'and contract['input_offset_folded_in_patch_bias']
 assert sha(R/'data/integer_parameters.npz')==contract['arrays_sha256']
 assert list(config['mean'])==[.5]*3 and list(config['std'])==[.5]*3
 K=ctypes.WinDLL('kernel32',use_last_error=True);K.SetProcessMitigationPolicy.argtypes=[ctypes.c_int,ctypes.c_void_p,ctypes.c_size_t];f=ctypes.c_uint32(1)
 if not K.SetProcessMitigationPolicy(6,ctypes.byref(f),ctypes.sizeof(f)):raise ctypes.WinError(ctypes.get_last_error())
 import torch
 from timm.data import create_transform
 torch.set_num_threads(2);transform=create_transform(**config,is_training=False)
 with Image.open(args.image)as im:x=transform(im.convert('RGB')).unsqueeze(0)
 patch=torch.nn.functional.unfold(x,16,stride=16).transpose(1,2)[0].numpy();q=encode(patch)
 p=json.loads((R/'data/package/package.json').read_text());blob=p['input_blob'];raw=bytearray((R/'data/package/ddr.bin').read_bytes());start=blob['offset'];n=blob['bytes'];assert n==q.nbytes
 original=bytes(raw);raw[start:start+n]=q.tobytes();assert raw[:start]==original[:start]and raw[start+n:]==original[start+n:]
 output.mkdir(parents=True,exist_ok=False);(output/'ddr.bin').write_bytes(raw);np.save(output/'patches.npy',q)
 out=dict(status='PASS',scope='Host preprocessing/DDR image generation only',image=str(args.image.resolve()),image_sha256=sha(args.image),ddr_sha256=sha(output/'ddr.bin'),input_blob_sha256=hashlib.sha256(q.tobytes()).hexdigest(),changed_blob='input_patch_codes',parameters_sha256=contract['arrays_sha256'],input_encoding=contract['input_encoding'],preprocess_config=config,classification='NOT_RUN',raw_bytes=n)
 (output/'INPUT.json').write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf-8');print('HOST_INPUT_READY',output)
if __name__=='__main__':main()
