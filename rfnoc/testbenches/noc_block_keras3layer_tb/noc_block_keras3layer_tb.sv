`timescale 1ns/1ps
`define NS_PER_TICK 1
`define NUM_TEST_CASES 5

`include "sim_exec_report.vh"
`include "sim_clks_rsts.vh"
`include "sim_rfnoc_lib.svh"

module noc_block_keras3layer_tb();
  `TEST_BENCH_INIT("noc_block_keras3layer",`NUM_TEST_CASES,`NS_PER_TICK);
  localparam BUS_CLK_PERIOD = $ceil(1e9/166.67e6);
  localparam CE_CLK_PERIOD  = $ceil(1e9/200e6);
  localparam NUM_CE         = 1;  // Number of Computation Engines / User RFNoC blocks to simulate
  localparam NUM_STREAMS    = 1;  // Number of test bench streams
  `RFNOC_SIM_INIT(NUM_CE, NUM_STREAMS, BUS_CLK_PERIOD, CE_CLK_PERIOD);
  `RFNOC_ADD_BLOCK(noc_block_keras3layer, 0);
  localparam NUM_IN = 16;
  localparam NUM_OUT = 5;

  localparam SPP = 10; // Samples per packet

  /********************************************************
  ** Verification
  ********************************************************/
  initial begin : tb_main
    string s;
    logic [31:0] random_word;
    logic [63:0] readback;
    integer data_file; // file handler
    integer scan_file; // file handler
    integer data_file_ref;

    /********************************************************
    ** Test 1 -- Reset
    ********************************************************/
    `TEST_CASE_START("Wait for Reset");
    while (bus_rst) @(posedge bus_clk);
    while (ce_rst) @(posedge ce_clk);
    `TEST_CASE_DONE(~bus_rst & ~ce_rst);

    /********************************************************
    ** Test 2 -- Check for correct NoC IDs
    ********************************************************/
    `TEST_CASE_START("Check NoC ID");
    // Read NOC IDs
    tb_streamer.read_reg(sid_noc_block_keras3layer, RB_NOC_ID, readback);
    $display("Read EX1LAYER NOC ID: %16x", readback);
    `ASSERT_ERROR(readback == noc_block_keras3layer.NOC_ID, "Incorrect NOC ID");
    `TEST_CASE_DONE(1);

    /********************************************************
    ** Test 3 -- Connect RFNoC blocks
    ********************************************************/
    `TEST_CASE_START("Connect RFNoC blocks");
    `RFNOC_CONNECT(noc_block_tb,noc_block_keras3layer,S16,SPP);
    `RFNOC_CONNECT(noc_block_keras3layer,noc_block_tb,S16,SPP);
    `TEST_CASE_DONE(1);

    /********************************************************
    ** Test 4 -- Write / readback user registers
    ********************************************************/
    `TEST_CASE_START("Write / readback user registers");
    tb_streamer.read_user_reg(sid_noc_block_keras3layer, noc_block_keras3layer.RB_SIZE_INPUT, readback);
    $sformat(s, "User register 0 incorrect readback! Expected: %0d, Actual %0d", readback[31:0], NUM_IN);
    `ASSERT_ERROR(readback[31:0] == NUM_IN, s);
    random_word = $random();
    tb_streamer.read_user_reg(sid_noc_block_keras3layer, noc_block_keras3layer.RB_SIZE_OUTPUT, readback);
    $sformat(s, "User register 1 incorrect readback! Expected: %0d, Actual %0d", readback[31:0], NUM_OUT);
    `ASSERT_ERROR(readback[31:0] == NUM_OUT, s);
    `TEST_CASE_DONE(1);

    /********************************************************
    ** Test 5 -- Test sequence
    ********************************************************/

    `TEST_CASE_START("Test Neural Net Data");
    // Run the test twice to make sure we can recreate results

    fork
      begin
        real data_float;
        integer data_int;
        logic [15:0] data_logic;
        // NOTE: Feed the core! It needs a stream of data in order
        // to keep clocking stuff through
        for (int ii = 0; ii < 10; ii++) begin
          data_file = $fopen("test_data_16x1.txt", "r");
          `ASSERT_FATAL(data_file != 0, "Data file could not be opened");
          if (data_file == 0) begin
            $display("data_file handle was NULL");
            $finish;
          end
          $display("Send data from text file");
          while (!$feof(data_file)) begin
            scan_file = $fscanf(data_file, "%f", data_float);
            data_int = data_float * (2**10); // multiply by 2^(num fractional bits)
            data_logic = data_int;
            if (!$feof(data_file))
              tb_streamer.push_word({data_logic}, 0 );
            else
              tb_streamer.push_word({data_logic}, 1 );
            $sformat(s, "Pushing word: %f, %d", data_float, data_int);
            //$display(s);
          end
          $fclose(data_file);
        end
      end
      begin
        logic last;
        logic [15:0] res_logic;
        shortint res_int;
        real result_float;
        real reference_float;
        data_file_ref = $fopen("output_data_5x1.txt", "r");
        `ASSERT_FATAL(data_file_ref != 0, "Output data file could not be opened");
        for (int ii = 0; ii < NUM_OUT; ii++) begin
          tb_streamer.pull_word({res_logic}, last);
          res_int = res_logic;
          result_float =  res_int / 2.0**10;  // divide by 2^(num fractional bits)
          $sformat(s, "Received Value: %f, %h", result_float, res_logic); $display(s);
          scan_file = $fscanf(data_file_ref, "%f\n", reference_float);
          $sformat(s, "Incorrect output value received! Expected: %0f, Received: %0f", reference_float, result_float);
          `ASSERT_ERROR((result_float-reference_float) < 0.1 && (reference_float-result_float) > -0.1, s);
        end
        $fclose(data_file_ref);
      end
    join
    `TEST_CASE_DONE(1);

    `TEST_BENCH_DONE;

  end
endmodule
