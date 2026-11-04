import json,re,sys
from pathlib import Path
def timing(text):
 pattern=r'^\s*(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+(\d+)\s+(\d+)\s+(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+(\d+)\s+(\d+)\s+(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+(\d+)\s+(\d+)\s*$'
 rows=re.findall(pattern,text,re.M)
 if len(rows)!=1:raise ValueError('TIMING_SUMMARY_ROW_NOT_UNIQUE')
 keys=['WNS','TNS','setup_fail','setup_total','WHS','THS','hold_fail','hold_total','WPWS','TPWS','pulse_fail','pulse_total']
 return dict(zip(keys,[int(x) if i%4 in (2,3) else float(x) for i,x in enumerate(rows[0])]))
def gate(t):
 return 'PASS_TIMING_ONLY' if all(t[x]>=0 for x in ['WNS','WHS','WPWS']) and all(t[x]==0 for x in ['TNS','THS','TPWS','setup_fail','hold_fail','pulse_fail']) else 'FAIL'
if __name__=='__main__':
 t=timing(Path(sys.argv[1]).read_text());print(json.dumps({'status':gate(t),'metrics':t,'DRC_CDC_source_identity':'REQUIRES_SEPARATE_AUDIT'}))
