param([string]$VitisRoot='D:/Xilinx/Vitis/2023.1',
      [string]$HostCompiler='D:/Xilinx/Vivado/2023.1/tps/mingw/9.3.0/win64.o/nt/bin/gcc.exe')
$ErrorActionPreference='Stop'
$fixedRoot=$PSScriptRoot
$fixedCompiler="$VitisRoot/gnu/aarch32/nt/gcc-arm-none-eabi/bin/arm-none-eabi-gcc.exe"
New-Item -ItemType Directory -Force -Path "$fixedRoot/build","$fixedRoot/reports" | Out-Null
$fixedCommon=@('-std=c11','-O2','-g','-fno-fast-math','-ffp-contract=off','-fno-builtin','-fno-common','-Wall','-Wextra','-Werror','-I',"$fixedRoot/include",'-I',"$fixedRoot/vendor/ra8p1")
$fixedCommon+=@('-I',"$fixedRoot/tests")
$fixedSources=@("$fixedRoot/vendor/ra8p1/urdf_kinematics.c","$fixedRoot/src/arm_kinematics_port.c","$fixedRoot/src/fixed_path.c","$fixedRoot/src/fixed_workflow.c","$fixedRoot/tests/workflow_tests.c","$fixedRoot/src/arm_tool.c","$fixedRoot/src/physical_config.c","$fixedRoot/tests/tool_tests.c","$fixedRoot/src/pick_candidate.c")
$fixedArm=$fixedCommon+@('-mcpu=cortex-a9','-marm','-mfloat-abi=soft','-ffreestanding','-nostdlib','-T',"$fixedRoot/platform/compute.ld",'-x','assembler-with-cpp',"$fixedRoot/platform/start.s",'-x','none',"$fixedRoot/src/tcp_pick_main.c")+$fixedSources+@('-Wl,--start-group','-lm','-lc','-lgcc','-Wl,--end-group',"-Wl,-Map=$fixedRoot/build/tcp_pick_preflight.map",'-o',"$fixedRoot/build/tcp_pick_preflight.elf")
& $fixedCompiler @fixedArm 2>&1 | Tee-Object "$fixedRoot/reports/arm_build.log"
if($LASTEXITCODE -ne 0) {throw 'ARM build failed'}
& $HostCompiler @fixedCommon @fixedSources "$fixedRoot/tests/tcp_host_main.c" '-lm' '-o' "$fixedRoot/build/tcp_pick_host.exe"
if($LASTEXITCODE -ne 0) {throw 'Host build failed'}
& "$fixedRoot/build/tcp_pick_host.exe" "$fixedRoot/reports/host_preflight.bin" "$fixedRoot/reports/host_tool.bin" "$fixedRoot/reports/host_candidate.bin" | Tee-Object "$fixedRoot/reports/host_tests.log"
if($LASTEXITCODE -ne 0) {throw 'Refusal/guard regression failed'}
Write-Host 'Compute-only TCP/bare-Link6 preflight built. Original path and motor start remain BLOCKED. No hardware operations.'
