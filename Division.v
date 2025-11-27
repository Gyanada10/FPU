`timescale 1ns/1ps

module Division (
    input  wire [63:0] a,     
    input  wire [63:0] b,     
    output reg  [63:0] result 
);

    // Step 1: Unpack inputs 
    wire sign_a     = a[63];        
    wire [10:0] exp_a = a[62:52];    
    wire [51:0] frac_a = a[51:0];    

    wire sign_b     = b[63];         
    wire [10:0] exp_b = b[62:52];    
    wire [51:0] frac_b = b[51:0];    

    // Step 2: Special cases detection 
    wire is_zero_a = (exp_a == 0) && (frac_a == 0);
    wire is_zero_b = (exp_b == 0) && (frac_b == 0);
    wire is_inf_a  = (exp_a == 11'h7FF) && (frac_a == 0);
    wire is_inf_b  = (exp_b == 11'h7FF) && (frac_b == 0);
    wire is_nan_a  = (exp_a == 11'h7FF) && (frac_a != 0);
    wire is_nan_b  = (exp_b == 11'h7FF) && (frac_b != 0);

    // Step 3: Result sign and quiet NaN definition
    wire result_sign = sign_a ^ sign_b;                         
    wire [63:0] quiet_nan = {1'b0, 11'h7FF, 1'b1, 51'b0};       

    // Step 4: Internal registers 
    reg [10:0] exp_r;                
    reg [10:0] exp_a_int, exp_b_int; 
    reg [53:0] mant_a, mant_b;       
    reg [105:0] mant_res;            
	reg [51:0] mant_dividend;
    reg [51:0] mant_divisor; 
	
    always @(*) begin
        // Step 5: Handle special cases (IEEE 754 rules) 
        if (is_nan_a || is_nan_b) begin
            result = quiet_nan;                      // If either input is NaN → result is NaN
        end else if ((is_zero_a && is_zero_b) || (is_inf_a && is_inf_b)) begin
            result = quiet_nan;                      // 0/0 or Inf/Inf → NaN
        end else if (is_zero_b) begin
            result = {result_sign, 11'h7FF, 52'b0};  // Division by 0 → Inf
        end else if (is_zero_a) begin
            result = {result_sign, 63'b0};           // 0 / x → 0
        end else if (is_inf_a) begin
            result = {result_sign, 11'h7FF, 52'b0};  // Inf / x → Inf
        end else if (is_inf_b) begin
            result = {result_sign, 63'b0};           // x / Inf → 0
        end else begin
            // Step 6: Normalize mantissas
            
            mant_a = (exp_a == 0) ? {1'b0, frac_a} : {1'b1, frac_a};
            mant_b = (exp_b == 0) ? {1'b0, frac_b} : {1'b1, frac_b};

            
            exp_a_int = (exp_a == 0) ? 11'd1 : exp_a;
            exp_b_int = (exp_b == 0) ? 11'd1 : exp_b;

            
            exp_r = exp_a_int - exp_b_int + 1023;

            // Step 7: Mantissa division

			wire [105:0] recip_b;
			Reciprocal_NR recip_inst (
				.d(mant_b),
				.recip_out(recip_b)
			);

			mant_res = mant_a * recip_b;

            // Step 8: Normalize the result
           
            if (mant_res[53] == 0) begin
                mant_res = mant_res << 1;
                exp_r = exp_r - 1;
            end

            // Step 9: Pack final result 
        
            result = {result_sign, exp_r, mant_res[52:1]};
        end
    end

endmodule

module Reciprocal_NR (
    input  [52:0] d,          // divisor mantissa (normalized, 53 bits)
    output [105:0] recip_out  // reciprocal approximation (scaled for mantissa multiply)
);
    // Initial approximation (for coursework, use a rough shift)
    // In practice, you'd use a LUT for better accuracy
    reg [105:0] x0;
    reg [105:0] x1;

    always @(*) begin
        // crude initial guess: 1/d ≈ (2^53)/d
        x0 = (1 << 53) / d;

        // Newton–Raphson refinement: x1 = x0 * (2 - d*x0)
        x1 = x0 * ((1 << 54) - d * x0) >> 53;

    end

    assign recip_out = x1;
endmodule


