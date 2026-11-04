# ViT-Tiny FPGA Accelerator — VCU118 / 128 MAC

面向 AMD 自主选题高级组竞赛评审的源码、设计报告和实验依据。当前版本为 **166.6667MHz 板级候选（P）** 的待上传快照。

**当前结论：整机时序通过；首次实板数值检查失败。** 首次实板得到 1000 个分类输出码，其中 **921 项与 Golden 不一致**；两次保存的读数相同，根因仍未知。这里的 1000 项是一次推理的 1000 个输出值，不能解释为 1000 张图片的准确率。历史 C 版本整网通过不能覆盖当前 P。未宣称正确板级 FPS、功耗或最终整网验收通过。

## 评委阅读入口

- [设计报告 PDF](competition_2026_advanced/report/design_report.pdf)、[Word](competition_2026_advanced/report/design_report.docx)、[Markdown](competition_2026_advanced/report/design_report.md)。
- [实验结论与边界](docs/STATUS.md)、[原始证据索引](competition_2026_advanced/report/evidence_index.md)、[发布路径映射](publication/SOURCE_MAP.md)。
- [复现说明](docs/REPRODUCING.md)、[外部依赖](data/README.md)、[许可说明](LICENSE.md)。
- [上传前检查](publication/PREUPLOAD.md)、[全部文件清单](publication/FILE_LIST.md)。

## 已有实测证据

| 项目 | 已有记录 | 证据 |
|---|---|---|
| FPGA | VCU118，xcvu9p-flga2104-2L-e，目标 VCCINT 0.85V | 构建清单及报告 |
| 时钟 | DDR UI 300MHz / Host 75MHz / Compute 166.6667MHz；MMCM M=10、D=3、O=6 | IP配置、时钟报告与约束 |
| Routed timing | WNS +0.073ns；WHS +0.005ns；WPWS +0.039ns；TNS/THS/TPWS=0 | [物理指标](evidence/build/PHYSICAL_METRICS_166.json)、[原始时序表](competition_2026_advanced/report/evidence/e16_timing_summary.rpt) |
| 首次板级输出 | 921/1000 不一致；重复读取差异为0 | [原始分析](competition_2026_advanced/report/evidence/e31_actual_board_analysis.json) |
| 当前候选完整L3 | 尚未签收，不继承历史C结果 | [状态说明](competition_2026_advanced/report/verification_status.md) |

本目录仅选取实际166.7MHz综合输入绑定的128 MAC候选，不将原工程顶层的8×8简化模型作为完整ViT-Tiny发布。报告描述了12层、197 token、192 hidden、3 heads、1000类的目标模型/流程；当前硬件数值失败的边界如上。

## 目录

| 路径 | 内容 |
|---|---|
| `rtl/` | 27项实际综合绑定的原创RTL/头文件，逐文件SHA核对 |
| `testbench/` | 自检TB、合成向量与历史测试入口；部分模型派生夹具未分发 |
| `golden/` | 整数/NumPy Golden、整数LayerNorm、Host预处理算法 |
| `constraints/` | 板级XDC、166.7MHz真实时钟与校准状态CDC约束 |
| `scripts/` | 实际BD Tcl的路径适配副本、工程准备入口；尚未运行验证 |
| `host/` | JTAG AXI Host及首次测试脚本；硬件操作需手动执行 |
| `ip/` | 实际BD/XCI配置及带原许可的板卡描述；无生成IP实现 |
| `data/` | 自主调度程序ROM和数据布局；不含权重/图片/DDR负载 |
| `competition_2026_advanced/` | 原设计报告、16组图、实验依据和三个Skill |
| `historical/` | 原构建/报告/验证脚本的只读文本参考（`.txt`后缀） |
| `publication/` | 来源SHA、排除项、路径适配记录、检查结果与文件清单 |

## 离线核查（无需Vivado/板卡）

在本目录运行 Python 3.11+：

```powershell
python -B tools/audit_release.py
python -B tools/check_saved_evidence.py
```

第一条检查发布文件的SHA、可执行路径、敏感内容和大小。第二条重新解析**保存的**Timing Summary并比较保存的1000码，预期报告 `TIMING_PASS`、`BOARD_NUMERIC_FAIL` 和 `mismatches=921`；成功退出只表示历史证据被如实复核，不代表新仿真或实板通过。

完整网络/板级复现还需要合法取得外部模型及数据，并补齐对应SHA的运行夹具；详见复现说明。该发布整理未执行R2、XSim、综合、布局布线或板操作，未验证干净克隆后的构建。

## 发布状态与许可

当前没有创建公开仓库、执行push或生成可访问的评委GitHub链接。账号和目标仓库尚待提供；现有SSH认证未成功确认。建议仓库名 `vit-tiny-fpga-public`，实际地址由用户确认后填写。

项目未擅自授予统一开源许可，详见 [LICENSE.md](LICENSE.md) 和 [第三方清单](third_party/NOTICE.md)。公开前需确认作者/团队/单位的公开权限；本次发布包已排除许可不明的第三方权重及生成IP。
