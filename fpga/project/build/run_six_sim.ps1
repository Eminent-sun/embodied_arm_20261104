$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$simDir = Join-Path $root 'simulation/six'
$rtl = @(Get-ChildItem (Join-Path $root 'candidate/rtl') -Filter '*.v' | ForEach-Object FullName)
$models = @(Get-ChildItem (Join-Path $root 'candidate/sim') -Filter '*model.v' | ForEach-Object FullName)
$tests = @(
    @{top='tb_six_pp';file='tb_six_pp.sv';pass='SIX_PP CHECKS'},
    @{top='tb_six_pp_two_turn';file='tb_six_pp_two_turn.sv';pass='TWO_TURN CHECKS'},
    @{top='tb_six_stop_master';file='tb_six_stop_master.sv';pass='PASS SIX STOP MASTER INTEGRATION'}
)
Push-Location $simDir
try {
    foreach($t in $tests) {
        $top = $t.top
        $src = Join-Path $root ('candidate/sim/' + $t.file)
        $compile = & D:/Xilinx/Vivado/2023.1/bin/xvlog.bat -nolog -sv @rtl @models $src 2>&1
        $compile | Set-Content "$top.compile.log"
        if($LASTEXITCODE -ne 0 -or ($compile -match '(^|\s)(ERROR|FATAL):')) {throw "Compile failed: $top"}
        $elab = & D:/Xilinx/Vivado/2023.1/bin/xelab.bat -nolog $top -s $top 2>&1
        $elab | Set-Content "$top.elab.log"
        if($LASTEXITCODE -ne 0 -or ($elab -match '(^|\s)(ERROR|FATAL):')) {throw "Elaboration failed: $top"}
        $run = & D:/Xilinx/Vivado/2023.1/bin/xsim.bat $top -nolog -runall 2>&1
        $run | Set-Content "$top.run.log"
        if($LASTEXITCODE -ne 0 -or ($run -match '(?m)^FAIL\b|Fatal:|ERROR:') -or
            -not (($run -join "`n").Contains($t.pass))) {throw "Simulation failed: $top"}
        Write-Host "$top PASS"
    }
} finally {Pop-Location}
