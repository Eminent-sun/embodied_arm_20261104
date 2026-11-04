param([string]$HostCompiler='D:/Xilinx/Vivado/2023.1/tps/mingw/9.3.0/win64.o/nt/bin/gcc.exe')
$ErrorActionPreference='Stop'
$pathSoftware=$PSScriptRoot
New-Item -ItemType Directory -Path "$pathSoftware/build","$pathSoftware/reports" -Force | Out-Null
$pathArgs=@('-std=c11','-O2','-g','-fno-fast-math','-ffp-contract=off','-fno-builtin','-fno-common','-Wall','-Wextra','-Werror','-I',"$pathSoftware/include",'-I',"$pathSoftware/vendor/ra8p1","$pathSoftware/vendor/ra8p1/urdf_kinematics.c","$pathSoftware/src/arm_kinematics_port.c","$pathSoftware/src/fixed_path.c","$pathSoftware/src/pick_candidate.c","$pathSoftware/src/path_plan.c","$pathSoftware/src/path_executor.c","$pathSoftware/tests/path_executor_tests.c",'-lm','-o',"$pathSoftware/build/path_executor_tests.exe")
& $HostCompiler @pathArgs 2>&1 | Tee-Object "$pathSoftware/reports/executor_host_build.log"
if($LASTEXITCODE -ne 0){throw 'Executor host build failed'}
& "$pathSoftware/build/path_executor_tests.exe" | Tee-Object "$pathSoftware/reports/executor_host_tests.log"
if($LASTEXITCODE -ne 0){throw 'Executor host regression failed'}
