"""Offline re-read of saved evidence only. No RTL, tool, inference or hardware run."""
from pathlib import Path
import json, importlib.util
R=Path(__file__).resolve().parents[1]
def load(name, rel):
    spec=importlib.util.spec_from_file_location(name,R/rel)
    mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod);return mod

def main():
    g=load('saved_golden_check','competition_2026_advanced/skill/fpga-golden-check/scripts/check.py')
    t=load('saved_timing_check','competition_2026_advanced/skill/vivado-evidence-audit/scripts/check.py')
    b=load('saved_board_check','competition_2026_advanced/skill/fpga-board-diagnosis/scripts/check.py')
    er=R/'competition_2026_advanced/report/evidence'
    expected=g.codes(R/'evidence/board/expected_1000.hex')
    first=g.codes(er/'e29_observed_pass1.hex');second=g.codes(er/'e30_observed_pass2.hex')
    compared=g.compare(expected,first)
    assert len(expected)==len(first)==len(second)==1000
    assert compared['status']=='FAIL' and compared['mismatch_count']==921
    assert first==second
    timing=t.timing((er/'e16_timing_summary.rpt').read_text())
    assert t.gate(timing)=='PASS_TIMING_ONLY'
    metrics=json.loads((R/'evidence/build/PHYSICAL_METRICS_166.json').read_text())['timing']
    assert timing==metrics,(timing,metrics)
    session=b.inspect(json.loads((er/'e32_board_session_observations.json').read_text('utf-8')))
    assert session['numeric_status']=='FAIL' and session['root_cause']=='UNKNOWN'
    # Checks below inject errors into in-memory copies only, never into source files.
    fault=expected.copy();fault[37]^=1
    assert g.compare(expected,fault)['mismatch_count']==1
    assert g.compare(expected,expected[:-1])['status']=='FAIL'
    assert g.native_gate(0,0,[])=='PASS' and g.native_gate(0,0,['dump'])=='FAIL'
    assert g.native_gate(0,1,[])=='FAIL'
    for key in ['WNS','WHS','WPWS']:
        bad=dict(timing);bad[key]=-0.001;assert t.gate(bad)=='FAIL'
    for key in ['TNS','THS','TPWS']:
        bad=dict(timing);bad[key]=-0.001;assert t.gate(bad)=='FAIL'
    result=dict(status='PASS_SAVED_EVIDENCE_REPRODUCTION_ONLY',timing_status='TIMING_PASS',
        board_status='BOARD_NUMERIC_FAIL',outputs=1000,mismatches=921,repeated_read_mismatches=0,
        timing=timing,root_cause='UNKNOWN',offline_fault_checks='PASS',
        new_simulations=0,new_vivado_runs=0,new_hardware_operations=0)
    (R/'publication/saved_evidence_check.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
if __name__=='__main__':main()
