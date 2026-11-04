-- (c) Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- (c) Copyright 2022-2026 Advanced Micro Devices, Inc. All rights reserved.
-- 
-- This file contains confidential and proprietary information
-- of AMD and is protected under U.S. and international copyright
-- and other intellectual property laws.
-- 
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- AMD, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) AMD shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or AMD had been advised of the
-- possibility of the same.
-- 
-- CRITICAL APPLICATIONS
-- AMD products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of AMD products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
-- 
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
-- 
-- DO NOT MODIFY THIS FILE.

-- IP VLNV: xilinx.com:ip:can:5.1
-- IP Revision: 0

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY can_v5_1_0;
USE can_v5_1_0.can_v5_1_0;

ENTITY can_test_axi_can_0_0 IS
  PORT (
    can_clk : IN STD_LOGIC;
    can_phy_rx : IN STD_LOGIC;
    can_phy_tx : OUT STD_LOGIC;
    ip2bus_intrevent : OUT STD_LOGIC;
    s_axi_aclk : IN STD_LOGIC;
    s_axi_aresetn : IN STD_LOGIC;
    s_axi_awaddr : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    s_axi_awvalid : IN STD_LOGIC;
    s_axi_awready : OUT STD_LOGIC;
    s_axi_wdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axi_wstrb : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    s_axi_wvalid : IN STD_LOGIC;
    s_axi_wready : OUT STD_LOGIC;
    s_axi_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    s_axi_bvalid : OUT STD_LOGIC;
    s_axi_bready : IN STD_LOGIC;
    s_axi_araddr : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    s_axi_arvalid : IN STD_LOGIC;
    s_axi_arready : OUT STD_LOGIC;
    s_axi_rdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axi_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    s_axi_rvalid : OUT STD_LOGIC;
    s_axi_rready : IN STD_LOGIC
  );
END can_test_axi_can_0_0;

ARCHITECTURE can_test_axi_can_0_0_arch OF can_test_axi_can_0_0 IS
  ATTRIBUTE DowngradeIPIdentifiedWarnings : STRING;
  ATTRIBUTE DowngradeIPIdentifiedWarnings OF can_test_axi_can_0_0_arch: ARCHITECTURE IS "yes";
  COMPONENT can_v5_1_0 IS
    GENERIC (
      c_can_rx_dpth : INTEGER;
      c_can_tx_dpth : INTEGER;
      c_can_num_acf : INTEGER;
      c_c2s_mtbf_stages : INTEGER;
      c_s2c_mtbf_stages : INTEGER;
      c_s_axi_addr_width : INTEGER;
      c_s_axi_data_width : INTEGER;
      c_family : STRING;
      c_enable_ecc_tx_tl : INTEGER;
      c_enable_ecc_tx_ol : INTEGER;
      c_enable_ecc_rx : INTEGER;
      c_has_ecc_err_inject_tx_tl : INTEGER;
      c_has_ecc_err_inject_tx_ol : INTEGER;
      c_has_ecc_err_inject_rx : INTEGER
    );
    PORT (
      can_clk : IN STD_LOGIC;
      can_phy_rx : IN STD_LOGIC;
      can_phy_tx : OUT STD_LOGIC;
      ip2bus_intrevent : OUT STD_LOGIC;
      s_axi_aclk : IN STD_LOGIC;
      s_axi_aresetn : IN STD_LOGIC;
      s_axi_awaddr : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      s_axi_awvalid : IN STD_LOGIC;
      s_axi_awready : OUT STD_LOGIC;
      s_axi_wdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      s_axi_wstrb : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      s_axi_wvalid : IN STD_LOGIC;
      s_axi_wready : OUT STD_LOGIC;
      s_axi_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      s_axi_bvalid : OUT STD_LOGIC;
      s_axi_bready : IN STD_LOGIC;
      s_axi_araddr : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      s_axi_arvalid : IN STD_LOGIC;
      s_axi_arready : OUT STD_LOGIC;
      s_axi_rdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
      s_axi_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      s_axi_rvalid : OUT STD_LOGIC;
      s_axi_rready : IN STD_LOGIC
    );
  END COMPONENT can_v5_1_0;
  ATTRIBUTE X_CORE_INFO : STRING;
  ATTRIBUTE X_CORE_INFO OF can_test_axi_can_0_0_arch: ARCHITECTURE IS "can_v5_1_0,Vivado 2023.1";
  ATTRIBUTE CHECK_LICENSE_TYPE : STRING;
  ATTRIBUTE CHECK_LICENSE_TYPE OF can_test_axi_can_0_0_arch : ARCHITECTURE IS "can_test_axi_can_0_0,can_v5_1_0,{}";
  ATTRIBUTE CORE_GENERATION_INFO : STRING;
  ATTRIBUTE CORE_GENERATION_INFO OF can_test_axi_can_0_0_arch: ARCHITECTURE IS "can_test_axi_can_0_0,can_v5_1_0,{x_ipProduct=Vivado 2023.1,x_ipVendor=xilinx.com,x_ipLibrary=ip,x_ipName=can,x_ipVersion=5.1,x_ipCoreRevision=0,x_ipLanguage=VERILOG,x_ipSimLanguage=MIXED,c_can_rx_dpth=2,c_can_tx_dpth=2,c_can_num_acf=0,c_c2s_mtbf_stages=2,c_s2c_mtbf_stages=2,c_s_axi_addr_width=8,c_s_axi_data_width=32,c_family=zynq,c_enable_ecc_tx_tl=0,c_enable_ecc_tx_ol=0,c_enable_ecc_rx=0,c_has_ecc_err_inject_tx_tl=0,c_has_ecc_err_inject_tx_ol=0,c_has_ecc_err_inject_rx=0,x_ipLicense=can@2023.04(" & 
"bought)}";
  ATTRIBUTE X_INTERFACE_INFO : STRING;
  ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
  ATTRIBUTE X_INTERFACE_INFO OF can_clk: SIGNAL IS "xilinx.com:interface:can:1.0 CAN_INTERFACE CLK";
  ATTRIBUTE X_INTERFACE_INFO OF can_phy_rx: SIGNAL IS "xilinx.com:interface:can:1.0 CAN_INTERFACE RX";
  ATTRIBUTE X_INTERFACE_INFO OF can_phy_tx: SIGNAL IS "xilinx.com:interface:can:1.0 CAN_INTERFACE TX";
  ATTRIBUTE X_INTERFACE_PARAMETER OF ip2bus_intrevent: SIGNAL IS "XIL_INTERFACENAME interrupt, SENSITIVITY LEVEL_HIGH, PORTWIDTH 1";
  ATTRIBUTE X_INTERFACE_INFO OF ip2bus_intrevent: SIGNAL IS "xilinx.com:signal:interrupt:1.0 interrupt INTERRUPT";
  ATTRIBUTE X_INTERFACE_PARAMETER OF s_axi_aclk: SIGNAL IS "XIL_INTERFACENAME s_axi_aclk, ASSOCIATED_BUSIF CAN_S_AXI_LITE, ASSOCIATED_RESET s_axi_aresetn, FREQ_HZ 50000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN /clk_pl_clk_out1, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_aclk: SIGNAL IS "xilinx.com:signal:clock:1.0 s_axi_aclk CLK";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_araddr: SIGNAL IS "xilinx.com:interface:aximm:1.0 CAN_S_AXI_LITE ARADDR";
  ATTRIBUTE X_INTERFACE_PARAMETER OF s_axi_aresetn: SIGNAL IS "XIL_INTERFACENAME s_axi_aresetn, POLARITY ACTIVE_LOW, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_aresetn: SIGNAL IS "xilinx.com:signal:reset:1.0 s_axi_aresetn RST";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_arready: SIGNAL IS "xilinx.com:interface:aximm:1.0 CAN_S_AXI_LITE ARREADY";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_arvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 CAN_S_AXI_LITE ARVALID";
  ATTRIBUTE X_INTERFACE_PARAMETER OF s_axi_awaddr: SIGNAL IS "XIL_INTERFACENAME CAN_S_AXI_LITE, DATA_WIDTH 32, PROTOCOL AXI4LITE, FREQ_HZ 50000000, ID_WIDTH 0, ADDR_WIDTH 8, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 0, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN /clk_pl_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREA" & 
"DS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_awaddr: SIGNAL IS "xilinx.com:interface:aximm:1.0 CAN_S_AXI_LITE AWADDR";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_awready: SIGNAL IS "xilinx.com:interface:aximm:1.0 CAN_S_AXI_LITE AWREADY";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_awvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 CAN_S_AXI_LITE AWVALID";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_bready: SIGNAL IS "xilinx.com:interface:aximm:1.0 CAN_S_AXI_LITE BREADY";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_bresp: SIGNAL IS "xilinx.com:interface:aximm:1.0 CAN_S_AXI_LITE BRESP";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_bvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 CAN_S_AXI_LITE BVALID";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_rdata: SIGNAL IS "xilinx.com:interface:aximm:1.0 CAN_S_AXI_LITE RDATA";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_rready: SIGNAL IS "xilinx.com:interface:aximm:1.0 CAN_S_AXI_LITE RREADY";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_rresp: SIGNAL IS "xilinx.com:interface:aximm:1.0 CAN_S_AXI_LITE RRESP";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_rvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 CAN_S_AXI_LITE RVALID";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_wdata: SIGNAL IS "xilinx.com:interface:aximm:1.0 CAN_S_AXI_LITE WDATA";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_wready: SIGNAL IS "xilinx.com:interface:aximm:1.0 CAN_S_AXI_LITE WREADY";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_wstrb: SIGNAL IS "xilinx.com:interface:aximm:1.0 CAN_S_AXI_LITE WSTRB";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_wvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 CAN_S_AXI_LITE WVALID";
BEGIN
  U0 : can_v5_1_0
    GENERIC MAP (
      c_can_rx_dpth => 2,
      c_can_tx_dpth => 2,
      c_can_num_acf => 0,
      c_c2s_mtbf_stages => 2,
      c_s2c_mtbf_stages => 2,
      c_s_axi_addr_width => 8,
      c_s_axi_data_width => 32,
      c_family => "zynq",
      c_enable_ecc_tx_tl => 0,
      c_enable_ecc_tx_ol => 0,
      c_enable_ecc_rx => 0,
      c_has_ecc_err_inject_tx_tl => 0,
      c_has_ecc_err_inject_tx_ol => 0,
      c_has_ecc_err_inject_rx => 0
    )
    PORT MAP (
      can_clk => can_clk,
      can_phy_rx => can_phy_rx,
      can_phy_tx => can_phy_tx,
      ip2bus_intrevent => ip2bus_intrevent,
      s_axi_aclk => s_axi_aclk,
      s_axi_aresetn => s_axi_aresetn,
      s_axi_awaddr => s_axi_awaddr,
      s_axi_awvalid => s_axi_awvalid,
      s_axi_awready => s_axi_awready,
      s_axi_wdata => s_axi_wdata,
      s_axi_wstrb => s_axi_wstrb,
      s_axi_wvalid => s_axi_wvalid,
      s_axi_wready => s_axi_wready,
      s_axi_bresp => s_axi_bresp,
      s_axi_bvalid => s_axi_bvalid,
      s_axi_bready => s_axi_bready,
      s_axi_araddr => s_axi_araddr,
      s_axi_arvalid => s_axi_arvalid,
      s_axi_arready => s_axi_arready,
      s_axi_rdata => s_axi_rdata,
      s_axi_rresp => s_axi_rresp,
      s_axi_rvalid => s_axi_rvalid,
      s_axi_rready => s_axi_rready
    );
END can_test_axi_can_0_0_arch;
