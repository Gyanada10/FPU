
module ALU (
         
  input  wire  enable,      
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
  wire Add_Sub_Exception, Add_Sub_Overflow, Add_Sub_Underflow ;
  wire Mul_Exception,Mul_Overflow, Mul_Underflow;
  wire Div_Exception, Div_Overflow, Div_Underflow;

  Addition_Subtraction addsub_inst (
    .enable(enable_addsub),             
    .a_operand(a_operand),
    .b_operand(b_operand),
    .Add_or_Sub(add_sub_ctrl),
    .Result(Add_Sub_Output),
    .Exception(Add_Sub_Exception),
    .Overflow(Add_sub_Overflow),
    .Underflow(Add_sub_Underfow)  
  );

  Multiplication mul_inst (
    .enable(enable_mul),
    .a_operand(a_operand),
    .b_operand(b_operand),
    .Exception(Mul_Exception),
    .Overflow(Mul_Overflow),
    .Underflow(Mul_Underflow),
    .result(Mul_Output)
  );

Division divinst(
	.enable(enable_div),
    .a(a_operand),     
    .b(b_operand),     
    .Result(Div_Output), 
    .Exception(Div_Exception) 
);




  always @(*) begin
  
	if (enable) begin
		
    case(Operation)
		
      OP_ADD, OP_SUB: 
			begin 
				ALU_Output = Add_Sub_Output; 
				Exception = Add_Sub_Exception;
				Overflow = Add_sub_Overflow;  	
				Underflow =Add_sub_Underfow;
			end		
			
      OP_MUL: 
			begin
				ALU_Output = Mul_Output; 
				Exception = Mul_Exception;
				Overflow = Mul_Overflow; 
				Underflow = Mul_Underflow;
			end			
			
      OP_DIV: 
			begin 
				ALU_Output = Div_Output; 
				Exception = Div_Exception;
			end			
			
      OP_AND: 
            begin
			     ALU_Output = a_operand & b_operand;
			     Exception = 1'b0;
			end		
		
      OP_OR :
            begin
			     ALU_Output = a_operand | b_operand;
			     Exception = 1'b0;
			end	
						
			
      OP_XOR: 
			begin
			     ALU_Output = a_operand ^ b_operand;
			     Exception = 1'b0;
			end			
			
      OP_NOT: 
			begin
			     ALU_Output = ~a_operand;
			     Exception = 1'b0;
			end	  		
			
      OP_LS: 	
			begin
			     ALU_Output = a_operand << 1'b1;	
			     Exception = 1'b0;
			end	
			
      OP_RS: 
			begin
			     ALU_Output = a_operand >> 1'b1;	
			     Exception = 1'b0;
			end	
				
      OP_FPI: 
			begin
			     ALU_Output = Int_output;	
			     Exception = 1'b0;
			end	
					
			
      default: ALU_Output = 64'd0;
    
	endcase
  end
    
  else begin
  
		  ALU_Output = 64'd0; 
		  Exception = 1'b0; 
		  Overflow = 1'b0; 
		  Underflow = 1'b0;
  
  end
  
  end

endmodule

