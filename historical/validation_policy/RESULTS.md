# V2分级验证与仿真加速评估

- 当前R2完整12层回归保持运行，本轮没有启动其他vendor、修改其脚本/参数或中断进程。只读核对97个绑定代码文件，SHA全部一致；未修改RTL、权重、Golden。
- 新增只读选测工具`plan.py`及真实入口登记`registry.json`。六项策略自检PASS、全部参考入口存在。计划输出不能授予任何功能/整网/物理PASS。

| 级别 | 触发条件 | 必要证据 |
|---|---|---|
| L1 | 每次RTL局部修改先执行 | 相关模块自检查TB、局部冻结Golden、适用的故障注入及reset/bubble/背压/flush/credit/tail/连续任务 |
| L2 | 计算通路、调度或接口变化 | L1，加受影响算子、真实BRAM供数/写回、地址/tag同龄及代表性网络路径 |
| L3 | 重要架构定版、可能影响全网、最终交付 | 对应L1/L2证据，加完整257检查点/11,532,400值/1000实际host分类输出逐位对拍、两项FI、真实周期账本与干净工具退出 |

必须显式指定改动影响；未知文件保守升级L3。未变且精确源/向量/工具契约一致的局部前置证据可保留，受影响修改必须重新验证。局部PASS只能报告局部范围。

入口示例（仅生成计划，不启动仿真）：

```powershell
D:/python1/python.exe -B validation/v2_validation/plan.py --change v2_rq16.sv --impact local
D:/python1/python.exe -B validation/v2_validation/plan.py --change v2_gemm128_wide.sv --impact datapath
D:/python1/python.exe -B validation/v2_validation/plan.py --component network --impact final
```

真实覆盖缺口：当前新128短连接仅覆盖DMA/共享ACT/GEMM/MOVE/QK-packed/WB/host；独立短回归尚未覆盖LN→QK→Softmax15→Q14AV→投影/residual→GELU/FC连续路径。旧16lane encoder测试不能代替。选测工具遇到该需求时明确列出缺口并要求L3兜底；未冒称新短回归已实现。

加速评估（只读，未运行性能对照）：

- 当前没有WDB/VCD/WCFG和`log_wave`；16:35时`simulation.log`约8KiB、相关日志合计约38KiB。关闭波形/减少进度日志预计收益小，保留错误、检查点、周期计数和必要外部对拍文件。
- 当前编译至仿真启动约8.09秒；10秒采样xsimk消耗约9.97秒CPU、读250B/写0B，主耗时为事件仿真CPU成本。不能据此归因某个具体RTL进程。
- 2019.1当前xelab默认`-O 2 -debug off -mt auto`，日志显示14个编译线程；编译多线程不代表运行时多核。未来可在新目录评估`-O 3 -debug off -mt 2`，先执行相同GEMM/真实BRAM/FI/短连接对照，通过后才评估完整回归。没有已测提速结果。
- 不降低时间精度、不删断言/前缀/握手检查、不更换DSP原语模型、不缩小全网覆盖或改变seed/数学/Golden。当前运行参数不变。
- 构建缓存尚未启用。现有xsim.dir没有完整可信缓存清单，且编入头文件的绝对参数/DDR路径随work变化，不能直接搬用。
- 将来只缓存严格干净的compile/elab产物；key必须包含工具build/实际库、RTL/TB/递归include、宏/generic/top、编译顺序/flags及路径布局。首次仿真前冻结完整产物SHA，缓存只读发布、复制到新目录而非硬链接。运行向量、Golden、plusargs和seed每次重新绑定；编入代码的参数也进入build key。
- cache_hit仅代表构建复用，不能授予功能PASS。先验证cached/uncached短normal与FI一致，并确认修改RTL/宏/tool key强制miss，再考虑长回归。即使全部省去本轮约8秒构建时间，整体收益也很有限；近期主要收益来自分级选测。

官方参数依据：[UG900 v2019.1](https://docs.amd.com/v/u/2019.1-English/ug900-vivado-logic-simulation)。现有R2回归和v19诊断队列均未改动，当前整网仍须完成原验收。
