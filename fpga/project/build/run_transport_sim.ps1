$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$simDir = Join-Path $root 'simulation/transport'
New-Item -ItemType Directory -Force $simDir | Out-Null
$rtl = @(Get-ChildItem (Join-Path $root 'candidate/rtl') -Filter '*.v' | ForEach-Object FullName)
$models = @(Get-ChildItem (Join-Path $root 'candidate/sim') -Filter '*model.v' | ForEach-Object FullName)
$tests = @(
    @{top='tb_robstride_protocol';pass='RESULT: PASS ('},
    @{top='tb_can_rx_service';pass='RESULT: PASS'},
    @{top='tb_can_six_axis_tx';pass='RESULT: PASS SIX_AXIS'}
)
Push-Location $simDir
try {
    foreach($t in $tests) {
        $top = $t.top
        $src = Join-Path $root ('candidate/sim/' + $top + '.v')
        $compile = & D:/Xilinx/Vivado/2023.1/bin/xvlog.bat -nolog @rtl @models $src 2>&1
        $compile | Set-Content "$top.compile.log"
        if($LASTEXITCODE -ne 0 -or ($compile -match 'ERROR:|FATAL:')) {throw "Compile failed: $top"}
        $elab = & D:/Xilinx/Vivado/2023.1/bin/xelab.bat -nolog $top -s $top 2>&1
        $elab | Set-Content "$top.elab.log"
        if($LASTEXITCODE -ne 0 -or ($elab -match 'ERROR:|FATAL:')) {throw "Elaboration failed: $top"}
        $run = & D:/Xilinx/Vivado/2023.1/bin/xsim.bat $top -nolog -runall 2>&1
        $run | Set-Content "$top.run.log"
        if($LASTEXITCODE -ne 0 -or ($run -match '(?m)^FAIL\b|RESULT: FAIL|Fatal:|ERROR:') -or
            -not (($run -join "`n").Contains($t.pass))) {throw "Simulation failed: $top"}
        Write-Host "$top PASS"
    }
} finally {Pop-Location}
