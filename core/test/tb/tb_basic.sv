// tb_basic.sv
`timescale 1ns / 1ps

// VIP instance path (design_1 / axi_vip_0 は sim_ifetch.tcl の生成に合わせる)
`define VIPINST dut.design_1_i.axi_vip_0.inst

import axi_vip_pkg::*;
import design_1_axi_vip_0_0_pkg::*;

module tb_basic;

  localparam integer STEP = 8;

  localparam string MEMMDATA = "sample.hex";

  // DUT ports (design_1_wrapper のポートに合わせる)
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
  // BOOTCTRL register map (bootctrl_regbus.veryl の BOOT_BASE=0x1000 に合わせる)
  // ----------------------------------------------------------------
  localparam logic [15:0] BOOT_BASE = 16'h1000;
  localparam logic [15:0] BOOT_STATUS = BOOT_BASE + 16'h0000;
  localparam logic [15:0] BOOT_CTRL = BOOT_BASE + 16'h0004;
  localparam logic [15:0] BOOT_DRAMBASE = BOOT_BASE + 16'h0008;
  localparam logic [15:0] BOOT_ENTRYPC = BOOT_BASE + 16'h000C;

  // Instruction memory base used by VIP backdoor (任意。draw と合わせて 0x2000_0000 にしておく)
  localparam logic [31:0] MEMBASE = 32'h2000_0000;

  // VIP Slave agent (slv_mem)
  design_1_axi_vip_0_0_slv_mem_t agent;

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
  // VIP ready behavior (ARREADY のみ設定すれば ifetch は進む)
  // ----------------------------------------------------------------
  task automatic user_gen_arready();
    axi_ready_gen arready_gen;
    begin
      arready_gen = agent.wr_driver.create_ready("arready");
      arready_gen.set_ready_policy(XIL_AXI_READY_GEN_RANDOM);
      agent.rd_driver.send_arready(arready_gen);
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

  // Simple Hex loader: read 32-bit word per line
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
      user_gen_arready();
    end
  endtask

  // ----------------------------------------------------------------
  // Test
  // ----------------------------------------------------------------
  reg [31:0] status;

  initial begin
    // defaults
    ARESETN = 1'b1;
    UART_RX = 1'b1;
    WRADDR  = 0;
    BYTEEN  = 0;
    WREN    = 0;
    WDATA   = 0;
    RDADDR  = 0;
    RDEN    = 0;

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
    // 2) Set BOOTCTRL (dram_base / entry_pc / START)
    // ------------------------------------------------------------
    write_reg(BOOT_DRAMBASE, 4'hf, MEMBASE);
    write_reg(BOOT_ENTRYPC, 4'hf, 32'h0000_0000);

    // CTRL: bit0=HOLD_RESET(level), bit1=START(W1P)
    // WDATA=0x2: hold_reset=0 & run=1
    write_reg(BOOT_CTRL, 4'h1, 32'h0000_0002);

    // read status
    read_reg(BOOT_STATUS, status);
    $display("[TB] BOOT_STATUS = 0x%08h (bit0=run, bit1=hold_reset)", status);

    // main
    $display("[TB] Watching DEBUG(last_pc) ...");
    begin : watch
      int seen;
      reg [31:0] prev;
      seen = 0;
      prev = 32'hffff_ffff;
      while (seen < 10) begin
        @(posedge ACLK);
        if (DEBUG != prev) begin
          $display("[TB] t=%0t  last_pc=0x%08h", $time, DEBUG);
          prev = DEBUG;
          seen++;
        end
      end
    end

    $display("[TB] DONE");
    $stop;
  end

endmodule
