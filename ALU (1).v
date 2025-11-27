`include "Addition_Subtraction.v"
`include "Multiplication.v"
`include "Division.v"

module ALU (
  input  wire  clk,       
  input  wire  reset,      
  input  wire  [3:0]  Operation, // ALU operation code
  input  wire  [63:0] a_operand, // operand A
  input  wire  [63:0] b_operand, // operand B
  output reg   [63:0] ALU_Output,
  output reg   Exception,
  output reg   Overflow,
  output reg   Underflow
);

  // 1. Define operation codes using localparams (readable constants)
  localparam OP_ADD = 4'd1,  //a_operand + b_operand
             OP_SUB = 4'd2,  //a_operand - b_operand
             OP_MUL = 4'd3,  //a_operand * b_operand
             OP_DIV  = 4'd4, //a_operand / b_operand
             OP_AND = 4'd5,  //a_operand & b_operand
             OP_OR = 4'd6,   //a_operand | b_operand
             OP_XOR = 4'd7,  //a_operand ^ b_operand
             OP_NOT = 4'd8,  //~a_operand
             OP_LS = 4'd9,   //1 bit left shift on a_operand
             OP_RS = 4'd10,  //1 bit right shift on a_operand
             OP_FPI = 4'd11; //converting FP a_operand to integer

  // 2. Safe input driving for submodules (no 'z')
  wire  add_sub_ctrl = (Operation == OP_SUB); // 1=sub, 0=add

  // 3. Enable signals for power saving (gating heavy modules)
  wire enable_mul = (Operation == OP_MUL);
  wire enable_div = (Operation == OP_DIV);
  wire enable_addsub = (Operation == OP_ADD) || (Operation == OP_SUB);

  // 4. Submodule instantiations (with enable signals)
  wire [63:0] Add_Sub_Output, Mul_Output, Div_Output, Int_output;
  wire Add_Sub_Exception, Mul_Exception, Div_Exception;
  wire Mul_Overflow, Mul_Underflow;


  Addition_Subtraction addsub_inst (
    .clk(clk),
    .enable(enable_addsub),             
    .a_operand(a_operand),
    .b_operand(b_operand),
    .Add_or_Sub(add_sub_ctrl),
    .Exception(Add_Sub_Exception),
    .Result(Add_Sub_Output)
  );

  Multiplication mul_inst (
    .clk(clk),
    .enable(enable_mul),
    .reset(reset),
    .a_operand(a_operand),
    .b_operand(b_operand),
    .Exception(Mul_Exception),
    .Overflow(Mul_Overflow),
    .Underflow(Mul_Underflow),
    .result(Mul_Output)
  );

 Division div_inst (
    .clk(clk),
    .enable(enable_div),
    .reset(reset),
    .a(a_operand),
    .b(b_operand),
    .q(Div_Output),
    .r(),
    .busy(),
    .ready(),
    .count()
);


  // 5. Combinational logic for operation selection
  reg [63:0] alu_out;
  reg exc, ovf, unf;

  always @(*) begin
    alu_out = 64'd0; exc = 1'b0; ovf = 1'b0; unf = 1'b0;
    case(Operation)
      OP_ADD,
      OP_SUB: begin alu_out = Add_Sub_Output; exc = Add_Sub_Exception; end
      OP_MUL: begin alu_out = Mul_Output; exc = Mul_Exception;
               ovf = Mul_Overflow; unf = Mul_Underflow; end
      OP_DIV: begin alu_out = Div_Output; exc = Div_Exception; end
      OP_AND: alu_out = a_operand & b_operand;
      OP_OR : alu_out = a_operand | b_operand;
      OP_XOR: alu_out = a_operand ^ b_operand;
      OP_NOT: alu_out = ~a_operand;   
      OP_LS: alu_out = a_operand << 1'b1;
      OP_RS: alu_out = a_operand >> 1'b1;
      OP_FPI: alu_out = Int_output;
      default: alu_out = 64'd0;
    endcase
  end

  // 6. Registered outputs (timing stability + glitch reduction)
  always @(posedge clk) begin
    ALU_Output <= alu_out;
    Exception  <= exc;
    Overflow   <= ovf;
    Underflow  <= unf;
  end

endmodule
