# 完整128 MAC ViT-Tiny166.7MHz实验性Bitstream

**BITSTREAM_GENERATED / TIMING_PASS / BOARD_NOT_YET_VERIFIED**

- 对象：VCU118、xcvu9p-flga2104-2L-e，完整12层静态W8A8/128MAC候选；Vivado2023.2。仅一次166.7MHz完整综合/P&R，150MHz未运行。没有修改计算算术RTL、权重、量化规则或Golden。
- 计算时钟真实配置：固定250MHz(E12/D12)→MIG UI300MHz；Clock Wizard MMCME4 M=10/D=3/O=6，VCO1000MHz、计算166.666667MHz/6.000ns。Host75MHz、DDR UI300MHz保持，CSR频率标识166666666。用户Setup不确定度0.100ns、Hold0.050ns保持。已重新生成IP并完整重综合，不使用旧200MHz DCP改约束冒充结果。

## 最终真实物理验收

|项目|结果|
|---|---|
|综合/优化/布局/物理优化/布线|实际完成，逐阶段DCP保留|
|Setup WNS / TNS|+0.073ns /0.000ns，0负端点/223194端点|
|Hold WHS / THS|+0.005ns /0.000ns，0负端点/222285端点|
|Pulse WPWS / TPWS|+0.039ns /0.000ns，0违例/66447检查|
|路由|123520/123520可布线网络完整，0路由错误|
|资源|LUT49299、FF59093、DSP137(128MAC核心全部AREG/BREG/MREG/PREG=1/1/1/1)、RAMB36E2=1129、RAMB18E2=97、URAM0|
|内部约束|no_clock=0，未约束内部端点=0，生成时钟错误=0，环路=0|
|默认DRC|0Error/0Critical Warning；17条Warning实例及128Advisory保留分类|
|CDC|206条CDC3 Info、17条CDC9 Info；其中4条CDC15 Warning均为Debug Hub读/写FIFO；不是零警告CDC签收|
|Bitstream|工具原生正常退出、无dump；write_bitstream成功，真实日志在delivery_166p7/reports/bit_vivado.log|

SYS_RST异步输入和DDR reset_n异步输出按真实初始化/复位协议解释，未虚构I/O延迟；没有意外未约束的关键内部路径。原有校准状态两级同步器5ns max-flight界限保留，第二级保持普通Setup/Hold；未新增虚假False Path或Multicycle。

## 交付路径与版本

- Bitstream：`D:\fpga\vit_tiny_vcu118\experiments\full128_downclock_bit_20261102\delivery_166p7\full128_166p7.bit`，80,159,232字节，SHA256 `928403c3745abe5b18b57088eaaa1fdb3a181343661a60421b4346aee42d0905`。
- 最终DCP：`D:\fpga\vit_tiny_vcu118\experiments\full128_downclock_bit_20261102\delivery_166p7\full128_166p7_final.dcp`，SHA256 `25c8f75978fb10f65acb18292bb39930801118c4dd43f16201db1370ba001027`。
- 有效XDC：`D:\fpga\vit_tiny_vcu118\experiments\full128_downclock_bit_20261102\delivery_166p7\effective_final.xdc`；Clock合同与全部原始STA/资源/CDC/DRC及关键路径见delivery_166p7/reports。有效XDC是诊断快照，重建需要原IP约束/作用域和实际板级工程，不能只将该文件单独当成新工程。
- RTL冻结根：`D:\fpga\vit_tiny_vcu118\experiments\full128_bank_reset_fix_20261102`，505文件manifest SHA256 `bd2004660656ea2f950d7957014924d588e469345cc1ab6fb69e3489eeec8cc8`；实际编译源码/IP/XDC274项SHA在ACTUAL_SYNTH_INPUTS_166.json。
- 新板级工程：`D:\fpga\vit_tiny_vcu118\hf02_b166\project\downclock_board.xpr`；真实Clock Wizard及BD参数已冻结。原200MHz routed DCP SHA256 `2bc7b742bbd5c1a62696bb52acf1f7aabe2513e809694ca652af419045b56489`保持不变。
- 全部交付文件SHA：delivery_166p7/MANIFEST.json；原始构建运行目录hf02_d166_sy/op/pl/ph/rt/rp与hf03_d166_audit/check/bit保留。

## 功能证据与检查器修复

真实生成MMCM+proc_sys_reset短测768周期、两次复位/锁定PASS，周期和AUX复位FI检出。两次连续真实128MAC分类头各1000Host值及1,548,288逐K前缀零差异，Golden FI检出索引37。新增频率CSR核验166666666。参考范围是局部实际DMA/ACT/Collector/Host，未仿真外部DDR训练或整机跨域负载。

综合后旧校准检查器仍要求5ns目的周期，原生退出1，原始FAIL不改写；只在独立检查副本核验6ns，保留原5ns CDC flight bound，从已保存综合DCP继续，无重复综合。布线报告旧GELU选择器检查器只接受idle_reset_local[4]，实际映射使用[2]；逐个证明六个FF的D/C/CE/R/INIT一致后做严格别名归一化，所有10类BRAM-only检查PASS、0LUTRAM/0非RAM阵列存储FF，选择器检查器的载荷源/缺地址FI检出。未改网表、RTL或放宽存储容量。

原128MAC C0及全部数学数据SHA保留。**最新Bank版本完整12层L3 NOT_RUN**，历史完整L3不能替代最新版本。用户已明确授权先生成实验Bitstream；生成成功不是整网推理正确证明。实板1000输出、DDR、JTAG稳定性、延迟/FPS及功耗均NOT_RUN。

## 资源和日志

严格串行、maxThreads1，无5.5GiB/8GiB RAM硬上限，现有16GiB页面文件未改动；无OOM或异常dump、无压力保护触发。Job私有提交峰值9.918GiB，进程树工作集采样峰值8.977GiB，全系统Commit采样峰值26.291GiB(提交上限约31.8GiB)，页面文件实际使用采样峰值4.374GiB；最低可用RAM0.011GiB，正常换页获授权，未因此单独中断。工作集可能含共享页重复，物理/系统峰值为监控采样口径，详见FINAL_RESOURCES.json和原始resources.jsonl。

重要警告逐项见WARNING_REVIEW.md，包括厂商DSP流水建议、LUT未使用输入、JTAG FIFO碰撞提示、Debug Hub CDC15、9条厂商LUT异步复位、外部复位I/O、MMCM位置建议及工具TclStore/大查询警告；未降级任何严重性。实际顶层I/O审计确认DDR reset_n=N20/LVCMOS12/DRIVE8，时钟E12/D12；MIG作用域重放警告未造成这些属性缺失。

## 首次上板

**可以开始受控VCU118下载及真实推理测试，不能宣称实板PASS。** 按BOARD_FIRST_TEST.md，用匹配.bit/.ltx配置唯一正确的xcvu9p器件，不烧Flash。先发现JTAG AXI、核对ID/128MAC/频率标识，等DDR校准，执行scratch写读及完整8,990,912字节上传回读，再跑完整程序并逐位核对1000实际分类输出。board_test/first_test.tcl仅准备、未执行；FPGA复位期间停止Host/DMA事务，等待LOCKED和校准后再启动。完整L3、板级稳定性、真实FPS/功耗仍需后续签收。
