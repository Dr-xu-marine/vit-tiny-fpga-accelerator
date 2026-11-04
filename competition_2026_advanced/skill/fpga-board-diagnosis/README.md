# fpga-board-diagnosis
入口：SKILL.md。仅离线证据审查；输入是冻结证据副本，输出是JSON和人工审核结论。
运行：python scripts/check.py <input>，Golden检查需要expected与actual两个文件。
失败条件、权限边界和真实使用范围见SKILL.md及references/evidence.md。
本包来自同一ViT工程的已用工作流程，2026-11-03新整理；独立跨工程验证NOT_RUN。不能代替原Vivado、XSim或实板验收。
代码许可尚需作品权利人统一确认，未给历史RTL或第三方IP擅自授权。
