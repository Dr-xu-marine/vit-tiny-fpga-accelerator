# VCU118 166.7MHz完整128MAC ViT-Tiny首次上板包

状态：BITSTREAM_GENERATED / TIMING_PASS / BOARD_NOT_YET_VERIFIED。
计算166.666667MHz(真实MMCM M=10/D=3/O=6，输入300MHz)，Host75MHz、DDR UI300MHz。
Vivado2023.2；目标xcvu9p-flga2104-2L-e。Setup WNS+0.073ns/TNS0；Hold WHS+0.005ns/THS0；脉宽无违例；123520/123520网络完整布通。

|文件|用途|
|---|---|
|full128_166p7.bit|Vivado Hardware Manager下载到FPGA的配置文件|
|full128_166p7.ltx|本次构建匹配的调试探针描述文件|
|ddr.bin|真实冻结输入、权重和算子数据包，8,990,912字节；需通过Host写入DDR|
|host_w8.tcl|未改动的Host/JTAG AXI加载、读回、状态轮询及对拍函数|
|expected_1000.hex|冻结1000分类INT8预期值，仅用于比较，不写入ACT或Collector|
|first_test.tcl|便携测试入口，自动使用同目录数据和脚本；不会下载Bitstream或烧Flash|
|MANIFEST.json|文件SHA256及原始路径|

## 操作

1. 将整个目录解压到可写位置，文件保留在一起。启动Vivado2023.2 Hardware Manager，连接VCU118电源和JTAG USB，Open Target/Auto Connect，核对唯一正确的xcvu9p器件。
2. Program Device选择full128_166p7.bit；探针文件选择同目录full128_166p7.ltx。仅下载FPGA，不执行Flash烧录。
3. Refresh Device后确认JTAG AXI出现。在Tcl Console执行 `source {你解压的完整路径/first_test.tcl}`。路径带空格用花括号。
4. 脚本先检查ID/128MAC/166MHz频率标识，最多30秒等待DDR校准，再执行DDR scratch写读；随后完整上传ddr.bin并逐块回读，启动真实完整程序，最多600秒等待计算完成，并读取/对拍全部1000分类结果。
5. 成功应看到HOST_DDR_SCRATCH_PASS及V128_HOST_FUNCTIONAL_PASS values=1000；实际结果输出为同目录observed_1000_<时间戳>.hex。保存完整Tcl日志、结果文件和core_cycles/job_cycles。出现错误立即停止，保留第一处不一致，不更改Golden。

本机原路径可直接执行：
`source {D:/fpga/vit_tiny_vcu118/experiments/full128_downclock_bit_20261102/board_kit_166p7/first_test.tcl}`

## 重要边界

- .bit成功不代表实板推理PASS。最新Bank修改版本完整12层L3尚未重新签收；本包获准作为实验候选先上板，实际DDR/JTAG/1000输出、FPS和功耗仍NOT_RUN。
- 复位期间停止Host/DMA事务，等待MMCM重锁、复位释放及DDR校准再启动。不要在计算/AXI事务进行时使用局部复位。首次建议冷上电后测试。
- 本测试验证冻结数据包中的单个输入完整推理，不是ImageNet验证集精度评测；不代表75%分类精度或测得FPS。
- 数据打包及Host2023.2真实接口尚待实板确认，若scratch字序/STATUS读取不符，应先查接口，不能修改Golden掩盖。
- DCP、XDC和RTL不是Hardware Manager下载必需文件，留在原交付目录供重建和诊断；本包不修改它们。
