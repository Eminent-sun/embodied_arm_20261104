# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "ENABLE_PERIODIC" -parent ${Page_0}
  ipgui::add_param $IPINST -name "ENABLE_PL_INIT" -parent ${Page_0}
  ipgui::add_param $IPINST -name "ENABLE_RX" -parent ${Page_0}
  ipgui::add_param $IPINST -name "ENABLE_SINGLE_TX" -parent ${Page_0}
  ipgui::add_param $IPINST -name "ENABLE_SIX_AXIS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "INIT_POLL_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "INIT_TIMEOUT_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PERIOD_100HZ_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PERIOD_10HZ_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PERIOD_200HZ_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "POLL_INTERVAL_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "RX_FIFO_DEPTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "RX_POLL_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "SEND_TIMEOUT_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "TIMEOUT_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "TXOK_POLL_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "TXOK_TIMEOUT_CYCLES" -parent ${Page_0}


}

proc update_PARAM_VALUE.ENABLE_PERIODIC { PARAM_VALUE.ENABLE_PERIODIC } {
	# Procedure called to update ENABLE_PERIODIC when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ENABLE_PERIODIC { PARAM_VALUE.ENABLE_PERIODIC } {
	# Procedure called to validate ENABLE_PERIODIC
	return true
}

proc update_PARAM_VALUE.ENABLE_PL_INIT { PARAM_VALUE.ENABLE_PL_INIT } {
	# Procedure called to update ENABLE_PL_INIT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ENABLE_PL_INIT { PARAM_VALUE.ENABLE_PL_INIT } {
	# Procedure called to validate ENABLE_PL_INIT
	return true
}

proc update_PARAM_VALUE.ENABLE_RX { PARAM_VALUE.ENABLE_RX } {
	# Procedure called to update ENABLE_RX when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ENABLE_RX { PARAM_VALUE.ENABLE_RX } {
	# Procedure called to validate ENABLE_RX
	return true
}

proc update_PARAM_VALUE.ENABLE_SINGLE_TX { PARAM_VALUE.ENABLE_SINGLE_TX } {
	# Procedure called to update ENABLE_SINGLE_TX when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ENABLE_SINGLE_TX { PARAM_VALUE.ENABLE_SINGLE_TX } {
	# Procedure called to validate ENABLE_SINGLE_TX
	return true
}

proc update_PARAM_VALUE.ENABLE_SIX_AXIS { PARAM_VALUE.ENABLE_SIX_AXIS } {
	# Procedure called to update ENABLE_SIX_AXIS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ENABLE_SIX_AXIS { PARAM_VALUE.ENABLE_SIX_AXIS } {
	# Procedure called to validate ENABLE_SIX_AXIS
	return true
}

proc update_PARAM_VALUE.INIT_POLL_CYCLES { PARAM_VALUE.INIT_POLL_CYCLES } {
	# Procedure called to update INIT_POLL_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.INIT_POLL_CYCLES { PARAM_VALUE.INIT_POLL_CYCLES } {
	# Procedure called to validate INIT_POLL_CYCLES
	return true
}

proc update_PARAM_VALUE.INIT_TIMEOUT_CYCLES { PARAM_VALUE.INIT_TIMEOUT_CYCLES } {
	# Procedure called to update INIT_TIMEOUT_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.INIT_TIMEOUT_CYCLES { PARAM_VALUE.INIT_TIMEOUT_CYCLES } {
	# Procedure called to validate INIT_TIMEOUT_CYCLES
	return true
}

proc update_PARAM_VALUE.PERIOD_100HZ_CYCLES { PARAM_VALUE.PERIOD_100HZ_CYCLES } {
	# Procedure called to update PERIOD_100HZ_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PERIOD_100HZ_CYCLES { PARAM_VALUE.PERIOD_100HZ_CYCLES } {
	# Procedure called to validate PERIOD_100HZ_CYCLES
	return true
}

proc update_PARAM_VALUE.PERIOD_10HZ_CYCLES { PARAM_VALUE.PERIOD_10HZ_CYCLES } {
	# Procedure called to update PERIOD_10HZ_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PERIOD_10HZ_CYCLES { PARAM_VALUE.PERIOD_10HZ_CYCLES } {
	# Procedure called to validate PERIOD_10HZ_CYCLES
	return true
}

proc update_PARAM_VALUE.PERIOD_200HZ_CYCLES { PARAM_VALUE.PERIOD_200HZ_CYCLES } {
	# Procedure called to update PERIOD_200HZ_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PERIOD_200HZ_CYCLES { PARAM_VALUE.PERIOD_200HZ_CYCLES } {
	# Procedure called to validate PERIOD_200HZ_CYCLES
	return true
}

proc update_PARAM_VALUE.POLL_INTERVAL_CYCLES { PARAM_VALUE.POLL_INTERVAL_CYCLES } {
	# Procedure called to update POLL_INTERVAL_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.POLL_INTERVAL_CYCLES { PARAM_VALUE.POLL_INTERVAL_CYCLES } {
	# Procedure called to validate POLL_INTERVAL_CYCLES
	return true
}

proc update_PARAM_VALUE.RX_FIFO_DEPTH { PARAM_VALUE.RX_FIFO_DEPTH } {
	# Procedure called to update RX_FIFO_DEPTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.RX_FIFO_DEPTH { PARAM_VALUE.RX_FIFO_DEPTH } {
	# Procedure called to validate RX_FIFO_DEPTH
	return true
}

proc update_PARAM_VALUE.RX_POLL_CYCLES { PARAM_VALUE.RX_POLL_CYCLES } {
	# Procedure called to update RX_POLL_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.RX_POLL_CYCLES { PARAM_VALUE.RX_POLL_CYCLES } {
	# Procedure called to validate RX_POLL_CYCLES
	return true
}

proc update_PARAM_VALUE.SEND_TIMEOUT_CYCLES { PARAM_VALUE.SEND_TIMEOUT_CYCLES } {
	# Procedure called to update SEND_TIMEOUT_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SEND_TIMEOUT_CYCLES { PARAM_VALUE.SEND_TIMEOUT_CYCLES } {
	# Procedure called to validate SEND_TIMEOUT_CYCLES
	return true
}

proc update_PARAM_VALUE.TIMEOUT_CYCLES { PARAM_VALUE.TIMEOUT_CYCLES } {
	# Procedure called to update TIMEOUT_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TIMEOUT_CYCLES { PARAM_VALUE.TIMEOUT_CYCLES } {
	# Procedure called to validate TIMEOUT_CYCLES
	return true
}

proc update_PARAM_VALUE.TXOK_POLL_CYCLES { PARAM_VALUE.TXOK_POLL_CYCLES } {
	# Procedure called to update TXOK_POLL_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TXOK_POLL_CYCLES { PARAM_VALUE.TXOK_POLL_CYCLES } {
	# Procedure called to validate TXOK_POLL_CYCLES
	return true
}

proc update_PARAM_VALUE.TXOK_TIMEOUT_CYCLES { PARAM_VALUE.TXOK_TIMEOUT_CYCLES } {
	# Procedure called to update TXOK_TIMEOUT_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TXOK_TIMEOUT_CYCLES { PARAM_VALUE.TXOK_TIMEOUT_CYCLES } {
	# Procedure called to validate TXOK_TIMEOUT_CYCLES
	return true
}


proc update_MODELPARAM_VALUE.POLL_INTERVAL_CYCLES { MODELPARAM_VALUE.POLL_INTERVAL_CYCLES PARAM_VALUE.POLL_INTERVAL_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.POLL_INTERVAL_CYCLES}] ${MODELPARAM_VALUE.POLL_INTERVAL_CYCLES}
}

proc update_MODELPARAM_VALUE.TIMEOUT_CYCLES { MODELPARAM_VALUE.TIMEOUT_CYCLES PARAM_VALUE.TIMEOUT_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TIMEOUT_CYCLES}] ${MODELPARAM_VALUE.TIMEOUT_CYCLES}
}

proc update_MODELPARAM_VALUE.TXOK_TIMEOUT_CYCLES { MODELPARAM_VALUE.TXOK_TIMEOUT_CYCLES PARAM_VALUE.TXOK_TIMEOUT_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TXOK_TIMEOUT_CYCLES}] ${MODELPARAM_VALUE.TXOK_TIMEOUT_CYCLES}
}

proc update_MODELPARAM_VALUE.SEND_TIMEOUT_CYCLES { MODELPARAM_VALUE.SEND_TIMEOUT_CYCLES PARAM_VALUE.SEND_TIMEOUT_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SEND_TIMEOUT_CYCLES}] ${MODELPARAM_VALUE.SEND_TIMEOUT_CYCLES}
}

proc update_MODELPARAM_VALUE.ENABLE_PL_INIT { MODELPARAM_VALUE.ENABLE_PL_INIT PARAM_VALUE.ENABLE_PL_INIT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ENABLE_PL_INIT}] ${MODELPARAM_VALUE.ENABLE_PL_INIT}
}

proc update_MODELPARAM_VALUE.INIT_TIMEOUT_CYCLES { MODELPARAM_VALUE.INIT_TIMEOUT_CYCLES PARAM_VALUE.INIT_TIMEOUT_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.INIT_TIMEOUT_CYCLES}] ${MODELPARAM_VALUE.INIT_TIMEOUT_CYCLES}
}

proc update_MODELPARAM_VALUE.INIT_POLL_CYCLES { MODELPARAM_VALUE.INIT_POLL_CYCLES PARAM_VALUE.INIT_POLL_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.INIT_POLL_CYCLES}] ${MODELPARAM_VALUE.INIT_POLL_CYCLES}
}

proc update_MODELPARAM_VALUE.ENABLE_PERIODIC { MODELPARAM_VALUE.ENABLE_PERIODIC PARAM_VALUE.ENABLE_PERIODIC } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ENABLE_PERIODIC}] ${MODELPARAM_VALUE.ENABLE_PERIODIC}
}

proc update_MODELPARAM_VALUE.PERIOD_10HZ_CYCLES { MODELPARAM_VALUE.PERIOD_10HZ_CYCLES PARAM_VALUE.PERIOD_10HZ_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PERIOD_10HZ_CYCLES}] ${MODELPARAM_VALUE.PERIOD_10HZ_CYCLES}
}

proc update_MODELPARAM_VALUE.PERIOD_100HZ_CYCLES { MODELPARAM_VALUE.PERIOD_100HZ_CYCLES PARAM_VALUE.PERIOD_100HZ_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PERIOD_100HZ_CYCLES}] ${MODELPARAM_VALUE.PERIOD_100HZ_CYCLES}
}

proc update_MODELPARAM_VALUE.PERIOD_200HZ_CYCLES { MODELPARAM_VALUE.PERIOD_200HZ_CYCLES PARAM_VALUE.PERIOD_200HZ_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PERIOD_200HZ_CYCLES}] ${MODELPARAM_VALUE.PERIOD_200HZ_CYCLES}
}

proc update_MODELPARAM_VALUE.TXOK_POLL_CYCLES { MODELPARAM_VALUE.TXOK_POLL_CYCLES PARAM_VALUE.TXOK_POLL_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TXOK_POLL_CYCLES}] ${MODELPARAM_VALUE.TXOK_POLL_CYCLES}
}

proc update_MODELPARAM_VALUE.ENABLE_SIX_AXIS { MODELPARAM_VALUE.ENABLE_SIX_AXIS PARAM_VALUE.ENABLE_SIX_AXIS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ENABLE_SIX_AXIS}] ${MODELPARAM_VALUE.ENABLE_SIX_AXIS}
}

proc update_MODELPARAM_VALUE.ENABLE_RX { MODELPARAM_VALUE.ENABLE_RX PARAM_VALUE.ENABLE_RX } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ENABLE_RX}] ${MODELPARAM_VALUE.ENABLE_RX}
}

proc update_MODELPARAM_VALUE.RX_POLL_CYCLES { MODELPARAM_VALUE.RX_POLL_CYCLES PARAM_VALUE.RX_POLL_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.RX_POLL_CYCLES}] ${MODELPARAM_VALUE.RX_POLL_CYCLES}
}

proc update_MODELPARAM_VALUE.RX_FIFO_DEPTH { MODELPARAM_VALUE.RX_FIFO_DEPTH PARAM_VALUE.RX_FIFO_DEPTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.RX_FIFO_DEPTH}] ${MODELPARAM_VALUE.RX_FIFO_DEPTH}
}

proc update_MODELPARAM_VALUE.ENABLE_SINGLE_TX { MODELPARAM_VALUE.ENABLE_SINGLE_TX PARAM_VALUE.ENABLE_SINGLE_TX } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ENABLE_SINGLE_TX}] ${MODELPARAM_VALUE.ENABLE_SINGLE_TX}
}

