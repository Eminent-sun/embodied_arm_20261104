param([string]$Compiler='D:/Xilinx/Vivado/2023.1/tps/mingw/9.3.0/win64.o/nt/bin/gcc.exe')
$ErrorActionPreference='Stop'
$wfRoot=$PSScriptRoot
python "$wfRoot/tools/prepare_cooperative_solver.py"
if($LASTEXITCODE -ne 0){throw "Cooperative solver generation failed"}
$wfArgs=@('-std=c11','-O2','-g','-fno-fast-math','-ffp-contract=off','-fno-builtin','-Wall','-Wextra','-Werror','-I',"$wfRoot/include",'-I',"$wfRoot/vendor/ra8p1")
$wfSources=@('build/urdf_kinematics_cooperative.c','src/arm_kinematics_port.c','src/fixed_path.c','src/pick_candidate.c','src/path_plan.c','src/path_executor.c','src/pieper_kinematics.c','src/arm_workflow.c','src/workflow_plan.c','tests/workflow_tests.c') | ForEach-Object {Join-Path $wfRoot $_}
& $Compiler @wfArgs @wfSources -lm -o "$wfRoot/build/workflow_tests.exe" 2>&1 | Tee-Object "$wfRoot/reports/workflow_host_build.log"
if($LASTEXITCODE -ne 0){throw 'Workflow compilation failed'}
& "$wfRoot/build/workflow_tests.exe" | Tee-Object "$wfRoot/reports/workflow_host_tests.log"
if($LASTEXITCODE -ne 0){throw 'Workflow tests failed'}
