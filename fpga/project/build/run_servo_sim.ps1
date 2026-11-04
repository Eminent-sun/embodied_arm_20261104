$ErrorActionPreference='Stop'
$servoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$simDir=Join-Path $servoRoot 'simulation/servo'
New-Item -ItemType Directory -Force $simDir | Out-Null
Push-Location $simDir
try {
    & D:/Xilinx/Vivado/2023.1/bin/xvlog.bat -nolog -sv "$servoRoot/candidate/rtl/pl_servo_axi.v" "$servoRoot/candidate/sim/tb_servo_axi.sv" > compile.log 2>&1
    if($LASTEXITCODE -ne 0){throw 'Servo compile failed'}
    & D:/Xilinx/Vivado/2023.1/bin/xelab.bat -nolog tb_servo_axi -s tb_servo_axi > elab.log 2>&1
    if($LASTEXITCODE -ne 0){throw 'Servo elaboration failed'}
    & D:/Xilinx/Vivado/2023.1/bin/xsim.bat tb_servo_axi -nolog -runall > run.log 2>&1
    if($LASTEXITCODE -ne 0 -or !(Select-String -Path run.log -Pattern 'SERVO_AXI_PASS') -or (Select-String -Path run.log -Pattern 'FAIL|Fatal:|ERROR:')){throw 'Servo simulation failed; inspect simulation/servo/run.log'}
    Select-String -Path run.log -Pattern 'SERVO_AXI_PASS'
} finally {Pop-Location}
