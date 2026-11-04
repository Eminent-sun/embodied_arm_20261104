# Post-synthesis debug clock connection (UG908), no new timing clocks/exceptions.
# Added with USED_IN_SYNTHESIS=false, USED_IN_IMPLEMENTATION=true and LATE order.
# The input is the existing real 50 MHz Clocking Wizard BUFG net.
connect_debug_port dbg_hub/clk [get_nets can_test_i/clk_pl_clk_out1]
set_property C_CLK_INPUT_FREQ_HZ 50000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
