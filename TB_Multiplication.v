`timescale 1ns / 1ps
module TB_Multiplication;

  // Inputs
  reg clk, reset, enable;
  reg [63:0] a_operand, b_operand;

  // Outputs
  wire Exception, Overflow, Underflow;
  wire [63:0] result;

  // Instantiate the DUT
  Multiplication uut (
    .clk(clk),
    .reset(reset),
    .enable(enable),
    .a_operand(a_operand),
    .b_operand(b_operand),
    .Exception(Exception),
    .Overflow(Overflow),
    .Underflow(Underflow),
    .result(result)
  );

  // Clock generation: 10ns period
  always #5 clk = ~clk;

  initial begin
    // Initialize
    clk = 0; reset = 1; enable = 0;
    #15 reset = 0; enable = 1;

    // Test 1: 2.5 × 3.25 = 8.125
    a_operand = 64'h4004000000000000; // 2.5
    b_operand = 64'h400A000000000000; // 3.25
    #20;

    // Test 2: 5.0 × -2.0 = -10.0
    a_operand = 64'h4014000000000000; // 5.0
    b_operand = 64'hC000000000000000; // -2.0
    #20;

    // Test 3: 0.5 × 0.25 = 0.125
    a_operand = 64'h3FE0000000000000; // 0.5
    b_operand = 64'h3FD0000000000000; // 0.25
    #20;

    // Test 4: 1.0 × 0.0 = 0.0
    a_operand = 64'h3FF0000000000000; // 1.0
    b_operand = 64'h0000000000000000; // 0.0
    #20;

    // Test 5: (-3.0) × (-4.0) = 12.0
    a_operand = 64'hC008000000000000; // -3.0
    b_operand = 64'hC010000000000000; // -4.0
    #20;

    // Test 6: Overflow
    a_operand = 64'h7FEFFFFFFFFFFFFF;
    b_operand = 64'h7FEFFFFFFFFFFFFF;
    #20;

    // Test 7: Underflow
    a_operand = 64'h0010000000000000;
    b_operand = 64'h0010000000000000;
    #20;

    $finish;
  end

endmodule
