module Priority_Encoder (
  input        clk,            // new clock input for pipelining
  input         enable,
  input  [52:0] Input_Mantissa,
  input  [10:0] Input_Exp,
  output reg [52:0] Output_Mantissa,
  output reg [10:0] Output_Exp
);

  integer i;
  reg [5:0] shift; 
  reg found;
  reg [52:0] mant_shifted;
  reg [10:0] exp_adj;

  always @(*) begin
    shift = 0;
    found = 1'b0;
    mant_shifted = Input_Mantissa;
    exp_adj = Input_Exp;
    // If input mantissa is zero, keep shift=0 and exp unchanged
    if (Input_Mantissa == 53'd0) begin
      shift = 6'd0;
      mant_shifted = Input_Mantissa;
      exp_adj = Input_Exp;
    end 
    else begin
    for (i = 0; i <= 52; i = i + 1) begin
      if (!found && Input_Mantissa[52 - i]) begin
         shift = i[5:0];            // distance to shift left
        found = 1'b1;
      end
    end

    mant_shifted = Input_Mantissa << shift;
    exp_adj      = Input_Exp - shift;
    end
  end

  // 1 pipeline register stage (helps timing closure)
  always @(posedge clk) begin
    Output_Mantissa <= mant_shifted;
    Output_Exp      <= exp_adj;
  end
endmodule
