param([string]$Compiler='D:/Xilinx/Vivado/2023.1/tps/mingw/9.3.0/win64.o/nt/bin/gcc.exe')
$ErrorActionPreference='Stop'
$cartRoot=$PSScriptRoot
python "$cartRoot/tools/prepare_cooperative_solver.py"
if($LASTEXITCODE -ne 0){throw 'Cooperative source failed'}
$cartArgs=@('-std=c11','-O2','-g','-fno-fast-math','-ffp-contract=off','-fno-builtin','-Wall','-Wextra','-Werror','-I',"$cartRoot/include",'-I',"$cartRoot/vendor/ra8p1")
$cartSources=@('build/urdf_kinematics_cooperative.c','src/arm_kinematics_port.c','src/fixed_path.c','src/pick_candidate.c','src/path_plan.c','src/path_executor.c','src/pieper_kinematics.c','src/arm_workflow.c','src/workflow_plan.c','tests/cartesian_tests.c') | ForEach-Object {Join-Path $cartRoot $_}
& $Compiler @cartArgs @cartSources -lm -o "$cartRoot/build/cartesian_tests.exe"
if($LASTEXITCODE -ne 0){throw 'Cartesian test build failed'}
& "$cartRoot/build/cartesian_tests.exe" | Tee-Object "$cartRoot/reports/cartesian_host_tests.log"
if($LASTEXITCODE -ne 0){throw 'Cartesian tests failed'}
& $Compiler @cartArgs -Durdf_kinematics_inverse=urdf_original_inverse -Durdf_kinematics_forward=urdf_original_forward -c "$cartRoot/vendor/ra8p1/urdf_kinematics.c" -o "$cartRoot/build/urdf_original.o"
if($LASTEXITCODE -ne 0){throw 'Reference solver compile failed'}
& $Compiler @cartArgs "$cartRoot/build/urdf_kinematics_cooperative.c" "$cartRoot/src/arm_kinematics_port.c" "$cartRoot/tests/solver_equivalence.c" "$cartRoot/build/urdf_original.o" -lm -o "$cartRoot/build/solver_equivalence.exe"
if($LASTEXITCODE -ne 0){throw 'Solver equivalence compile failed'}
& "$cartRoot/build/solver_equivalence.exe" | Tee-Object "$cartRoot/reports/solver_equivalence.log"
if($LASTEXITCODE -ne 0){throw 'Solver equivalence failed'}
& $Compiler @cartArgs "$cartRoot/build/urdf_kinematics_cooperative.c" "$cartRoot/src/arm_kinematics_port.c" "$cartRoot/src/pieper_kinematics.c" "$cartRoot/tests/pieper_tests.c" -lm -o "$cartRoot/build/pieper_tests.exe"
if($LASTEXITCODE -ne 0){throw 'Pieper tests compile failed'}
& "$cartRoot/build/pieper_tests.exe" | Tee-Object "$cartRoot/reports/pieper_host_tests.log"
if($LASTEXITCODE -ne 0){throw 'Pieper tests failed'}
