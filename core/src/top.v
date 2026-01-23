module top #(
    parameter integer C_M_AXI_THREAD_ID_WIDTH = 1,
    parameter integer C_M_AXI_ADDR_WIDTH      = 32,
    parameter integer C_M_AXI_DATA_WIDTH      = 32,
    parameter integer C_M_AXI_AWUSER_WIDTH    = 1,
    parameter integer C_M_AXI_ARUSER_WIDTH    = 1,
    parameter integer C_M_AXI_WUSER_WIDTH     = 4,   // Avoid Warning
    parameter integer C_M_AXI_RUSER_WIDTH     = 4,   // Avoid Warning
    parameter integer C_M_AXI_BUSER_WIDTH     = 1,

    // Avoid compile errors
    parameter integer C_INTERCONNECT_M_AXI_WRITE_ISSUING = 0,
    parameter integer C_M_AXI_SUPPORTS_READ              = 1,
    parameter integer C_M_AXI_SUPPORTS_WRITE             = 1,
    parameter integer C_M_AXI_TARGET                     = 0,
    parameter integer C_M_AXI_BURST_LEN                  = 0,
    parameter integer C_OFFSET_WIDTH                     = 0
) (
    // System Signals
    input wire ACLK,
    input wire ARESETN,

    // Master Interface Write Address
    output wire [C_M_AXI_THREAD_ID_WIDTH-1:0] M_AXI_AWID,
    output wire [     C_M_AXI_ADDR_WIDTH-1:0] M_AXI_AWADDR,
    output wire [                      8-1:0] M_AXI_AWLEN,
    output wire [                      3-1:0] M_AXI_AWSIZE,
    output wire [                      2-1:0] M_AXI_AWBURST,
    output wire [                      2-1:0] M_AXI_AWLOCK,
    output wire [                      4-1:0] M_AXI_AWCACHE,
    output wire [                      3-1:0] M_AXI_AWPROT,
    // AXI3 output wire [4-1:0]                  M_AXI_AWREGION,
    output wire [                      4-1:0] M_AXI_AWQOS,
    output wire [   C_M_AXI_AWUSER_WIDTH-1:0] M_AXI_AWUSER,
    output wire                               M_AXI_AWVALID,
    input  wire                               M_AXI_AWREADY,

    // Master Interface Write Data
    // AXI3 output wire [C_M_AXI_THREAD_ID_WIDTH-1:0]     M_AXI_WID,
    output wire [  C_M_AXI_DATA_WIDTH-1:0] M_AXI_WDATA,
    output wire [C_M_AXI_DATA_WIDTH/8-1:0] M_AXI_WSTRB,
    output wire                            M_AXI_WLAST,
    output wire [ C_M_AXI_WUSER_WIDTH-1:0] M_AXI_WUSER,
    output wire                            M_AXI_WVALID,
    input  wire                            M_AXI_WREADY,

    // Master Interface Write Response
    input  wire [C_M_AXI_THREAD_ID_WIDTH-1:0] M_AXI_BID,
    input  wire [                      2-1:0] M_AXI_BRESP,
    input  wire [    C_M_AXI_BUSER_WIDTH-1:0] M_AXI_BUSER,
    input  wire                               M_AXI_BVALID,
    output wire                               M_AXI_BREADY,

    // Master Interface Read Address
    output wire [C_M_AXI_THREAD_ID_WIDTH-1:0] M_AXI_ARID,
    output wire [     C_M_AXI_ADDR_WIDTH-1:0] M_AXI_ARADDR,
    output wire [                      8-1:0] M_AXI_ARLEN,
    output wire [                      3-1:0] M_AXI_ARSIZE,
    output wire [                      2-1:0] M_AXI_ARBURST,
    output wire [                      2-1:0] M_AXI_ARLOCK,
    output wire [                      4-1:0] M_AXI_ARCACHE,
    output wire [                      3-1:0] M_AXI_ARPROT,
    // AXI3 output wire [4-1:0]                  M_AXI_ARREGION,
    output wire [                      4-1:0] M_AXI_ARQOS,
    output wire [   C_M_AXI_ARUSER_WIDTH-1:0] M_AXI_ARUSER,
    output wire                               M_AXI_ARVALID,
    input  wire                               M_AXI_ARREADY,

    // Master Interface Read Data
    input  wire [C_M_AXI_THREAD_ID_WIDTH-1:0] M_AXI_RID,
    input  wire [     C_M_AXI_DATA_WIDTH-1:0] M_AXI_RDATA,
    input  wire [                      2-1:0] M_AXI_RRESP,
    input  wire                               M_AXI_RLAST,
    input  wire [    C_M_AXI_RUSER_WIDTH-1:0] M_AXI_RUSER,
    input  wire                               M_AXI_RVALID,
    output wire                               M_AXI_RREADY,

    // UART
    input  wire UART_RX,  // J5 pin5
    output wire UART_TX,  // J5 pin7

    // Register bus
    input  wire [16-1:0] WRADDR,
    input  wire [ 4-1:0] BYTEEN,
    input  wire          WREN,
    input  wire [32-1:0] WDATA,
    input  wire [16-1:0] RDADDR,
    input  wire          RDEN,
    output wire [32-1:0] RDATA,

    output wire [31:0] DEBUG  // for debugging
);

  //-------------------------------------------------------------------------
  // Reset synchronizer (ARESETN is async, internal ARST is sync / active-high)
  //-------------------------------------------------------------------------
  reg [1:0] arst_ff;
  always @(posedge ACLK) begin
    arst_ff <= {arst_ff[0], ~ARESETN};
  end
  wire ARST;
  assign ARST = arst_ff[1];

  //-------------------------------------------------------------------------
  // BOOTCTRL (regbus)
  //-------------------------------------------------------------------------
  wire [31:0] boot_rdata;
  wire        boot_run;
  wire        boot_hold_reset;
  wire [31:0] boot_dram_base;
  wire [31:0] boot_entry_pc;

  bootctrl_regbus #(
      .BOOT_BASE(16'h1000)
  ) u_bootctrl (
      .clk       (ACLK),
      .rst       (ARST),
      .WRADDR    (WRADDR),
      .BYTEEN    (BYTEEN),
      .WREN      (WREN),
      .WDATA     (WDATA),
      .RDADDR    (RDADDR),
      .RDEN      (RDEN),
      .RDATA     (boot_rdata),
      .run       (boot_run),
      .hold_reset(boot_hold_reset),
      .dram_base (boot_dram_base),
      .entry_pc  (boot_entry_pc)
  );

  // For now, top only exposes BOOTCTRL RDATA.
  // Later: OR / mux with draw/display regctrl RDATA.
  assign RDATA = boot_rdata;

  //-------------------------------------------------------------------------
  // CPU core (wrapped with plain membus wires)
  //-------------------------------------------------------------------------
  wire CORE_RST;
  assign CORE_RST = ARST | boot_hold_reset | ~boot_run;

  wire        mem_valid;
  wire        mem_ready;
  wire [31:0] mem_addr;
  wire        mem_wen;
  wire [31:0] mem_wdata;
  wire [ 3:0] mem_wmask;
  wire        mem_rvalid;
  wire [31:0] mem_rdata;

  // NOTE: `core_port` is provided as Veryl wrapper (core_port.veryl).
  // It exposes the membus signals as plain ports (no SV interface on top-level).
  core_port u_core (
      .clk       (ACLK),
      .rst       (CORE_RST),
      .mem_valid (mem_valid),
      .mem_ready (mem_ready),
      .mem_addr  (mem_addr),
      .mem_wen   (mem_wen),
      .mem_wdata (mem_wdata),
      .mem_wmask (mem_wmask),
      .mem_rvalid(mem_rvalid),
      .mem_rdata (mem_rdata)
  );

  //-------------------------------------------------------------------------
  // membus -> AXI adapter
  //-------------------------------------------------------------------------
  wire [31:0] last_pc;

  membus_axi_master #(
      .AXI_ID_W  (C_M_AXI_THREAD_ID_WIDTH),
      .AXI_ADDR_W(C_M_AXI_ADDR_WIDTH),
      .AXI_DATA_W(C_M_AXI_DATA_WIDTH)
  ) u_membus_axi_master (
      .clk      (ACLK),
      .rst      (CORE_RST),
      .run      (boot_run),
      .dram_base(boot_dram_base),
      .entry_pc (boot_entry_pc),

      .mem_valid (mem_valid),
      .mem_ready (mem_ready),
      .mem_addr  (mem_addr),
      .mem_wen   (mem_wen),
      .mem_wdata (mem_wdata),
      .mem_wmask (mem_wmask),
      .mem_rvalid(mem_rvalid),
      .mem_rdata (mem_rdata),

      .M_AXI_AWID   (M_AXI_AWID),
      .M_AXI_AWADDR (M_AXI_AWADDR),
      .M_AXI_AWLEN  (M_AXI_AWLEN),
      .M_AXI_AWSIZE (M_AXI_AWSIZE),
      .M_AXI_AWBURST(M_AXI_AWBURST),
      .M_AXI_AWLOCK (M_AXI_AWLOCK),
      .M_AXI_AWCACHE(M_AXI_AWCACHE),
      .M_AXI_AWPROT (M_AXI_AWPROT),
      .M_AXI_AWQOS  (M_AXI_AWQOS),
      .M_AXI_AWVALID(M_AXI_AWVALID),
      .M_AXI_AWREADY(M_AXI_AWREADY),

      .M_AXI_WDATA (M_AXI_WDATA),
      .M_AXI_WSTRB (M_AXI_WSTRB),
      .M_AXI_WLAST (M_AXI_WLAST),
      .M_AXI_WVALID(M_AXI_WVALID),
      .M_AXI_WREADY(M_AXI_WREADY),

      .M_AXI_BID   (M_AXI_BID),
      .M_AXI_BRESP (M_AXI_BRESP),
      .M_AXI_BVALID(M_AXI_BVALID),
      .M_AXI_BREADY(M_AXI_BREADY),

      .M_AXI_ARID   (M_AXI_ARID),
      .M_AXI_ARADDR (M_AXI_ARADDR),
      .M_AXI_ARLEN  (M_AXI_ARLEN),
      .M_AXI_ARSIZE (M_AXI_ARSIZE),
      .M_AXI_ARBURST(M_AXI_ARBURST),
      .M_AXI_ARLOCK (M_AXI_ARLOCK),
      .M_AXI_ARCACHE(M_AXI_ARCACHE),
      .M_AXI_ARPROT (M_AXI_ARPROT),
      .M_AXI_ARQOS  (M_AXI_ARQOS),
      .M_AXI_ARVALID(M_AXI_ARVALID),
      .M_AXI_ARREADY(M_AXI_ARREADY),

      .M_AXI_RID   (M_AXI_RID),
      .M_AXI_RDATA (M_AXI_RDATA),
      .M_AXI_RRESP (M_AXI_RRESP),
      .M_AXI_RLAST (M_AXI_RLAST),
      .M_AXI_RVALID(M_AXI_RVALID),
      .M_AXI_RREADY(M_AXI_RREADY),

      .last_pc(last_pc)
  );

  assign DEBUG = last_pc;

  //-------------------------------------------------------------------------
  // AXI user fields are unused for now (tie to 0)
  //-------------------------------------------------------------------------
  assign M_AXI_AWUSER = {C_M_AXI_AWUSER_WIDTH{1'b0}};
  assign M_AXI_WUSER = {C_M_AXI_WUSER_WIDTH{1'b0}};
  assign M_AXI_ARUSER = {C_M_AXI_ARUSER_WIDTH{1'b0}};

  // UART idle
  assign UART_TX = 1'b1;

  // Unused read side fields
  assign M_AXI_ARUSER = {C_M_AXI_ARUSER_WIDTH{1'b0}};

endmodule
