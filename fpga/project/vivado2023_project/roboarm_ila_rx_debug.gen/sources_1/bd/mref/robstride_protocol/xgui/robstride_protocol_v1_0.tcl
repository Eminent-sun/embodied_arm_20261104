# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "ALLOW_IDENTITY" -parent ${Page_0}
  ipgui::add_param $IPINST -name "CONFIG_ENABLE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "FEEDBACK_TIMEOUT_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "HOST_ID" -parent ${Page_0}
  ipgui::add_param $IPINST -name "MOTOR_IDS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PARAM_TIMEOUT_CYCLES" -parent ${Page_0}


}

proc update_PARAM_VALUE.ALLOW_IDENTITY { PARAM_VALUE.ALLOW_IDENTITY } {
	# Procedure called to update ALLOW_IDENTITY when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ALLOW_IDENTITY { PARAM_VALUE.ALLOW_IDENTITY } {
	# Procedure called to validate ALLOW_IDENTITY
	return true
}

proc update_PARAM_VALUE.CONFIG_ENABLE { PARAM_VALUE.CONFIG_ENABLE } {
	# Procedure called to update CONFIG_ENABLE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.CONFIG_ENABLE { PARAM_VALUE.CONFIG_ENABLE } {
	# Procedure called to validate CONFIG_ENABLE
	return true
}

proc update_PARAM_VALUE.FEEDBACK_TIMEOUT_CYCLES { PARAM_VALUE.FEEDBACK_TIMEOUT_CYCLES } {
	# Procedure called to update FEEDBACK_TIMEOUT_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.FEEDBACK_TIMEOUT_CYCLES { PARAM_VALUE.FEEDBACK_TIMEOUT_CYCLES } {
	# Procedure called to validate FEEDBACK_TIMEOUT_CYCLES
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

proc update_PARAM_VALUE.PARAM_TIMEOUT_CYCLES { PARAM_VALUE.PARAM_TIMEOUT_CYCLES } {
	# Procedure called to update PARAM_TIMEOUT_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PARAM_TIMEOUT_CYCLES { PARAM_VALUE.PARAM_TIMEOUT_CYCLES } {
	# Procedure called to validate PARAM_TIMEOUT_CYCLES
	return true
}


proc update_MODELPARAM_VALUE.CONFIG_ENABLE { MODELPARAM_VALUE.CONFIG_ENABLE PARAM_VALUE.CONFIG_ENABLE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.CONFIG_ENABLE}] ${MODELPARAM_VALUE.CONFIG_ENABLE}
}

proc update_MODELPARAM_VALUE.HOST_ID { MODELPARAM_VALUE.HOST_ID PARAM_VALUE.HOST_ID } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.HOST_ID}] ${MODELPARAM_VALUE.HOST_ID}
}

proc update_MODELPARAM_VALUE.MOTOR_IDS { MODELPARAM_VALUE.MOTOR_IDS PARAM_VALUE.MOTOR_IDS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.MOTOR_IDS}] ${MODELPARAM_VALUE.MOTOR_IDS}
}

proc update_MODELPARAM_VALUE.ALLOW_IDENTITY { MODELPARAM_VALUE.ALLOW_IDENTITY PARAM_VALUE.ALLOW_IDENTITY } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ALLOW_IDENTITY}] ${MODELPARAM_VALUE.ALLOW_IDENTITY}
}

proc update_MODELPARAM_VALUE.FEEDBACK_TIMEOUT_CYCLES { MODELPARAM_VALUE.FEEDBACK_TIMEOUT_CYCLES PARAM_VALUE.FEEDBACK_TIMEOUT_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FEEDBACK_TIMEOUT_CYCLES}] ${MODELPARAM_VALUE.FEEDBACK_TIMEOUT_CYCLES}
}

proc update_MODELPARAM_VALUE.PARAM_TIMEOUT_CYCLES { MODELPARAM_VALUE.PARAM_TIMEOUT_CYCLES PARAM_VALUE.PARAM_TIMEOUT_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PARAM_TIMEOUT_CYCLES}] ${MODELPARAM_VALUE.PARAM_TIMEOUT_CYCLES}
}

