$ErrorActionPreference='Stop'
$pathRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$pathSim=Join-Path $pathRoot 'simulation/path'
$pathRtl=@(Get-ChildItem (Join-Path $pathRoot 'candidate/rtl') -Filter '*.v' | ForEach-Object FullName)
Push-Location $pathSim
try {
 $pathCompile=& D:/Xilinx/Vivado/2023.1/bin/xvlog.bat -nolog -sv @pathRtl "$pathRoot/candidate/sim/tb_path_pp.sv" 2>&1
 $pathCompile | Set-Content 'tb_path_pp.compile.log'
 if($LASTEXITCODE -ne 0){throw 'PATH compile failed'}
 $pathElab=& D:/Xilinx/Vivado/2023.1/bin/xelab.bat -nolog tb_path_pp -s tb_path_pp 2>&1
 $pathElab | Set-Content 'tb_path_pp.elab.log'
 if($LASTEXITCODE -ne 0){throw 'PATH elaboration failed'}
 $pathRun=& D:/Xilinx/Vivado/2023.1/bin/xsim.bat tb_path_pp -nolog -runall 2>&1
 $pathRun | Set-Content 'tb_path_pp.run.log'
 if($LASTEXITCODE -ne 0 -or ($pathRun -match '(?m)^FAIL\b|Fatal:|ERROR:') -or -not (($pathRun -join "`n").Contains('PASS PATH_PP CONTINUATION AND GUARDS'))){throw 'PATH regression failed'}
 Write-Host ($pathRun | Where-Object {$_ -match 'PASS PATH_PP'})
} finally {Pop-Location}
