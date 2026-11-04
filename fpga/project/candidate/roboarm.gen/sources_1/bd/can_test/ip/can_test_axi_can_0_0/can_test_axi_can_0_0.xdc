
################################################################################
# (c) Copyright 2007 - 2011 Xilinx, Inc. All rights reserved.
#
# This file contains confidential and proprietary information
# of Xilinx, Inc. and is protected under U.S. and
# international copyright and other intellectual property
# laws.
#
# DISCLAIMER
# This disclaimer is not a license and does not grant any
# rights to the materials distributed herewith. Except as
# otherwise provided in a valid license issued to you by
# Xilinx, and to the maximum extent permitted by applicable
# law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
# WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
# AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
# BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
# INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
# (2) Xilinx shall not be liable (whether in contract or tort,
# including negligence, or under any other theory of
# liability) for any loss or damage of any kind or nature
# related to, arising under or in connection with these
# materials, including for any direct, or any indirect,
# special, incidental, or consequential loss or damage
# (including loss of data, profits, goodwill, or any type of
# loss or damage suffered as a result of any action brought
# by a third party) even if such damage or loss was
# reasonably foreseeable or Xilinx had been advised of the
# possibility of the same.
#
# CRITICAL APPLICATIONS
# Xilinx products are not designed or intended to be fail-
# safe, or for use in any application requiring fail-safe
# performance, such as life-support or safety devices or
# systems, Class III medical devices, nuclear facilities,
# applications related to the deployment of airbags, or any
# other applications that could lead to death, personal
# injury, or severe property or environmental damage
# (individually and collectively, "Critical
# Applications"). Customer assumes the sole risk and
# liability of any use of Xilinx products in Critical
# Applications, subject only to applicable laws and
# regulations governing limitations on product liability.
#
# THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
# PART OF THIS FILE AT ALL TIMES.
################################################################################


#set false path's
#set_false_path  -from [filter [all_registers  -clock [get_clocks -of_objects [get_ports -quiet s_axi_aclk]]] {NAME =~ *CANCORE_LOGIC_I*}] -to  [filter [all_registers  -clock [get_clocks -of_objects [get_ports -quiet can_clk]]] {NAME =~ *CANCORE_LOGIC_I*}]
#set_false_path  -from [filter [all_registers  -clock [get_clocks -of_objects [get_ports -quiet can_clk]]] {NAME =~ *CANCORE_LOGIC_I*} ] -to  [filter [all_registers  -clock [get_clocks -of_objects [get_ports -quiet s_axi_aclk]]] {NAME =~ *CANCORE_LOGIC_I*}]


##set_false_path -to [get_pins -hierarchical -filter {NAME =~ *cdc_to*/D}]
set_false_path -to [get_pins -of [get_cells -hier -filter name=~*cdc_to*] -filter {REF_PIN_NAME == D}]

set_false_path -from  [get_cells -hierarchical -filter {NAME =~ *CANCORE_LOGIC_I*/IC_REG_BTR*reg[*]}]
set_false_path -from  [get_cells -hierarchical -filter {NAME =~ *CANCORE_LOGIC_I*/IC_REG_BRP*reg[*]}]
##set_false_path -to    [get_pins -hierarchical -filter {NAME =~ *IC_REG_ECR*/D}]
set_false_path -to [get_pins -of [get_cells -hier -filter name=~*IC_REG_ECR*] -filter {REF_PIN_NAME == D}]

set_false_path -from  [get_cells -hierarchical -filter {NAME =~ *CANCORE_LOGIC_I*olsync/OL_FIFO_RST_FS*reg}]
##set_false_path  -to [get_pins -hierarchical -filter {NAME =~ *CANCORE_LOGIC_I*olsync/OL_FIFO_RST_FS*/PRE}]
set_false_path -to [get_pins -of [get_cells -hier -filter name=~*CANCORE_LOGIC_I*olsync/OL_FIFO_RST_FS*] -filter {REF_PIN_NAME == PRE}]

set_false_path -from  [get_cells -hierarchical -filter {NAME =~ *CANCORE_LOGIC_I*olsync/SYNC_TL_RST_FS*reg}]
##set_false_path -to [get_pins -hierarchical -filter {NAME =~ *CANCORE_LOGIC_I*olsync/SYNC_TL_RST_FS*/PRE}]
set_false_path -to [get_pins -of [get_cells -hier -filter name=~*CANCORE_LOGIC_I*olsync/SYNC_TL_RST_FS*] -filter {REF_PIN_NAME == PRE}]

##set_false_path -to [get_pins -hierarchical -filter {NAME =~ *CANCORE_LOGIC_I*/RXF_RGPTR_FS*/CLR}]
##set_false_path -to [get_pins -hierarchical -filter {NAME =~ *CANCORE_LOGIC_I*/TXF_HPB_WPTR_FS*/CLR}]
##set_false_path -to [get_pins -hierarchical -filter {NAME =~ *CANCORE_LOGIC_I*/TXF_WGPTR_FS*/CLR}]
set_false_path -to [get_pins -of [get_cells -hier -filter name=~*CANCORE_LOGIC_I*/RXF_RGPTR_FS*] -filter {REF_PIN_NAME == CLR}]
set_false_path -to [get_pins -of [get_cells -hier -filter name=~*CANCORE_LOGIC_I*/TXF_HPB_WPTR_FS*] -filter {REF_PIN_NAME == CLR}]
set_false_path -to [get_pins -of [get_cells -hier -filter name=~*CANCORE_LOGIC_I*/TXF_WGPTR_FS*] -filter {REF_PIN_NAME == CLR}]


################################################################################
