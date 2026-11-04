param([string]$VitisRoot='D:/Xilinx/Vitis/2023.1')
$ErrorActionPreference='Stop'
$execRoot=$PSScriptRoot
python "$execRoot/tools/prepare_cooperative_solver.py"
if($LASTEXITCODE -ne 0){throw "Cooperative solver generation failed"}
$execCompiler="$VitisRoot/gnu/aarch32/nt/gcc-arm-none-eabi/bin/arm-none-eabi-gcc.exe"
New-Item -ItemType Directory -Path "$execRoot/build","$execRoot/reports" -Force | Out-Null
$execArgs=@('-std=c11','-O2','-g','-mcpu=cortex-a9','-marm','-mfloat-abi=soft','-ffreestanding','-fno-builtin','-fno-common','-fno-fast-math','-ffp-contract=off','-Wall','-Wextra','-Werror','-nostdlib','-I',"$execRoot/include",'-I',"$execRoot/vendor/ra8p1",'-T',"$execRoot/platform/compute.ld",'-x','assembler-with-cpp',"$execRoot/platform/start.s",'-x','none',"$execRoot/build/urdf_kinematics_cooperative.c","$execRoot/src/arm_kinematics_port.c","$execRoot/src/fixed_path.c","$execRoot/src/pick_candidate.c","$execRoot/src/path_plan.c","$execRoot/src/path_executor.c","$execRoot/src/path_mailbox.c","$execRoot/src/pieper_kinematics.c","$execRoot/src/arm_workflow.c","$execRoot/src/workflow_plan.c","$execRoot/src/workflow_runtime.c","$execRoot/src/gripper.c","$execRoot/src/motion_mailbox.c",'-Wl,--start-group','-lm','-lc','-lgcc','-Wl,--end-group',"-Wl,-Map=$execRoot/build/arm_workflow.map",'-o',"$execRoot/build/arm_workflow.elf")
'' | Set-Content "$execRoot/reports/workflow_arm_build.log"
& $execCompiler @execArgs 2>&1 | Tee-Object -Append "$execRoot/reports/workflow_arm_build.log"
if($LASTEXITCODE -ne 0){throw 'ARM executor build failed'}
'ELF compiled; refreshing console symbols immediately.' | Add-Content "$execRoot/reports/workflow_arm_build.log"
$execNm="$VitisRoot/gnu/aarch32/nt/gcc-arm-none-eabi/bin/arm-none-eabi-nm.exe"
python "$execRoot/tools/refresh_workflow_symbols.py" "$execRoot/build/arm_workflow.elf" $execNm "$execRoot/reports/workflow_symbols.json"
if($LASTEXITCODE -ne 0){throw 'ELF/symbol pairing refresh failed'}
'ARM workflow compilation PASS (-Wall -Wextra -Werror)' | Add-Content "$execRoot/reports/workflow_arm_build.log"
$execInputFiles=@("$execRoot/platform/start.s","$execRoot/platform/compute.ld","$execRoot/build/urdf_kinematics_cooperative.c","$execRoot/build/urdf_model_parameters.h","$execRoot/tools/prepare_cooperative_solver.py")
foreach($execPart in @('src','include','vendor/ra8p1')) {$execInputFiles+=@(Get-ChildItem -LiteralPath "$execRoot/$execPart" -File | Where-Object {$_.Extension -in @('.c','.h')} | ForEach-Object FullName)}
$execInputs=@($execInputFiles | ForEach-Object {@{path=$_.Substring($execRoot.Length+1).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant()}})
@{compiler=(& $execCompiler --version | Select-Object -First 1);ELF_sha256=(Get-FileHash -LiteralPath "$execRoot/build/arm_workflow.elf" -Algorithm SHA256).Hash.ToLowerInvariant();sources=$execInputs} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$execRoot/reports/workflow_build_inputs.json" -Encoding utf8
Write-Host 'ARM arm_workflow.elf built. Boot waits without peripheral access; geometry requires explicit PREVIEW. No automatic enable.'
