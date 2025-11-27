`timescale 1ns / 1ps

module Multiplication (
  input clk, reset, enable,
  input [63:0] a_operand, b_operand,
  output reg Exception, Overflow, Underflow,
  output reg [63:0] result
);

  // ----------------------------
  // Stage 0 (combinational decode)
  // ----------------------------
  wire sign = a_operand[63] ^ b_operand[63];
  wire [10:0] exp_a = a_operand[62:52];
  wire [10:0] exp_b = b_operand[62:52];
  wire [51:0] mant_a = a_operand[51:0];
  wire [51:0] mant_b = b_operand[51:0];

  wire [52:0] op_a = (|exp_a) ? {1'b1, mant_a} : {1'b0, mant_a};
  wire [52:0] op_b = (|exp_b) ? {1'b1, mant_b} : {1'b0, mant_b};

  wire exc = (&exp_a) | (&exp_b);

  // ----------------------------
  // Stage 1 pipeline registers
  // ----------------------------
  reg s1_sign;
  reg [10:0] s1_exp_a, s1_exp_b;
  reg [52:0] s1_op_a, s1_op_b;
  reg s1_exc;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      s1_sign <= 0;
      s1_exp_a <= 0;
      s1_exp_b <= 0;
      s1_op_a <= 0;
      s1_op_b <= 0;
      s1_exc <= 0;
    end
    else if (enable) begin
      s1_sign <= sign;
      s1_exp_a <= exp_a;
      s1_exp_b <= exp_b;
      s1_op_a <= op_a;
      s1_op_b <= op_b;
      s1_exc <= exc;
    end
  end

  // ----------------------------
  // Stage 2 (multiply + finish)
  // ----------------------------

wire [105:0] product;

BoothMultiplier booth_inst (
  .A(s1_op_a),
  .B(s1_op_b),
  .Product(product)
);

  wire normalised = product[105];
  wire [105:0] norm_product =
      normalised ? product : (product << 1);

  wire [51:0] mant_final =
      norm_product[104:53] + norm_product[52];

  wire [11:0] exp_sum =
      s1_exp_a + s1_exp_b + normalised;

  wire ovf = (exp_sum > 12'd3070);
  wire unf = (exp_sum < 12'd1023);

  wire [10:0] exp_result = exp_sum - 12'd1023;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      result <= 0;
      Exception <= 0;
      Overflow <= 0;
      Underflow <= 0;
    end
    else if (enable) begin
      Exception <= s1_exc;
      Overflow  <= ovf;
      Underflow <= unf;

      result <=
        s1_exc ? 64'd0 :
        ovf    ? {s1_sign, 11'h7FF, 52'd0} :
        unf    ? {s1_sign, 63'd0} :
                 {s1_sign, exp_result, mant_final};
    end
  end

endmodule



module BoothMultiplier (
  input  signed [52:0] A,   // 53-bit multiplicand (mantissa + hidden bit)
  input  signed [52:0] B,   // 53-bit multiplier
  output signed [105:0] Product // 106-bit product
);

  reg signed [106:0] acc;   // Accumulator (extra bit for Booth)
  integer i;

  always @(*) begin
    acc = {53'd0, B, 1'b0}; // {upper zeros, multiplier, extra bit}
    for (i = 0; i < 53; i = i + 1) begin
      case ({acc[1], acc[0]})
        2'b01: acc[106:54] = acc[106:54] + A;
        2'b10: acc[106:54] = acc[106:54] - A;
        default: ; // Do nothing
      endcase
      acc = acc >>> 1; // Arithmetic right shift
    end
  end

  assign Product = acc[106:1]; // Final product
endmodule

