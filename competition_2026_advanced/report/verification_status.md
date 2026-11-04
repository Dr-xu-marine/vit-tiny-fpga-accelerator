# 全部验证状态
状态截止2026-11-03 19:36:38 +08:00。后来结果不得覆盖此快照。

|对象|状态|依据与边界|
|---|---|---|
|当前冻结505文件身份|PASS|SOURCE_MANIFEST逐项SHA核验；见audit_facts.json|
|512张FP32/INT8确认|PASS_TEST_EXECUTION|383/512对377/512；75%全整数之类主张不成立|
|下降≤1个百分点目标|FAIL|实际1.171875个百分点|
|完整ImageNet50000评测|NOT_RUN|不能外推确认集为全量精度|
|历史C整网Golden|PASS|257点/11532400值/1000Host，原生退出正常|
|当前P Bank/ACT/Head局部|PASS_L1_L2|21次有限运行含8负例FI，不是全网|
|当前P完整L3|NOT_RUN|相对C有14个修改/新增活动源|
|当前P定向回归|RUNNING|最多20点；截至19:36为8点355787值PASS|
|200MHz完整整机物理|FAIL|全布通，WNS-0.583ns，1744 Setup负端点|
|166.7MHz完整整机Setup/Hold/Pulse/Route|PASS|WNS+.073/WHS+.005/TNS0/THS0/WPWS+.039|
|166.7MHz DRC/CDC|PASS_REVIEW_WITH_WARNINGS|0Error/0Critical；17DRC Warning+128Advisory；4CDC Warning待保留边界|
|Bitstream|PASS_GENERATION|真实文件SHA928403c3...；不是数值PASS|
|JTAG配置/MIG校准|PASS_OBSERVED|用户截图及Host日志；不等于DDR全域可靠性|
|首次1000码板级数值|FAIL|921项不同；两次读取稳定0差异；Top1一致不等于PASS|
|后续DDR340点|FAIL_CURRENT_SESSION_ONLY|复位/下载后，不可解释首次推理|
|实板根因/修复|UNKNOWN / NOT_RUN|没有确认根因或成功修复|
|正确推理FPS/功耗|NOT_RUN|失败任务计数不作有效FPS|
|本次Skill helper|PASS_OFFLINE_ONLY|15项离线检查；0仿真/0Vivado/0板操作|

RUNNING不是PASS；UNKNOWN用于根因未定。任何工具异常或dump需标FAIL，即使数值断言已经完成。板级交付历史FINAL_STATUS的BOARD_NOT_YET_VERIFIED是生成时状态，当前状态按实际首次FAIL更新，未改历史原文件。
