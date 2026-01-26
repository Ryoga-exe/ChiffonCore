// tb_riscv_tests.sv
`timescale 1ns / 1ps

// VIP instance path
`define VIPINST dut.design_1_i.axi_vip_0.inst

import axi_vip_pkg::*;
import design_1_axi_vip_0_0_pkg::*;

module tb_riscv_tests;

  localparam integer STEP = 8;

  // default hex (override with +HEX=xxx.hex)
  localparam string MEMDATA_DEFAULT = "rv64ui-p-add.hex";

  // memory base used by VIP backdoor
  localparam logic [31:0] MEMBASE_DEFAULT = 32'h2000_0000;

  // CPU-side RAM base (CPU address space)
  localparam logic [31:0] CPU_RAM_BASE_DEFAULT = 32'h8000_0000;

  // CPU-side tohost address (riscv-tests)
  localparam logic [31:0] TOHOST_CPU_ADDR_DEFAULT = (CPU_RAM_BASE_DEFAULT + 32'h0000_1000);

  // timeout cycles (override with +TIMEOUT=...)
  localparam integer TIMEOUT_DEFAULT = 5_000_000;

  // DUT ports
  logic        ACLK;
  logic        ARESETN;

  logic        UART_RX;
  wire         UART_TX;

  // regbus
  reg   [15:0] WRADDR;
  reg   [ 3:0] BYTEEN;
  reg          WREN;
  reg   [31:0] WDATA;
  reg   [15:0] RDADDR;
  reg          RDEN;
  wire  [31:0] RDATA;

  wire  [31:0] DEBUG;

  // BD wrapper
  design_1_wrapper dut (.*);

  // ----------------------------------------------------------------
  // Clock
  // ----------------------------------------------------------------
  always begin
    ACLK = 0;
    #(STEP / 2);
    ACLK = 1;
    #(STEP / 2);
  end

  // ----------------------------------------------------------------
  // BOOTCTRL reg map (same as tb_basic)
  // ----------------------------------------------------------------
  localparam logic [15:0] BOOT_BASE = 16'h1000;
  localparam logic [15:0] BOOT_STATUS = BOOT_BASE + 16'h0000;
  localparam logic [15:0] BOOT_CTRL = BOOT_BASE + 16'h0004;
  localparam logic [15:0] BOOT_DRAMBASE = BOOT_BASE + 16'h0008;
  localparam logic [15:0] BOOT_ENTRYPC = BOOT_BASE + 16'h000C;

  // ----------------------------------------------------------------
  // runtime settings (plusargs)
  // ----------------------------------------------------------------
  string                                MEMDATA;
  integer                               TIMEOUT;
  logic                          [31:0] MEMBASE;
  logic                          [31:0] ENTRYPC;
  logic                          [31:0] CPU_RAM_BASE;
  logic                          [31:0] TOHOST_CPU_ADDR;
  logic                          [31:0] PHYS_TOHOST;

  // VIP Slave agent (slv_mem)
  design_1_axi_vip_0_0_slv_mem_t        agent;

  // ----------------------------------------------------------------
  // regbus helpers
  // ----------------------------------------------------------------
  task automatic write_reg(input logic [15:0] addr, input logic [3:0] byteen,
                           input logic [31:0] wdata);
    begin
      WRADDR = addr;
      BYTEEN = byteen;
      WDATA  = wdata;
      @(negedge ACLK);
      WREN = 1;
      @(negedge ACLK);
      WREN = 0;
    end
  endtask

  task automatic read_reg(input logic [15:0] addr, output logic [31:0] rdata);
    begin
      RDADDR = addr;
      @(negedge ACLK);
      RDEN = 1;
      @(negedge ACLK);
      rdata = RDATA;
      RDEN  = 0;
    end
  endtask

  // ----------------------------------------------------------------
  // VIP ready behavior (no backpressure)
  // ----------------------------------------------------------------
  task automatic user_gen_ready();
    axi_ready_gen arready_gen;
    axi_ready_gen awready_gen;
    axi_ready_gen wready_gen;
    begin
      arready_gen = agent.rd_driver.create_ready("arready");
      arready_gen.set_ready_policy(XIL_AXI_READY_GEN_NO_BACKPRESSURE);
      agent.rd_driver.send_arready(arready_gen);

      awready_gen = agent.wr_driver.create_ready("awready");
      awready_gen.set_ready_policy(XIL_AXI_READY_GEN_NO_BACKPRESSURE);
      agent.wr_driver.send_awready(awready_gen);

      wready_gen = agent.wr_driver.create_ready("wready");
      wready_gen.set_ready_policy(XIL_AXI_READY_GEN_NO_BACKPRESSURE);
      agent.wr_driver.send_wready(wready_gen);
    end
  endtask

  // ----------------------------------------------------------------
  // Memory helpers
  // ----------------------------------------------------------------
  task automatic memwrite32(input logic [31:0] addr, input logic [31:0] data);
    begin
      agent.mem_model.backdoor_memory_write_4byte(addr, data, 4'hf);
    end
  endtask

  task automatic memread32(input logic [31:0] addr, output logic [31:0] data);
    begin
      data = agent.mem_model.backdoor_memory_read_4byte(addr);
    end
  endtask

  // Simple Hex loader: read 32-bit word per line (tb_basic と同じ)
  task automatic load_hex_file(input string filename, input logic [31:0] base_addr);
    integer        fd;
    integer        rc;
    int            idx;
    int            n;
    reg     [31:0] word;
    string         line;
    begin
      fd = $fopen(filename, "r");
      if (fd == 0) begin
        $display("[TB] ERROR: cannot open hex file: %s", filename);
        $finish;
      end

      idx = 0;
      while (!$feof(
          fd
      )) begin
        line = "";
        rc = $fgets(line, fd);  // rc is number of chars read (unused)
        n = $sscanf(line, "%h", word);
        if (n == 1) begin
          memwrite32(base_addr + idx * 4, word);
          idx++;
        end
      end
      $fclose(fd);
      $display("[TB] Loaded %0d words to 0x%08h from %s", idx, base_addr, filename);
    end
  endtask

  // ----------------------------------------------------------------
  // System init
  // ----------------------------------------------------------------
  task automatic init_system();
    begin
      agent = new("AXI Slave Agent", `VIPINST.IF);
      agent.start_slave();
      user_gen_ready();
    end
  endtask

  // ----------------------------------------------------------------
  // tohost check (poll)
  // ----------------------------------------------------------------
  task automatic check_tohost();
    logic [31:0] v;
    begin
      memread32(PHYS_TOHOST, v);
      if (v[0]) begin
        if (v == 32'h1) begin
          $display("[TB] riscv-tests success! tohost=0x%08h (phys=0x%08h)", v, PHYS_TOHOST);
        end else begin
          $display("[TB] riscv-tests failed!  tohost=0x%08h (phys=0x%08h)", v, PHYS_TOHOST);
          $error("wdata : %h", v);
        end
        $finish;
      end
    end
  endtask

  // ----------------------------------------------------------------
  // Test
  // ----------------------------------------------------------------
  reg [31:0] status;

  initial begin
    // defaults
    ARESETN         = 1'b1;
    UART_RX         = 1'b1;
    WRADDR          = 0;
    BYTEEN          = 0;
    WREN            = 0;
    WDATA           = 0;
    RDADDR          = 0;
    RDEN            = 0;

    // plusargs (optional)
    MEMDATA         = MEMDATA_DEFAULT;
    TIMEOUT         = TIMEOUT_DEFAULT;
    MEMBASE         = MEMBASE_DEFAULT;
    ENTRYPC         = 32'h0000_0000;
    TOHOST_CPU_ADDR = TOHOST_CPU_ADDR_DEFAULT;

    CPU_RAM_BASE    = CPU_RAM_BASE_DEFAULT;
    void'($value$plusargs("HEX=%s", MEMDATA));
    void'($value$plusargs("TIMEOUT=%d", TIMEOUT));
    void'($value$plusargs("MEMBASE=%h", MEMBASE));
    void'($value$plusargs("ENTRY=%h", ENTRYPC));
    void'($value$plusargs("RAMBASE=%h", CPU_RAM_BASE));
    void'($value$plusargs("TOHOST=%h", TOHOST_CPU_ADDR));

    if (TOHOST_CPU_ADDR >= CPU_RAM_BASE) begin
      PHYS_TOHOST = MEMBASE + ENTRYPC + (TOHOST_CPU_ADDR - CPU_RAM_BASE);
    end else begin
      // Backward-compat: low-linked tests (e.g., TOHOST=0x1000)
      PHYS_TOHOST = MEMBASE + ENTRYPC + TOHOST_CPU_ADDR;
    end

    // reset pulse
    #(STEP);
    ARESETN = 1'b0;
    #(STEP * 50);
    ARESETN = 1'b1;
    #(STEP * 50);

    init_system();

    // Write hex to memory
    load_hex_file(MEMDATA, MEMBASE);

    // ------------------------------------------------------------
    // Set BOOTCTRL (dram_base / entry_pc / START)
    // ------------------------------------------------------------
    write_reg(BOOT_DRAMBASE, 4'hf, MEMBASE);
    write_reg(BOOT_ENTRYPC, 4'hf, ENTRYPC);

    // CTRL: bit0=HOLD_RESET(level), bit1=START(W1P)
    // WDATA=0x2: hold_reset=0 & run=1
    write_reg(BOOT_CTRL, 4'h1, 32'h0000_0002);

    // read status
    read_reg(BOOT_STATUS, status);
    $display(
        "[TB] BOOT_STATUS=0x%08h  MEMBASE=0x%08h ENTRY=0x%08h TOHOST=0x%08h PHYS_TOHOST=0x%08h HEX=%s TIMEOUT=%0d",
        status, MEMBASE, ENTRYPC, TOHOST_CPU_ADDR, PHYS_TOHOST, MEMDATA, TIMEOUT);

    // main loop: poll tohost + show DEBUG occasionally
    $display("[TB] Running... (poll tohost)");
    begin : run
      int cyc;
      reg [31:0] prev;
      prev = 32'hffff_ffff;

      for (cyc = 0; cyc < TIMEOUT; cyc++) begin
        @(posedge ACLK);

        // poll tohost often enough
        if ((cyc % 2000) == 0) begin
          check_tohost();
        end

        // DEBUG log (like tb_basic)
        if ((cyc % 50000) == 0) begin
          if (DEBUG != prev) begin
            $display("[TB] t=%0t cyc=%0d last_pc=0x%08h", $time, cyc, DEBUG);
            prev = DEBUG;
          end
        end
      end
    end

    $display("[TB] TIMEOUT");
    // one last try
    check_tohost();
    $finish;
  end

endmodule
