`timescale 1ns / 1ps

module TB_Add_Sub;

  reg clk;
  reg enable;
  reg [63:0] a_operand, b_operand;
  reg Add_or_Sub; // 0 = Add, 1 = Sub
  wire Exception;
  wire [63:0] Result;

  // Clock generator: 10 ns period
  always #5 clk = ~clk;

  // Instantiate the module
  Addition_Subtraction uut (
    .clk(clk),
    .enable(enable),
    .a_operand(a_operand),
    .b_operand(b_operand),
    .Add_or_Sub(Add_or_Sub),
    .Exception(Exception),
    .Result(Result)
  );

  initial begin
    clk = 0;
    enable = 1;

    // Monitor results
    $monitor("Time=%0t | Add_or_Sub=%b | A=%h | B=%h | Result=%h | Exception=%b", 
              $time, Add_or_Sub, a_operand, b_operand, Result, Exception);

    // -------------------------
    // Test 1: 5.25 + 2.75 = 8.0
    // -------------------------
    Add_or_Sub = 0;
    a_operand = 64'h4015000000000000;
    b_operand = 64'h4006000000000000;
    #20;  // allow two clock cycles

    // -------------------------
    // Test 2: 6.75 - 1.5 = 5.25
    // -------------------------
    Add_or_Sub = 1;
    a_operand = 64'h401B000000000000;
    b_operand = 64'h3FF8000000000000;
    #20;

    // -------------------------
    // Test 3: 0.625 + 1.125 = 1.75
    // -------------------------
    Add_or_Sub = 0;
    a_operand = 64'h3FE4000000000000;
    b_operand = 64'h3FF2000000000000;
    #20;

    // -------------------------
    // Test 4: Infinity + 1.0 (Exception case)
    // -------------------------
    Add_or_Sub = 0;
    a_operand = 64'h7FF0000000000000; // +Inf
    b_operand = 64'h3FF0000000000000; // 1.0
    #20;

    $finish;
  end

endmodule
