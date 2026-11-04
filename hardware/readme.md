# 硬件与外设

`bom.csv` 汇总 AIPC 与 FPGA 两端，接线和供电见 `../docs/hardware_setup.md`。Gemini 2 为 AIPC 采集设备；AX7010 为 FPGA 控制板。AI 推理环境来自 EliteMini Series / Ryzen AI 9 HX 370 的 AIPC 证据；原 FPGA ASUS FA608WI 记录作为调试工作站单列，不合并为同一台机器。

`photos/` 保留原型、零件和历史接线图片，历史图不代替当前实物逐线核对。PS 实际几何数值见 `../fpga/project/software/vendor/ra8p1/` 与 `software/build/urdf_model_parameters.h`。

原 FPGA 包内的两套历史 URDF ZIP 与小臂 CAD ZIP 未被本次软件部署/编译调用，已从本软件包移除，原始压缩包中仍保留。当前完整装配、电气原理图、各电机铭牌与电源保护参数未全部形成可复原台账，未确认字段保留空值。
