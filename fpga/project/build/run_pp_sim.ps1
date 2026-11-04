$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$simDir = Join-Path $root 'simulation/pp'
$rtl = @(Get-ChildItem (Join-Path $root 'candidate/rtl') -Filter '*.v' | ForEach-Object FullName)
$models = @(Get-ChildItem (Join-Path $root 'candidate/sim') -Filter '*model.v' | ForEach-Object FullName)
$tests = @(
    @{top='tb_pp_commissioning';file='tb_pp_commissioning.v';pass='PASS ALL 79 PP CHECKS'},
    @{top='tb_pp_master';file='tb_pp_master.sv';pass='PASS PP MASTER INTEGRATION'}
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
