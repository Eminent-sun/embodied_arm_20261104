$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$simDir = Join-Path $root 'simulation/v21'
$xvlog = 'D:\Xilinx\Vivado\2023.1\bin\xvlog.bat'
$xelab = 'D:\Xilinx\Vivado\2023.1\bin\xelab.bat'
$xsim = 'D:\Xilinx\Vivado\2023.1\bin\xsim.bat'
foreach ($tool in @($xvlog,$xelab,$xsim)) { if (!(Test-Path -LiteralPath $tool)) { throw "Missing $tool" } }
New-Item -ItemType Directory -Path $simDir -Force | Out-Null
$rtl = @(Get-ChildItem -LiteralPath (Join-Path $root 'candidate\rtl') -Filter '*.v' | ForEach-Object FullName)
$models = @(Get-ChildItem -LiteralPath (Join-Path $root 'candidate\sim') -Filter '*model.v' | ForEach-Object FullName)
$testbenches = @(
    @{top='tb_pl_robstride_command_engine';file='tb_pl_robstride_command_engine.v';pass='PASS ALL 30 CHECKS'},
    @{top='tb_v21_protocol_engine';file='tb_v21_protocol_engine.v';pass='PASS ALL 10 CHECKS'},
    @{top='tb_robstride_command_master';file='tb_robstride_command_master.sv';pass='RESULT: PASS V2.1 command/master integration'}
)
Push-Location $simDir
try {
    foreach ($t in $testbenches) {
        $top = $t.top
        $src = Join-Path $root (Join-Path 'candidate\sim' $t.file)
        $compile = & $xvlog -nolog -sv @rtl @models $src 2>&1
        $compile | Set-Content -LiteralPath "$top.compile.log"
        if ($LASTEXITCODE -ne 0 -or ($compile -match '(^|\s)(ERROR|FATAL):')) { throw "Compile failed: $top" }
        $elab = & $xelab -nolog $top -s $top 2>&1
        $elab | Set-Content -LiteralPath "$top.elab.log"
        if ($LASTEXITCODE -ne 0 -or ($elab -match '(^|\s)(ERROR|FATAL):')) { throw "Elaboration failed: $top" }
        $run = & $xsim $top -nolog -runall 2>&1
        $run | Set-Content -LiteralPath "$top.run.log"
        if ($LASTEXITCODE -ne 0 -or ($run -match '(?m)^FAIL\b|Fatal:|ERROR:') -or
            -not (($run -join "`n").Contains($t.pass))) { throw "Simulation failed: $top" }
        Write-Host "$top PASS"
    }
} finally { Pop-Location }
