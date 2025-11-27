
`include "Priority_Encoder.v"

module Addition_Subtraction (
  input  wire clk,
  input  wire enable,
  input  [63:0] a_operand, b_operand,
  input   Add_or_Sub,   // 0 for adddition 1 for subtraction
  output  reg Exception,
  output reg [63:0] Result
);

  // Extract sign (1 bit), exponent (11 bits), mantissa (52 bits1)
  wire sign_a = a_operand[63];
  wire sign_b = b_operand[63];
  wire [10:0] exp_a = a_operand[62:52];
  wire [10:0] exp_b = b_operand[62:52];
  wire [51:0] mant_a = a_operand[51:0];
  wire [51:0] mant_b = b_operand[51:0];

  // Hidden bit addition (1 for normalized, 0 for denorm or zero)
  wire [52:0] sig_a = (|exp_a) ? {1'b1, mant_a} : {1'b0, mant_a}; // non-0 exponent=normalised number
  wire [52:0] sig_b = (|exp_b) ? {1'b1, mant_b} : {1'b0, mant_b}; // adds 1 before decimal if normalised number otherwise adds 0

  // Exception check (NaN or Infinity have 0s in exponent)
wire Exception_wire = (&exp_a) | (&exp_b);

  // Compare exponents
  wire [11:0] exp_diff = (exp_a >= exp_b) ? (exp_a - exp_b) : (exp_b - exp_a);
  wire [10:0] exp_large = (exp_a >= exp_b) ? exp_a : exp_b;
  
  // Align smaller operand
  wire [52:0] sig_a_shifted = (exp_a >= exp_b) ? sig_a : (sig_a >> exp_diff);
  wire [52:0] sig_b_shifted = (exp_b > exp_a) ? sig_b : (sig_b >> exp_diff);


// Prepare B operand depending on add/sub
wire [53:0] B_input  = (Add_or_Sub) ? ~sig_b_shifted : sig_b_shifted;
wire        Cin_input = (Add_or_Sub) ? 1'b1 : 1'b0;

wire [53:0] sig_sum;
wire        sig_cout;
  
  // Perform addition or subtraction using CLA module
CLA_Adder cla_inst (
  .A(sig_a_shifted),
  .B(B_input),
  .Cin(Cin_input),
  .Sum(sig_sum),
  .Cout(sig_cout)
);


  // Normalization and sign handling
wire carry = sig_cout;
wire [53:0] sig_final = (carry ? (sig_sum >> 1) : sig_sum);
wire [10:0] exp_final = (carry ? (exp_large + 1) : exp_large);
  wire sign_final = (Add_or_Sub) ? ((sig_a_shifted >= sig_b_shifted) ? sign_a : sign_b) : sign_a;
  
reg [53:0] sig_stage1;
reg [10:0] exp_stage1;
reg        sign_stage1;
reg        exception_stage1;
  
always @(posedge clk) begin
  if (enable) begin
    sig_stage1  <= sig_final;
    exp_stage1  <= exp_final;
    sign_stage1 <= sign_final;
    exception_stage1 <= Exception_wire;
  end
end
  
  // Normalization after subtraction (priority encoder)
  wire [52:0] norm_mant;
  wire [10:0] norm_exp;

  Priority_Encoder norm(
    .clk(clk),
    .enable(enable),
    .Input_Mantissa(sig_stage1[52:0]),
    .Input_Exp(exp_stage1),
    .Output_Mantissa(norm_mant),
    .Output_Exp(norm_exp)
  );

  // Combine fields
 // Sequential output update
always @(posedge clk) begin
  if (enable) begin
    Exception <= exception_stage1;
   if (exception_stage1) begin
        Result <= 64'd0; // user chose to return zero on exception — change per IEEE handling if needed
      end else begin
        Result <= {sign_stage1, norm_exp, norm_mant[51:0]};
  end
end


endmodule

module CLA_Adder(
  input  [53:0] A,
  input  [53:0] B,
  input         Cin,
  output [53:0] Sum,
  output        Cout
);
  wire [53:0] G = A & B;   // generate
  wire [53:0] P = A ^ B;   // propagate
  wire [54:0] C;
  assign C[0] = Cin;

  genvar i;
  generate
    for (i=0; i<54; i=i+1) begin
      assign C[i+1] = G[i] | (P[i] & C[i]);
      assign Sum[i] = P[i] ^ C[i];
    end
  endgenerate

  assign Cout = C[54];
endmodule


  
