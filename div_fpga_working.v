`timescale 1ns/1ps

module fp_div (
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
            
            mant_res = (mant_a << 53) / mant_b;
            mant_dividend = (mant_a << 53);
            mant_divisor = mant_b;
			mant_divion m1(.mant_dividend(x), .mant_divisor(y), .mant_res (q), .remainder (r));
module mant_division(x,y,q,r);
    input [51:0]x //Dividend
,y; //Divisor
    output reg [51:0]q,r;
    reg [52:0]a;    
    reg [52:0]m;   
integer i;

always @(*) begin
    if (y!=52'd0) begin
        m[51:0]=y;
        m[52]=0;
        a=53'd0;
        q=x;
    for(i=0;i<52;i=i+1) begin
	//Shift Left
	a=a<<1;
        a[0]=q[51];
	q=q<<1;
	a=a-m;
        if(a[52]==1) begin
		q[0]=0;
		a=a+m; //Restore
	end
	else
	q[0]=1;
end
        r=a[51:0];
end
else
begin
	q=52'd0;
	r=52'd0;
end
end
endmodule

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



`timescale 1ns/1ps

module tb_fp_div;
    reg  [63:0] a, b;
    wire [63:0] result;

    fp_div uut (
        .a(a),
        .b(b),
        .result(result)
    );
    
    // Output formatting task
    task display_case;
        input [255:0] label;
        begin
        $display("%0t ns | %-24s | A: %h  B: %h  -> Result: %h", $time, label, a, b, result);
        end
    endtask

    initial begin
        $display("\n Running Division Testbench \n");

        // 1. Basic division
        a = 64'h4024000000000000; b = 64'h4000000000000000; // 10.0 / 2.0
        #10 display_case("10.0 / 2.0");

        a = 64'h4018000000000000; b = 64'h4008000000000000; // 6.0 / 3.0
        #10 display_case("6.0 / 3.0");

        a = 64'h4008000000000000; b = 64'h3ff0000000000000; // 3.0 / 1.0
        #10 display_case("3.0 / 1.0");

        // 2. Fractional division
        a = 64'h3fe0000000000000; b = 64'h3fd0000000000000; // 0.5 / 0.25 = 2.0
        #10 display_case("0.5 / 0.25");

        a = 64'h3fd0000000000000; b = 64'h3fe0000000000000; // 0.25 / 0.5 = 0.5
        #10 display_case("0.25 / 0.5");

        a = 64'h3ff0000000000000; b = 64'h4008000000000000; // 1.0 / 3.0 = repeating
        #10 display_case("1.0 / 3.0");

        // 3. Subnormals
        a = 64'h0000000000000001; b = 64'h3ff0000000000000; // min_subnormal / 1.0
        #10 display_case("subnormal / 1.0");

        a = 64'h0010000000000000; b = 64'h3ff0000000000000; // min_normal / 1.0
        #10 display_case("min_normal / 1.0");

        // 4. Infinity and Zero
        a = 64'h7ff0000000000000; b = 64'h4000000000000000; // inf / 2.0 = inf
        #10 display_case("inf / 2.0");

        a = 64'h0000000000000000; b = 64'h7ff0000000000000; // 0 / inf = 0
        #10 display_case("0 / inf");

        a = 64'h7ff0000000000000; b = 64'h7ff0000000000000; // inf / inf = NaN
        #10 display_case("inf / inf (NaN)");

        a = 64'h0000000000000000; b = 64'h0000000000000000; // 0 / 0 = NaN
        #10 display_case("0 / 0 (NaN)");

        a = 64'h7ff8000000000000; b = 64'h4000000000000000; // NaN / 2.0 = NaN
        #10 display_case("NaN / 2.0");

        // 5. Edge rounding case
        a = 64'h0000000000000001; b = 64'h0000000000000002; // ~0.5
        #10 display_case("denorm / denorm");

        // 6. Negative division
        a = 64'hc010000000000000; b = 64'h4000000000000000; // -4.0 / 2.0 = -2.0
        #10 display_case("-4.0 / 2.0");

        $display("\n Testbench Completed \n");
        $finish;
    end

endmodule
