# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "ABI_VERSION" -parent ${Page_0}


}

proc update_PARAM_VALUE.ABI_VERSION { PARAM_VALUE.ABI_VERSION } {
	# Procedure called to update ABI_VERSION when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ABI_VERSION { PARAM_VALUE.ABI_VERSION } {
	# Procedure called to validate ABI_VERSION
	return true
}


proc update_MODELPARAM_VALUE.ABI_VERSION { MODELPARAM_VALUE.ABI_VERSION PARAM_VALUE.ABI_VERSION } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ABI_VERSION}] ${MODELPARAM_VALUE.ABI_VERSION}
}

