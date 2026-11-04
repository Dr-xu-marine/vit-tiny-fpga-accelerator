# 128 MAC整机：200 MHz一次布线结果

**完整板级候选真实布线完成；Hold PASS，Setup FAIL，整机200 MHz时序未通过。** 新版完整L3 Golden、Bitstream及实板均未运行。

本轮从复制前 `D:/fpga/vit_tiny_vcu118/hf02_js_pl/05_placed_host75.dcp` 恢复，SHA256 `260f09fcaeae30ccc3e446b9ad627e46d07a74b3be63f92c220eafa903fb57bf`。未重新综合/布局，未单独执行复位复制或添加虚假时序例外；route_design工具内部执行了标准物理优化。本轮只执行一次route。输入DCP、冻结505源码和历史成果前后保护检查PASS。

| 检查 | 真实结果 |
|---|---|
| 路由 | 完成，124191/124191条可布线网络完全布线，0条路由错误 |
| Setup | WNS −0.583ns，TNS −217.731ns，1744/223283个端点失败 |
| Hold | WHS +0.005ns，THS 0，0/222374个端点失败 |
| 脉宽 | WPWS +0.039ns，失败0 |
| 时钟 | 计算域5.000ns；Host 13.333ns；DDR UI 3.333ns；计算时钟用户Setup/Hold uncertainty 0.100/0.050ns |
| 资源 | LUT 49874（其中分布式RAM LUT 2348），FF 59120，DSP 137，RAMB36 1129，RAMB18 97，URAM 0 |
| MAC | 128个DSP48E2、AREG/BREG/MREG/PREG=1/1/1/1，4个局部valid寄存器；黑盒0、锁存器0 |
| 工具状态 | route和报告进程原生PASS，均无dump；route_design实际13分50秒，包含DCP保存等的route进程约16分09秒，报告进程约11分30秒 |

最差Setup为Weight BRAM `RAMB36_X0Y108`（X0Y9/SLR1）到GEMM `b_leaf_reg[23]`（X3Y7/SLR1），实际数据延迟4.656ns，其中逻辑1.383ns、真实布线3.273ns，时钟偏斜−0.794ns，3级逻辑，slack −0.583ns。程序BRAM到writer目标寄存器也有−0.583ns；GELU到AUX最差−0.535ns；ACT BRAM路径−0.247ns；复位根到DDR FIFO控制约−0.374ns。DSP控制族−0.005ns，MAC数据路径族Setup +0.782ns；Bias/RQ +0.047ns余量很小。1744个负Setup端点完整清单未截断，Hold负端点0；不要以只查DO引脚的NOT_PRESENT代替全部RAM实例起点路径。具体路径参见 `report/setup20.rpt`、`report/negative_max_endpoints.tsv` 与 `report/family_*.rpt/tsv`。

`check_timing`：no_clock、错误生成时钟、未约束内部端点及组合环均0。`sys_rst`无input_delay、`c0_ddr4_reset_n`无output_delay需按异步复位和DDR初始化协议解释。DRC没有Error或Critical Warning，但有DPIP-2 3项、DPOP-3 1项、DPOP-4 3项、PDCN-1569 6项、REQP-1857/1858共3项、RTSTAT-10 1项和128条AVAL-155 Advisory。方法学有9条LUTAR-1和1条TIMING-18 Warning；CDC有206条CDC-3 Info、17条CDC-9 Info和4条CDC-15 Warning。报告命令成功不等于这些告警已关闭，也不等于板级CDC/DDR已验收。报告日志还有Tcl store写权限以及大对象时序查询的Critical Warning，原日志保留。

路由后128 MAC和局部valid结构再次检查PASS；BRAM分布见 `report/memory_mapping.rpt`。复用报告脚本时保留 `joint_bank_receivers NOT_RUN`：旧分类器对同龄复位别名有误判风险，本轮没有伪记其为PASS；布线前已对该快照十类主要数组进行BRAM结构只读复核。报告中的 `family_*.tsv` 路径组字段部分为UNKNOWN，完整时钟组以原始 `*.rpt` 为准。

资源保护：无Job内存硬上限，峰值私有提交11.20GiB，最大系统Commit 28.72GiB（约89.85%），页面文件使用峰值6.72GiB；未因短时物理可用内存低而终止，无OOM或工具dump。没有并行Vivado重型任务。

输出路由DCP：`route/07_routed.dcp`，SHA256 `2bc7b742bbd5c1a62696bb52acf1f7aabe2513e809694ca652af419045b56489`。全部原始日志、完整路径与资源记录分别在 `route/`、`report/`、`RESULT.json`。本轮不自动重试、不修改RTL、不生成Bitstream。下一步应以本次真实路径为依据联合处理Weight/GELU/ACT读出、程序供数与复位分发，并核查时钟偏斜及所有低裕量路径；保持128 MAC和数值规则，再做受影响功能验证和物理实现。最终整网签收仍需最新快照同源完整L3 Golden。
