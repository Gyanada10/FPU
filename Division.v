`timescale 1ns/1ps

module Division (
    input  wire        clk,
    input  wire        rst,

    input  wire [63:0] a,
    input  wire [63:0] b,

    output reg  [63:0] result
);

    // ------------------------------------------------------------
    // Stage 1: Unpack and classify
    // ------------------------------------------------------------

    // Unpack
    wire sign_a     = a[63];
    wire [10:0] exp_a  = a[62:52];
    wire [51:0] frac_a = a[51:0];

    wire sign_b     = b[63];
    wire [10:0] exp_b  = b[62:52];
    wire [51:0] frac_b = b[51:0];

    // Detect special cases
    wire is_zero_a = (exp_a == 0) && (frac_a == 0);
    wire is_zero_b = (exp_b == 0) && (frac_b == 0);
    wire is_inf_a  = (exp_a == 11'h7FF) && (frac_a == 0);
    wire is_inf_b  = (exp_b == 11'h7FF) && (frac_b == 0);
    wire is_nan_a  = (exp_a == 11'h7FF) && (frac_a != 0);
    wire is_nan_b  = (exp_b == 11'h7FF) && (frac_b != 0);

    wire result_sign = sign_a ^ sign_b;

    wire [63:0] quiet_nan = {1'b0, 11'h7FF, 1'b1, 51'b0};

    // ---------------- PIPELINE STAGE 1 REGISTERS ----------------

    reg [63:0] stage1_special_result;
    reg        stage1_is_special;

    reg        s1_result_sign;
    reg [10:0] s1_exp_a, s1_exp_b;
    reg [52:0] s1_mant_a, s1_mant_b;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            stage1_is_special <= 0;
            stage1_special_result <= 0;
        end else begin
            // Handle specials
            if (is_nan_a || is_nan_b ||
                (is_zero_a && is_zero_b) ||
                (is_inf_a && is_inf_b)) begin

                stage1_is_special     <= 1;
                stage1_special_result <= quiet_nan;

            end else if (is_zero_b) begin
                stage1_is_special     <= 1;
                stage1_special_result <= {result_sign, 11'h7FF, 52'b0};

            end else if (is_zero_a) begin
                stage1_is_special     <= 1;
                stage1_special_result <= {result_sign, 63'b0};

            end else if (is_inf_a) begin
                stage1_is_special     <= 1;
                stage1_special_result <= {result_sign, 11'h7FF, 52'b0};

            end else if (is_inf_b) begin
                stage1_is_special     <= 1;
                stage1_special_result <= {result_sign, 63'b0};

            end else begin
                // Normal numbers → continue pipeline
                stage1_is_special     <= 0;

                s1_result_sign <= result_sign;

                // Normalize mantissas
                s1_mant_a <= (exp_a == 0) ? {1'b0, frac_a} : {1'b1, frac_a};
                s1_mant_b <= (exp_b == 0) ? {1'b0, frac_b} : {1'b1, frac_b};

                s1_exp_a <= (exp_a == 0) ? 11'd1 : exp_a;
                s1_exp_b <= (exp_b == 0) ? 11'd1 : exp_b;
            end
        end
    end

    // ------------------------------------------------------------
    // Stage 2: Exponent difference and prepare dividend/divisor
    // ------------------------------------------------------------
    reg        s2_result_sign;
    reg [10:0] s2_exp_r;

    reg [105:0] s2_dividend;
    reg [52:0]  s2_divisor;

    reg         stage2_is_special;
    reg [63:0]  stage2_special_result;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            stage2_is_special <= 0;
        end else begin
            stage2_is_special     <= stage1_is_special;
            stage2_special_result <= stage1_special_result;

            if (!stage1_is_special) begin
                s2_result_sign <= s1_result_sign;

                // exponent difference
                s2_exp_r <= s1_exp_a - s1_exp_b + 1023;

                // shift mantissa for precise division
                s2_dividend <= (s1_mant_a << 53);
                s2_divisor  <= s1_mant_b;
            end
        end
    end

    // ------------------------------------------------------------
    // Stage 3: Do division, normalize, pack
    // ------------------------------------------------------------
    reg [63:0] final_result;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            result <= 0;
        end else begin
            if (stage2_is_special) begin
                final_result <= stage2_special_result;
            end else begin
                // Mantissa division
                reg [105:0] mant_res;
                reg [10:0] exp_r;

                mant_res = s2_dividend / s2_divisor;
                exp_r    = s2_exp_r;

                // Normalize result
                if (mant_res[53] == 0) begin
                    mant_res = mant_res << 1;
                    exp_r    = exp_r - 1;
                end

                // Pack final IEEE-754 result
                final_result <= {s2_result_sign, exp_r, mant_res[52:1]};
            end

            result <= final_result;
        end
    end

endmodule
