# Bank与复位联合修订 — 结果

**L1/L2功能PASS；代表性完整深度bank综合结构PASS；物理工具FAIL，停于opt_design。未布局/布线，无新WNS/WHS，无整机时序PASS。**

独立候选`D:/fpga/vit_tiny_vcu118/experiments/full128_bank_reset_fix_20261102`。冻结505文件，SOURCE_MANIFEST SHA256=`bd2004660656ea2f950d7957014924d588e469345cc1ab6fb69e3489eeec8cc8`。父版494文件、父版DCP、历史保护资产、128 MAC/P48/标量RQ算术及冻结参数/Golden前后核验PASS；`D:/xu`未写入。

实际RTL修改只有`rtl/vendor_byte_banks.v`、`rtl/w8_act_local_ram.sv`、`rtl/w8_memories.sv`及私有测试路径头文件；详见CHANGED_FILES.json及REVISION.diff。

- Weight/PACK及RQ/参数/LUT增加bank本地地址、数据、写使能寄存，提交延迟1拍。接受后的写入跨reset排空，统一writes_pending参与原LOAD/启动门槛。同步读延迟、读写优先级和背压语义保留，待提交值使用同拍读旁路。
- 第一版把旁路选择放在RAM同步读赋值内部，产生`Synth 8-6849`与LUTRAM回退，严格检查已在布局前拒绝。失败RTL和日志保留在`evidence/revision1_failed_rtl`及`D:/fpga/vit_tiny_vcu118/hf02_br_depth`。
- 只做一次已定位的推断模板修正：原生同步BRAM读与同拍外部旁路分离，没有增加对外读延迟。随后重跑所有受影响的接收端、tag/ABORT、分类头/Host、Patch和Softmax短路径。
- ACT/Weight/上传参数采用cascade_height=2；ACT标量5拍、宽响应6拍不变。代表性bank综合确实报告每bank16个RAMB36、8组高度2的级联；**尚无布线后级联延迟证据**。机制参见[AMD UG901](https://docs.amd.com/r/2023.2-English/ug901-vivado-synthesis/CASCADE_HEIGHT)。

|功能证据|结果|
|---|---|
|接收端原版逐拍对照|462690字节检查、4365拍、2395次接受写入、31次接受后Reset；FI检出bank数据篡改|
|ACT完整深度|64Ki×8、双读口、65536字逐地址检查、263172字节检查；Reset/停顿及FI PASS|
|ACT接口及算子|153响应/9456字节检查、12274标量检查、9种Reset相位；LN/Softmax/GELU/Residual/Prob/位置编码前缀/Move共1866值PASS|
|真实128 MAC分类头→Host|修正版连续两次各1000输出逐位一致，每次1548288个逐K前缀；281519周期=LOAD212280+compute61433+Collector6000，其余1806周期；与父版相同|
|Patch/Softmax/异常|Patch16输出/98304前缀、16363周期；Softmax200输出/122817周期；真实tag异常→GEMM ABORT及相应FI PASS|

本轮实际21次有限XSim运行（含8次预期失败注入执行），均按原生进程/退出码/dump规则验收，无异常dump。第一版及修正版原始记录分别保留；沿用的ACT/算子前置证据以实际使用源码SHA未变为依据。新版完整257/11532400/1000整网L3 **NOT_RUN**，不继承为新版完整PASS。

**小型综合与工具故障：**

- 使用真实器件xcvu9p-flga2104-2L-e、IBUFDS/MMCM/BUFG，250MHz输入生成200MHz/5.000ns；工具已通过生成时钟PERIOD断言并应用Setup/Hold uncertainty=0.100/0.050ns。无新增false path/multicycle。
- 范围为各一个实际完整深度ACT、Weight、参数bank（各64Ki×8），动态片内寄存器源/汇；**不是16-bank完整ACT、完整GEMM或整板验收**。
- 修正版实际综合：**LUT74、FF207、DSP0、RAMB36=48、RAMB18=0、LUT as Memory=0、Latch0**。综合DCP已保存并通过ZIP CRC检查。该资源只是小型探针，不能代替整机资源。
- 进入opt_design后，最后日志位于`PowerOpt Patch Enables Task`；原生Vivado与启动器均退出`0xC0000005`，并产生dump。异常指令位于`librdi_netlist.dll+0x165999`，调用栈暂无，**根因UNKNOWN**。这不证明某个第三方DLL、Windows配置或RTL数学导致故障，也不是时序FAIL/OOM证据。
- 修正版工具树私有提交峰值3.01GiB，系统Commit峰值19.03GiB/59.84%，页面文件使用峰值1.22GiB，最低可用物理RAM3.12GiB；未触发资源压力停止。未重装、未改系统/LSP/注册表，未因物理RAM下降终止。
- 原始日志/dump/逐进程退出/资源记录：`D:/fpga/vit_tiny_vcu118/hf02_br_depth_repaired`。保留DCP=`01_synthesized.dcp`，SHA256=`0c7983f890f9e97d08dea20970f2a61b6a5d8b4100e2e2473b33faccc48577cc`。

**复位与停止点：**

只读父版DCP确认终级reset FDRE位于SLICE_X112Y339，Q直接负载705，INIT0、CE1、R0，D来自原SEQ/pr_reg_0，C为原200MHz计算时钟。只读原生日志在`D:/fpga/vit_tiny_vcu118/hf02_br_reset_read`。已准备按相同D/C/CE/R/INIT做工具物理复制的约束检查，**复制试验NOT_RUN/BLOCKED**；未给现有reset增加延迟，不能说全局复位问题已经修复。[UG835物理复制命令依据](https://docs.amd.com/r/2023.2-English/ug835-vivado-tcl-commands/phys_opt_design)。

本轮只有两次小型综合入口：第一次因BRAM结构失败正常停止；第二次结构通过后工具崩溃。实际place/route均0次。另有一次只读父版DCP查询。串行守卫拦住过一次尚未结束报告进程期间的启动；一次原生日志混合编码导致的Python预检错误在工具启动前修正，均未产生额外Vivado实现进程。

**已停止，无后台Vivado任务。** 新整板实现、完整Golden、Bitstream、实板/FPS/功耗均NOT_RUN。下一步建议从保留的小型综合DCP定点验证PowerOpt故障，避免重新综合；官方`opt_design -directive RuntimeOptimized`不执行BRAM power optimization，可作为下一轮有限对照（**本轮未执行，不能保证修复**），见[AMD UG835](https://docs.amd.com/r/2023.2-English/ug835-vivado-tcl-commands/opt_design)。须先恢复小bank完整Setup/Hold/DRC验证，再验证同龄复位复制，然后决定是否进入一次新整板实现。
