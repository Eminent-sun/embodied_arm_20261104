# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "CANCEL_TIMEOUT_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "ENABLE_HOLD_PP" -parent ${Page_0}
  ipgui::add_param $IPINST -name "ENABLE_MULTI_PP" -parent ${Page_0}
  ipgui::add_param $IPINST -name "ENABLE_PATH_PP" -parent ${Page_0}
  ipgui::add_param $IPINST -name "ENABLE_PP_TEST" -parent ${Page_0}
  ipgui::add_param $IPINST -name "HOST_ID" -parent ${Page_0}
  ipgui::add_param $IPINST -name "MOTOR_IDS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PATH_LEASE_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PATH_MAX_STEP_Q16" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PATH_POSITION_AGE_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PATH_WINDOW_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PP_MAX_ACCEL_BITS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PP_MAX_DELTA_Q16" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PP_MAX_SPEED_BITS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PP_POSITION_AGE_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PP_WINDOW_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "REG_TIMEOUT_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "REPLY_TIMEOUT_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "TX_ACCEPT_TIMEOUT_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "TX_RESULT_TIMEOUT_CYCLES" -parent ${Page_0}


}

proc update_PARAM_VALUE.CANCEL_TIMEOUT_CYCLES { PARAM_VALUE.CANCEL_TIMEOUT_CYCLES } {
	# Procedure called to update CANCEL_TIMEOUT_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.CANCEL_TIMEOUT_CYCLES { PARAM_VALUE.CANCEL_TIMEOUT_CYCLES } {
	# Procedure called to validate CANCEL_TIMEOUT_CYCLES
	return true
}

proc update_PARAM_VALUE.ENABLE_HOLD_PP { PARAM_VALUE.ENABLE_HOLD_PP } {
	# Procedure called to update ENABLE_HOLD_PP when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ENABLE_HOLD_PP { PARAM_VALUE.ENABLE_HOLD_PP } {
	# Procedure called to validate ENABLE_HOLD_PP
	return true
}

proc update_PARAM_VALUE.ENABLE_MULTI_PP { PARAM_VALUE.ENABLE_MULTI_PP } {
	# Procedure called to update ENABLE_MULTI_PP when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ENABLE_MULTI_PP { PARAM_VALUE.ENABLE_MULTI_PP } {
	# Procedure called to validate ENABLE_MULTI_PP
	return true
}

proc update_PARAM_VALUE.ENABLE_PATH_PP { PARAM_VALUE.ENABLE_PATH_PP } {
	# Procedure called to update ENABLE_PATH_PP when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ENABLE_PATH_PP { PARAM_VALUE.ENABLE_PATH_PP } {
	# Procedure called to validate ENABLE_PATH_PP
	return true
}

proc update_PARAM_VALUE.ENABLE_PP_TEST { PARAM_VALUE.ENABLE_PP_TEST } {
	# Procedure called to update ENABLE_PP_TEST when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ENABLE_PP_TEST { PARAM_VALUE.ENABLE_PP_TEST } {
	# Procedure called to validate ENABLE_PP_TEST
	return true
}

proc update_PARAM_VALUE.HOST_ID { PARAM_VALUE.HOST_ID } {
	# Procedure called to update HOST_ID when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.HOST_ID { PARAM_VALUE.HOST_ID } {
	# Procedure called to validate HOST_ID
	return true
}

proc update_PARAM_VALUE.MOTOR_IDS { PARAM_VALUE.MOTOR_IDS } {
	# Procedure called to update MOTOR_IDS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.MOTOR_IDS { PARAM_VALUE.MOTOR_IDS } {
	# Procedure called to validate MOTOR_IDS
	return true
}

proc update_PARAM_VALUE.PATH_LEASE_CYCLES { PARAM_VALUE.PATH_LEASE_CYCLES } {
	# Procedure called to update PATH_LEASE_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PATH_LEASE_CYCLES { PARAM_VALUE.PATH_LEASE_CYCLES } {
	# Procedure called to validate PATH_LEASE_CYCLES
	return true
}

proc update_PARAM_VALUE.PATH_MAX_STEP_Q16 { PARAM_VALUE.PATH_MAX_STEP_Q16 } {
	# Procedure called to update PATH_MAX_STEP_Q16 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PATH_MAX_STEP_Q16 { PARAM_VALUE.PATH_MAX_STEP_Q16 } {
	# Procedure called to validate PATH_MAX_STEP_Q16
	return true
}

proc update_PARAM_VALUE.PATH_POSITION_AGE_CYCLES { PARAM_VALUE.PATH_POSITION_AGE_CYCLES } {
	# Procedure called to update PATH_POSITION_AGE_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PATH_POSITION_AGE_CYCLES { PARAM_VALUE.PATH_POSITION_AGE_CYCLES } {
	# Procedure called to validate PATH_POSITION_AGE_CYCLES
	return true
}

proc update_PARAM_VALUE.PATH_WINDOW_CYCLES { PARAM_VALUE.PATH_WINDOW_CYCLES } {
	# Procedure called to update PATH_WINDOW_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PATH_WINDOW_CYCLES { PARAM_VALUE.PATH_WINDOW_CYCLES } {
	# Procedure called to validate PATH_WINDOW_CYCLES
	return true
}

proc update_PARAM_VALUE.PP_MAX_ACCEL_BITS { PARAM_VALUE.PP_MAX_ACCEL_BITS } {
	# Procedure called to update PP_MAX_ACCEL_BITS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PP_MAX_ACCEL_BITS { PARAM_VALUE.PP_MAX_ACCEL_BITS } {
	# Procedure called to validate PP_MAX_ACCEL_BITS
	return true
}

proc update_PARAM_VALUE.PP_MAX_DELTA_Q16 { PARAM_VALUE.PP_MAX_DELTA_Q16 } {
	# Procedure called to update PP_MAX_DELTA_Q16 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PP_MAX_DELTA_Q16 { PARAM_VALUE.PP_MAX_DELTA_Q16 } {
	# Procedure called to validate PP_MAX_DELTA_Q16
	return true
}

proc update_PARAM_VALUE.PP_MAX_SPEED_BITS { PARAM_VALUE.PP_MAX_SPEED_BITS } {
	# Procedure called to update PP_MAX_SPEED_BITS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PP_MAX_SPEED_BITS { PARAM_VALUE.PP_MAX_SPEED_BITS } {
	# Procedure called to validate PP_MAX_SPEED_BITS
	return true
}

proc update_PARAM_VALUE.PP_POSITION_AGE_CYCLES { PARAM_VALUE.PP_POSITION_AGE_CYCLES } {
	# Procedure called to update PP_POSITION_AGE_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PP_POSITION_AGE_CYCLES { PARAM_VALUE.PP_POSITION_AGE_CYCLES } {
	# Procedure called to validate PP_POSITION_AGE_CYCLES
	return true
}

proc update_PARAM_VALUE.PP_WINDOW_CYCLES { PARAM_VALUE.PP_WINDOW_CYCLES } {
	# Procedure called to update PP_WINDOW_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PP_WINDOW_CYCLES { PARAM_VALUE.PP_WINDOW_CYCLES } {
	# Procedure called to validate PP_WINDOW_CYCLES
	return true
}

proc update_PARAM_VALUE.REG_TIMEOUT_CYCLES { PARAM_VALUE.REG_TIMEOUT_CYCLES } {
	# Procedure called to update REG_TIMEOUT_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.REG_TIMEOUT_CYCLES { PARAM_VALUE.REG_TIMEOUT_CYCLES } {
	# Procedure called to validate REG_TIMEOUT_CYCLES
	return true
}

proc update_PARAM_VALUE.REPLY_TIMEOUT_CYCLES { PARAM_VALUE.REPLY_TIMEOUT_CYCLES } {
	# Procedure called to update REPLY_TIMEOUT_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.REPLY_TIMEOUT_CYCLES { PARAM_VALUE.REPLY_TIMEOUT_CYCLES } {
	# Procedure called to validate REPLY_TIMEOUT_CYCLES
	return true
}

proc update_PARAM_VALUE.TX_ACCEPT_TIMEOUT_CYCLES { PARAM_VALUE.TX_ACCEPT_TIMEOUT_CYCLES } {
	# Procedure called to update TX_ACCEPT_TIMEOUT_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TX_ACCEPT_TIMEOUT_CYCLES { PARAM_VALUE.TX_ACCEPT_TIMEOUT_CYCLES } {
	# Procedure called to validate TX_ACCEPT_TIMEOUT_CYCLES
	return true
}

proc update_PARAM_VALUE.TX_RESULT_TIMEOUT_CYCLES { PARAM_VALUE.TX_RESULT_TIMEOUT_CYCLES } {
	# Procedure called to update TX_RESULT_TIMEOUT_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TX_RESULT_TIMEOUT_CYCLES { PARAM_VALUE.TX_RESULT_TIMEOUT_CYCLES } {
	# Procedure called to validate TX_RESULT_TIMEOUT_CYCLES
	return true
}


proc update_MODELPARAM_VALUE.HOST_ID { MODELPARAM_VALUE.HOST_ID PARAM_VALUE.HOST_ID } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.HOST_ID}] ${MODELPARAM_VALUE.HOST_ID}
}

proc update_MODELPARAM_VALUE.MOTOR_IDS { MODELPARAM_VALUE.MOTOR_IDS PARAM_VALUE.MOTOR_IDS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.MOTOR_IDS}] ${MODELPARAM_VALUE.MOTOR_IDS}
}

proc update_MODELPARAM_VALUE.REG_TIMEOUT_CYCLES { MODELPARAM_VALUE.REG_TIMEOUT_CYCLES PARAM_VALUE.REG_TIMEOUT_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.REG_TIMEOUT_CYCLES}] ${MODELPARAM_VALUE.REG_TIMEOUT_CYCLES}
}

proc update_MODELPARAM_VALUE.TX_ACCEPT_TIMEOUT_CYCLES { MODELPARAM_VALUE.TX_ACCEPT_TIMEOUT_CYCLES PARAM_VALUE.TX_ACCEPT_TIMEOUT_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TX_ACCEPT_TIMEOUT_CYCLES}] ${MODELPARAM_VALUE.TX_ACCEPT_TIMEOUT_CYCLES}
}

proc update_MODELPARAM_VALUE.TX_RESULT_TIMEOUT_CYCLES { MODELPARAM_VALUE.TX_RESULT_TIMEOUT_CYCLES PARAM_VALUE.TX_RESULT_TIMEOUT_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TX_RESULT_TIMEOUT_CYCLES}] ${MODELPARAM_VALUE.TX_RESULT_TIMEOUT_CYCLES}
}

proc update_MODELPARAM_VALUE.REPLY_TIMEOUT_CYCLES { MODELPARAM_VALUE.REPLY_TIMEOUT_CYCLES PARAM_VALUE.REPLY_TIMEOUT_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.REPLY_TIMEOUT_CYCLES}] ${MODELPARAM_VALUE.REPLY_TIMEOUT_CYCLES}
}

proc update_MODELPARAM_VALUE.CANCEL_TIMEOUT_CYCLES { MODELPARAM_VALUE.CANCEL_TIMEOUT_CYCLES PARAM_VALUE.CANCEL_TIMEOUT_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.CANCEL_TIMEOUT_CYCLES}] ${MODELPARAM_VALUE.CANCEL_TIMEOUT_CYCLES}
}

proc update_MODELPARAM_VALUE.ENABLE_PP_TEST { MODELPARAM_VALUE.ENABLE_PP_TEST PARAM_VALUE.ENABLE_PP_TEST } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ENABLE_PP_TEST}] ${MODELPARAM_VALUE.ENABLE_PP_TEST}
}

proc update_MODELPARAM_VALUE.ENABLE_MULTI_PP { MODELPARAM_VALUE.ENABLE_MULTI_PP PARAM_VALUE.ENABLE_MULTI_PP } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ENABLE_MULTI_PP}] ${MODELPARAM_VALUE.ENABLE_MULTI_PP}
}

proc update_MODELPARAM_VALUE.ENABLE_PATH_PP { MODELPARAM_VALUE.ENABLE_PATH_PP PARAM_VALUE.ENABLE_PATH_PP } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ENABLE_PATH_PP}] ${MODELPARAM_VALUE.ENABLE_PATH_PP}
}

proc update_MODELPARAM_VALUE.ENABLE_HOLD_PP { MODELPARAM_VALUE.ENABLE_HOLD_PP PARAM_VALUE.ENABLE_HOLD_PP } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ENABLE_HOLD_PP}] ${MODELPARAM_VALUE.ENABLE_HOLD_PP}
}

proc update_MODELPARAM_VALUE.PATH_WINDOW_CYCLES { MODELPARAM_VALUE.PATH_WINDOW_CYCLES PARAM_VALUE.PATH_WINDOW_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PATH_WINDOW_CYCLES}] ${MODELPARAM_VALUE.PATH_WINDOW_CYCLES}
}

proc update_MODELPARAM_VALUE.PATH_LEASE_CYCLES { MODELPARAM_VALUE.PATH_LEASE_CYCLES PARAM_VALUE.PATH_LEASE_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PATH_LEASE_CYCLES}] ${MODELPARAM_VALUE.PATH_LEASE_CYCLES}
}

proc update_MODELPARAM_VALUE.PATH_POSITION_AGE_CYCLES { MODELPARAM_VALUE.PATH_POSITION_AGE_CYCLES PARAM_VALUE.PATH_POSITION_AGE_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PATH_POSITION_AGE_CYCLES}] ${MODELPARAM_VALUE.PATH_POSITION_AGE_CYCLES}
}

proc update_MODELPARAM_VALUE.PATH_MAX_STEP_Q16 { MODELPARAM_VALUE.PATH_MAX_STEP_Q16 PARAM_VALUE.PATH_MAX_STEP_Q16 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PATH_MAX_STEP_Q16}] ${MODELPARAM_VALUE.PATH_MAX_STEP_Q16}
}

proc update_MODELPARAM_VALUE.PP_MAX_DELTA_Q16 { MODELPARAM_VALUE.PP_MAX_DELTA_Q16 PARAM_VALUE.PP_MAX_DELTA_Q16 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PP_MAX_DELTA_Q16}] ${MODELPARAM_VALUE.PP_MAX_DELTA_Q16}
}

proc update_MODELPARAM_VALUE.PP_MAX_SPEED_BITS { MODELPARAM_VALUE.PP_MAX_SPEED_BITS PARAM_VALUE.PP_MAX_SPEED_BITS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PP_MAX_SPEED_BITS}] ${MODELPARAM_VALUE.PP_MAX_SPEED_BITS}
}

proc update_MODELPARAM_VALUE.PP_MAX_ACCEL_BITS { MODELPARAM_VALUE.PP_MAX_ACCEL_BITS PARAM_VALUE.PP_MAX_ACCEL_BITS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PP_MAX_ACCEL_BITS}] ${MODELPARAM_VALUE.PP_MAX_ACCEL_BITS}
}

proc update_MODELPARAM_VALUE.PP_WINDOW_CYCLES { MODELPARAM_VALUE.PP_WINDOW_CYCLES PARAM_VALUE.PP_WINDOW_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PP_WINDOW_CYCLES}] ${MODELPARAM_VALUE.PP_WINDOW_CYCLES}
}

proc update_MODELPARAM_VALUE.PP_POSITION_AGE_CYCLES { MODELPARAM_VALUE.PP_POSITION_AGE_CYCLES PARAM_VALUE.PP_POSITION_AGE_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PP_POSITION_AGE_CYCLES}] ${MODELPARAM_VALUE.PP_POSITION_AGE_CYCLES}
}

