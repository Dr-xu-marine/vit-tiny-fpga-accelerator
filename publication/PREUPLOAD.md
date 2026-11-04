# 上传前检查 / Pre-upload review

当前状态：**本地发布文件检查及Git上传预演通过；等待账号/远程地址、可用认证及用户发布确认，尚无公开仓库链接。**

- 原工程仅作为只读来源；没有修改源RTL、原报告、权重、约束或测试现场。
- 未启动R2、XSim、Vivado综合/P&R或板卡操作。
- `source_manifest.json`记录每个复制文件的来源及SHA；active_sources仅为真实综合输入中27项源码/头文件。
- `excluded_dependencies.json`记录不分发的模型、运行夹具和厂商生成文件。
- 新增README、许可、第三方清单、复现说明、路径适配记录与离线检查脚本。
- 所有报告原件保留原始SHA。无源仓库Git历史、私钥、凭据、生成厂商IP、DCP/Bitstream或大缓存。
- 安全/大小/语法/路径/哈希的实际结果见 `audit_results.json`；保存证据复核见 `saved_evidence_check.json`。

## GitHub身份与仓库

- 原工程 `.git/config` 未配置remote。
- `C:/Users/Lenovo/.ssh` 不存在；系统OpenSSH客户端存在。
- 只读 `ssh -T` 使用BatchMode、StrictHostKeyChecking和连接超时；返回 `kex_exchange_identification: Connection closed by remote host`，无法确认账号。未接受新主机密钥，未写入SSH配置。
- GitHub CLI未在已检查的PATH/标准安装路径发现。
- 用户暂未提供账号及仓库地址，并指示先整理；目标仓库是否存在尚不能核实。
- 建议名称 `vit-tiny-fpga-public`。实际HTTPS与SSH地址均待账号/仓库确认，不提供虚构链接。

## 上传前待解决

1. 用户提供GitHub账号与目标仓库名/地址；只读检查仓库存在性及访问权限，确认SSH/HTTPS可用。
2. 确认作者/团队/单位对拟公开源码和报告的公开权限；当前许可保留权利，不擅自套用MIT。第三方权重、数据集和生成IP已排除。
3. 若要求评委独立完整重跑，还需合法外部数据及匹配SHA、适配并验证构建/仿真入口；当前只能承诺源码/报告/保存证据可审阅。
4. 已初始化独立本地Git仓库（main），未提交、未设置remote。用户确认**具体文件清单、账号和远程地址**后，再创建公开仓库（如尚无）、配置实际提交身份、本地提交并push。确认前不创建公开仓库、不push。

板级921差异是必须公开的工程状态，不阻止真实展示项目；不得通过README措辞将其改为功能PASS。

## 最终本地检查

327个公开文件，约17.4MB；最大文件约4.13MB。27项活动综合源码SHA与只读原工程一致，280项来源记录核验通过。9个Python脚本语法解析通过，17个发布文档相对链接有效；按扫描规则未发现私钥/凭据。保存证据重读确认时序通过、板级921/1000差异。`git add --dry-run --all`成功列出全部327个文件，误忽略0项；未执行实际add/commit/push。

Windows保留目录名`tests/aux`已在发布副本改为`testbench/aux_cases`，只调整测试文件路径；原文归档与映射记录完整。根构建目录忽略规则已收窄，不丢失`evidence/build`原始依据。
