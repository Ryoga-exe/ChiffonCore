// tb_riscv_tests.sv
`timescale 1ns / 1ps

`define VIPINST dut.design_1_i.axi_vip_0.inst

import axi_vip_pkg::*;
import design_1_axi_vip_0_0_pkg::*;

module tb_riscv_tests;

  localparam integer STEP = 8;

  logic        ACLK;
  logic        ARESETN;

  logic        UART_RX;
  wire         UART_TX;

  reg   [15:0] WRADDR;
  reg   [ 3:0] BYTEEN;
  reg          WREN;
  reg   [31:0] WDATA;
  reg   [15:0] RDADDR;
  reg          RDEN;
  wire  [31:0] RDATA;

  wire  [31:0] DEBUG;

  design_1_wrapper dut (.*);

  always begin
    ACLK = 0;
    #(STEP / 2);
    ACLK = 1;
    #(STEP / 2);
  end

  // BOOTCTRL reg map
  localparam [15:0] BOOT_BASE = 16'h1000;
  localparam [15:0] BOOT_STATUS = BOOT_BASE + 16'h0000;
  localparam [15:0] BOOT_CTRL = BOOT_BASE + 16'h0004;
  localparam [15:0] BOOT_DRAMBASE = BOOT_BASE + 16'h0008;
  localparam [15:0] BOOT_ENTRYPC = BOOT_BASE + 16'h000C;

  // Defaults (override with +args)
  reg                            [31:0] MEMBASE;
  reg                            [31:0] ENTRYPC;
  reg                            [31:0] TOHOST_OFFS;
  integer                               TIMEOUT;
  string                                HEXFILE;

  design_1_axi_vip_0_0_slv_mem_t        agent;

  task automatic write_reg(input logic [15:0] addr, input logic [3:0] byteen,
                           input logic [31:0] wdata);
    begin
      WRADDR = addr;
      BYTEEN = byteen;
      WDATA  = wdata;
      @(negedge ACLK);
      WREN = 1;
      @(negedge ACLK);
      WREN   = 0;
      WRADDR = 0;
      BYTEEN = 0;
      WDATA  = 0;
      @(negedge ACLK);
    end
  endtask

  task automatic read_reg(input logic [15:0] addr, output logic [31:0] rdata);
    begin
      RDADDR = addr;
      @(negedge ACLK);
      RDEN = 1;
      @(negedge ACLK);
      rdata  = RDATA;
      RDEN   = 0;
      RDADDR = 0;
      @(negedge ACLK);
    end
  endtask

  task automatic set_no_backpressure();
    axi_ready_gen ar_gen, aw_gen, w_gen;
    begin
      ar_gen = agent.rd_driver.create_ready("arready");
      ar_gen.set_ready_policy(XIL_AXI_READY_GEN_NO_BACKPRESSURE);
      agent.rd_driver.send_arready(ar_gen);

      aw_gen = agent.wr_driver.create_ready("awready");
      aw_gen.set_ready_policy(XIL_AXI_READY_GEN_NO_BACKPRESSURE);
      agent.wr_driver.send_awready(aw_gen);

      w_gen = agent.wr_driver.create_ready("wready");
      w_gen.set_ready_policy(XIL_AXI_READY_GEN_NO_BACKPRESSURE);
      agent.wr_driver.send_wready(w_gen);
    end
  endtask

  task automatic memwrite32(input logic [31:0] addr, input logic [31:0] data);
    begin
      agent.mem_model.backdoor_memory_write_4byte(addr, data, 4'hf);
    end
  endtask

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
        rc = $fgets(line, fd);
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

  // tohost watch by sniffing AXI writes
  reg        saw_aw;
  reg [31:0] last_awaddr;
  reg [31:0] last_wdata;
  reg [ 3:0] last_wstrb;

  function automatic bit is_tohost_addr(input logic [31:0] axi_addr);
    begin
      is_tohost_addr = (axi_addr == (MEMBASE + TOHOST_OFFS));
    end
  endfunction

  always_ff @(posedge ACLK) begin
    if (!ARESETN) begin
      saw_aw      <= 1'b0;
      last_awaddr <= 32'h0;
      last_wdata  <= 32'h0;
      last_wstrb  <= 4'h0;
    end else begin
      if (`VIPINST.IF.awvalid && `VIPINST.IF.awready) begin
        saw_aw      <= 1'b1;
        last_awaddr <= `VIPINST.IF.awaddr;
      end

      if (`VIPINST.IF.wvalid && `VIPINST.IF.wready) begin
        last_wdata <= `VIPINST.IF.wdata[31:0];
        last_wstrb <= `VIPINST.IF.wstrb[3:0];

        if (saw_aw && is_tohost_addr(last_awaddr) && (last_wstrb == 4'hf)) begin
          if (last_wdata[0]) begin
            if (last_wdata == 32'h1) begin
              $display("[TB] riscv-tests SUCCESS! tohost=0x%08h", last_wdata);
              $finish;
            end else begin
              $display("[TB] riscv-tests FAIL! tohost=0x%08h", last_wdata);
              $finish;
            end
          end
        end
      end

      if (`VIPINST.IF.bvalid && `VIPINST.IF.bready) begin
        saw_aw <= 1'b0;
      end
    end
  end

  reg [31:0] status;

  initial begin
    MEMBASE     = 32'h2000_0000;
    ENTRYPC     = 32'h0000_0000;
    TOHOST_OFFS = 32'h0000_1000;
    TIMEOUT     = 2000000;
    HEXFILE     = "rv32_test.hex";

    void'($value$plusargs("MEMBASE=%h", MEMBASE));
    void'($value$plusargs("ENTRY=%h", ENTRYPC));
    void'($value$plusargs("TOHOST=%h", TOHOST_OFFS));
    void'($value$plusargs("TIMEOUT=%d", TIMEOUT));
    begin
      string tmp;
      if ($value$plusargs("HEX=%s", tmp)) HEXFILE = tmp;
    end

    ARESETN = 1'b1;
    UART_RX = 1'b1;
    WRADDR = 0;
    BYTEEN = 0;
    WREN = 0;
    WDATA = 0;
    RDADDR = 0;
    RDEN = 0;

    #(STEP);
    ARESETN = 1'b0;
    #(STEP * 50);
    ARESETN = 1'b1;
    #(STEP * 20);

    agent = new("AXI Slave Agent", `VIPINST.IF);
    agent.start_slave();
    set_no_backpressure();

    load_hex_file(HEXFILE, MEMBASE);

    write_reg(BOOT_DRAMBASE, 4'hf, MEMBASE);
    write_reg(BOOT_ENTRYPC, 4'hf, ENTRYPC);
    write_reg(BOOT_CTRL, 4'h1, 32'h0000_0002);

    read_reg(BOOT_STATUS, status);
    $display("[TB] BOOT_STATUS=0x%08h MEMBASE=0x%08h ENTRY=0x%08h TOHOST=0x%08h HEX=%s", status,
             MEMBASE, ENTRYPC, TOHOST_OFFS, HEXFILE);

    begin : watchdog
      integer cyc;
      reg [31:0] last_dbg;
      last_dbg = 32'hffff_ffff;
      for (cyc = 0; cyc < TIMEOUT; cyc++) begin
        @(posedge ACLK);
        if ((cyc % 20000) == 0) begin
          if (DEBUG != last_dbg) begin
            $display("[TB] t=%0t cyc=%0d DEBUG=0x%08h", $time, cyc, DEBUG);
            last_dbg = DEBUG;
          end
        end
      end
      $display("[TB] TIMEOUT after %0d cycles. Last DEBUG=0x%08h", TIMEOUT, DEBUG);
      $finish;
    end
  end

endmodule
