from pathlib import Path
import sys
R=Path(__file__).resolve().parent;ROOT=R.parents[1]
sys.path.insert(0,str(R.parent/'full128_joint_screen_20261102'));import run as B
B.guard();B.preflight()
s=(R/'scripts/prepare_resume3.tcl').read_text()
needle='set_property -dict [list CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $target_mhz] [get_bd_cells compute_clock]'
assert s.count(needle)==1
s=s.replace(needle,needle+'\nset_property -dict [list CONFIG.OVERRIDE_MMCM true CONFIG.MMCM_DIVCLK_DIVIDE 3 CONFIG.MMCM_CLKFBOUT_MULT_F 10.000 CONFIG.MMCM_CLKOUT0_DIVIDE_F 6.000] [get_bd_cells compute_clock]')
p=R/'scripts/prepare_integer.tcl';p.write_text(s)
out=R/'prepare_integer_166';out.mkdir(exist_ok=False);B.M.D=out
x=B.M.run('prepare','vivado',['-mode','batch','-nojournal','-log',out/'vivado.log','-source',p,'-tclargs',ROOT/'hf02_b166/project/downclock_board.xpr',out,B.P,R/'scripts/sources.tcl','166.666667','166666666',ROOT/'hf30_ready_cache_v2/ip_cache'],out,timeout=1800,marker='DOWNCLOCK_BOARD_PREPARED_NO_SYNTHESIS')
B.M.save(R/'PREPARE_INTEGER_RESULT.json',x)
assert x['status']=='PASS'
