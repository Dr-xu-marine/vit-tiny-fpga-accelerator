import json,re,sys
from pathlib import Path
def codes(p):
 lines=Path(p).read_text().splitlines()
 if not lines or any(not re.fullmatch(r'[0-9a-fA-F]{2}',x.strip()) for x in lines):raise ValueError('INVALID_HEX_FORMAT')
 return [int(x,16) for x in lines]
def compare(a,b):
 bad=[i for i,(x,y) in enumerate(zip(a,b)) if x!=y]
 first=None
 if bad:
  i=bad[0];first={'index':i,'expected':a[i],'actual':b[i],'expected_signed':a[i] if a[i]<128 else a[i]-256,'actual_signed':b[i] if b[i]<128 else b[i]-256}
 return {'status':'PASS' if len(a)==len(b) and not bad else 'FAIL','expected_count':len(a),'actual_count':len(b),'mismatch_count':len(bad),'first_mismatch':first}
def native_gate(launcher,kernel,dumps):return 'PASS' if launcher==kernel==0 and not dumps else 'FAIL'
if __name__=='__main__':
 r=compare(codes(sys.argv[1]),codes(sys.argv[2]));print(json.dumps(r));sys.exit(0 if r['status']=='PASS' else 1)
