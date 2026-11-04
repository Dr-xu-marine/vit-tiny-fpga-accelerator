import json,sys
from pathlib import Path
def inspect(d):
 failed=d['initial_inference']['mismatch_values']!=0
 reset=bool(d.get('user_confirmed_intervening_action'))
 return {'numeric_status':'FAIL' if failed else 'PASS_CURRENT_CAPTURE_ONLY','root_cause':'UNKNOWN','post_reset_evidence_can_explain_original':False if reset else 'UNKNOWN','new_board_operations':'NOT_RUN'}
if __name__=='__main__':print(json.dumps(inspect(json.loads(Path(sys.argv[1]).read_text('utf8')))))
