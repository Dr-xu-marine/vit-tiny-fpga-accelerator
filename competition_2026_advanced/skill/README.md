# Reusable FPGA evidence skills

三个候选技能来自同一个ViT工程的真实流程，本次重新包装并进行离线helper测试；不是跨项目验证PASS。

|包|命令示例|范围与限制|
|---|---|---|
|fpga-golden-check|python fpga-golden-check/scripts/check.py expected.hex actual.hex|定位字节首差异；单独核查原生退出与覆盖数|
|vivado-evidence-audit|python vivado-evidence-audit/scripts/check.py timing_summary.rpt|仅解析真实时序表；路由/身份/DRC/CDC另审|
|fpga-board-diagnosis|python fpga-board-diagnosis/scripts/check.py observations.json|离线会话审查；不发送JTAG、复位或上传|

各包SKILL.md说明输入、步骤、失败条件、适用范围及真实证据。scripts仅依赖Python标准库。selftest_results.json记录15项离线自测；validation.json记录三个SKILL格式校验。

同一Golden的1000码比较通过、真实板级921码差异被检出，均只是checker验证结果。当前板级数值FAIL不因包装为Skill而改为PASS。

跨工程复用、自动原生日志适配和现场板级故障修复均未验证。对其他ABI或文件格式应新增显式适配，并使用复制故障注入样本测试，不自动猜测。
