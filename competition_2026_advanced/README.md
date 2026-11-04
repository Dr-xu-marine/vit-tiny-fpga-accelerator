# ViT-Tiny AMD advanced competition delivery

正式设计报告入口：report/design_report.pdf；可编辑版本report/design_report.docx；Markdown原稿report/design_report.md。
当前有效结论：166.7MHz完整整机TIMING_PASS / BITSTREAM_GENERATED；首次实板1000码中921项不一致，BOARD_NUMERIC_FAIL。历史C L3通过不能覆盖当前P。

## Contents
- report/figures：16幅SVG可编辑源与PNG。
- report/evidence_index.md：原始路径、SHA、活动源码行号。
- report/verification_status.md：PASS/FAIL/RUNNING/NOT_RUN边界。
- report/missing_evidence.md：缺失资料与竞赛附件风险。
- report/llm_collaboration.md、contribution_review.md：实际分工及待人工确认项。
- skill/：三个Skill、参考证据、离线helper和自测。
- tools/：只读取证、图形及报告构建脚本。Python使用独立Codex运行时，不修改Vivado环境。

## Read-only scope
未修改RTL/Golden/权重/XDC/Bitstream，未启动新Vivado、XSim或板操作。原有定向回归保持运行。所有生成文件仅位于本交付区；大DCP/Bitstream/权重不重复打包。D:/xu未纳入。

## Reproducibility
先阅读evidence_index、核验SHA与版本，再使用原工程各阶段脚本。报告生成脚本并不授权重跑构建/硬件。时序审查必须使用完整IP及生成时钟，不独立复用effective XDC。新回归按AGENTS的L1/L2/L3门槛。

## Competition checklist
官方AMD指南PDF22-25页，上传要求3页，SHA在official_sources.json。截止2026-11-04 18:00。PDF<=50MB，H264 MP4<=300MB且建议<=3分钟，代码RAR<=200MB、签字授权、Github链接、实物照片及可能的海报待人工准备。未知官方模板须最终核对。
新目录/文件采用英文小写；README.md和SKILL.md为用户与技能格式指定的保留文件名。第三方许可待核，不给原工程擅自添加许可证。

## Frozen build and board reproduction map

下表是已有实验的真实入口，不是本轮已执行命令。重新构建前须在新独立目录修正固定输出路径，保留原工程；原脚本含历史路径/拒绝覆盖保护，不能对历史run目录直接重跑。

|顺序|实际入口或输入|检查/输出|
|---|---|---|
|1|experiments/full128_bank_reset_fix_20261102/SOURCE_MANIFEST.json|505项SHA，冻结权重与量化参数|
|2|experiments/full128_downclock_bit_20261102/delivery_166p7/ACTUAL_SYNTH_INPUTS_166.json|实际编译源、初始化、IP与XDC；274项总记录，其中172项源码/头文件/数据|
|3|hf02_b166/project/downclock_board.xpr|真实VCU118完整板级工程，Vivado2023.2，器件-2L-e|
|4|experiments/full128_downclock_bit_20261102/prepare_integer_clock.py 与 scripts/prepare_integer.tcl|DDR UI300 / Host75 / compute166.6667；MMCM M10 D3 O6|
|5|同一实验build_scripts/synth.tcl、opt_calibrated.tcl、place.tcl、phys.tcl、route.tcl|按依赖串行，每阶段保存DCP，绑定新工程与新输出目录|
|6|build_scripts/report.tcl、close_final_checks.tcl、audit_final_storage.tcl|完整Setup/Hold/Pulse、DRC、CDC、路由、时钟与存储结构|
|7|build_scripts/bitstream_checked_io.tcl|仅全部必要检查满足后生成实验性Bitstream，不能替代功能验收|
|8|board_kit_166p7/first_test.tcl 与 host_w8.tcl|匹配bit/ltx；JTAG、校准、scratch、上传/读回、启动、1000码比较|

步骤4-8位于experiments/full128_downclock_bit_20261102；结果与日志在delivery_166p7及hf02_d166_* / hf03_d166_*目录。已有历史C整网输入绑定与原生命令见report/evidence/e08_simulate.json、e10_frozen_inputs.json和原始evidence_index。新P相对C修改14项活动RTL，须按当前输入重做最终L3。

实板流程要求保存同一会话的状态与所有输出，发生下载/断电/复位后重新标记会话，后续DDR内容不能解释前一次失败。当前已经921项不一致；不要直接重复first_test覆盖现场。此报告不授予重跑硬件的指令。

完整跨电脑/从零复现还依赖Vivado2023.2安装、xcvu9p器件支持及许可、原始模型/数据取得权与IP生成配置。本交付区只打包报告和精简证据，不冒充完整可分发RTL工程。提交源码RAR前应做单独干净目录复现与路径绑定审查。
