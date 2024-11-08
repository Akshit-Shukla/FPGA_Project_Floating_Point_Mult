`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.10.2024 13:57:27
// Design Name: 
// Module Name: Top_Module
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Top_Module(
    input clk,
    input wire [31:0] Num1,
    input wire [31:0] Num2,
    output reg [31:0] out
);

    wire sign_out;
    wire [8:0] exp_out;
    wire [47:0] mantissa_out;
    wire [25:0] mantissa_out_ulp;
    wire [22:0] mantissa_out_norm;
    wire [8:0] exp_out_norm;
    
    reg sign_inter1,sign_inter2,sign_inter3,sign_inter4;
    
    reg [9:0] exp_inter1,exp_inter2,exp_inter3,exp_inter4;

    // Corrected module instantiations
    signCalc sign_calc(.clk(clk), .sign1(Num1[31]), .sign2(Num2[31]), .out(sign_out));
    expAdd exp_calc(.clk(clk), .exp1(Num1[30:23]), .exp2(Num2[30:23]), .out(exp_out));
    ManMult Man_Calc(.clk(clk), .man1(Num1[22:0]), .man2(Num2[22:0]), .out(mantissa_out));
    ULP ulp_calc(.clk(clk), .mantissa_in(mantissa_out), .mantissa_out(mantissa_out_ulp));
    normalization norm(.mantissa_in(mantissa_out_ulp), .exponent_in(exp_inter4), .mantissa_out(mantissa_out_norm), .exponent_out(exp_out_norm));
    
    always @ (posedge clk)
    begin
    sign_inter1 <= sign_out;
    sign_inter2<=sign_inter1;
    sign_inter3<=sign_inter2;
    sign_inter4 <= sign_inter3;
    //sign_inter5<=sign_inter4;
    
    exp_inter1 <= exp_out;
    exp_inter2<=exp_inter1;
    exp_inter3<=exp_inter2;
    exp_inter4<=exp_inter3;
    //exp_inter5<=exp_inter4;
    end

    always @ (*)
    begin
        // Concatenate final output with sign, exponent, and normalized mantissa
        out <= {sign_inter4, exp_out_norm[7:0], mantissa_out_norm};
    end

endmodule

module signCalc(
    input wire sign1,
    input wire sign2,
    input clk,
    output reg out
);
    always @ (*)
        out <= sign1 ^ sign2;
endmodule

module expAdd(
    input wire [7:0] exp1,
    input wire [7:0] exp2,
    input clk,
    output wire [8:0] out
);
    assign out = exp1 + exp2 - 8'd127;
endmodule

 module ManMult(
        input wire [22:0] man1,
        input wire [22:0] man2,
        input clk,
        output wire [47:0] out
    );
    
        wire [30:0] booth_out;
        wire [47:0] C;
        wire [23:0] man1_append, man2_append;
        wire [42:0] dsp_out;
    
        assign man1_append = {1'b1, man1};
        assign man2_append = {1'b1, man2};
    
        booth_multiplier booth_inst(
            .clk(clk),
            .A(man1_append),
            .B(man2_append[23:17]),
            .P(booth_out)
        );
    
        assign C = booth_out << 17; // Shift for DSP alignment
        
        wire[24:0] man1_dsp;
        wire[17:0] man2_dsp;
        
        assign man1_dsp = {1'b0,man1_append};  //to accomodate for the sign bit in dsp macro
        assign man2_dsp = {1'b0,man2_append[16:0]};
    
        dsp_macro_0 dsp_inst (
            .CLK(clk),
            .A(man1_dsp),
            .B(man2_dsp),
            .P(dsp_out)
        );
       
        assign out = dsp_out + C;
    endmodule
module normalization (
    input [25:0] mantissa_in,       // 26-bit mantissa input (includes extra precision from ULP)
    input [8:0] exponent_in,        // 9-bit biased exponent input
    output reg [22:0] mantissa_out, // Normalized 23-bit mantissa output
    output reg [8:0] exponent_out   // 10-bit exponent output (E + 2 bits for single precision)
);

    reg [25:0] mantissa_temp;       // Temporary variable for shifting the mantissa
    reg [8:0] exponent_temp;        // Temporary variable for adjusting exponent
    integer shift_count;            // Counter to limit shifts

    always @(*) begin
        // Initialize mantissa and exponent
        mantissa_temp = mantissa_in;
        exponent_temp = {1'b0, exponent_in};  // Extend exponent to 10 bits for overflow handling
        shift_count = 0;                      // Reset shift counter

        // Check for zero mantissa to avoid unnecessary shifts
        if (mantissa_in == 0) begin
            mantissa_out = 0;
            exponent_out = 0;
        end else if (mantissa_temp[25] == 1) begin
            // Already normalized
            mantissa_out = mantissa_temp[24:2];  // Use the next 23 bits
            exponent_out = exponent_temp;
        end else begin
            // Not normalized: left shift mantissa until the MSB is 1 or until maximum shifts
            while (!mantissa_temp[25] && exponent_temp > 0 && shift_count < 24) begin
                mantissa_temp = mantissa_temp << 1;
                exponent_temp = exponent_temp - 1;
                shift_count = shift_count + 1;  // Increment shift counter
            end

            // Assign normalized mantissa and exponent
            mantissa_out = mantissa_temp[24:2];  // Extract normalized 23-bit mantissa
            exponent_out = exponent_temp;        // 10-bit exponent result
        end
    end
endmodule
module ULP (
    input [47:0] mantissa_in,
    input clk,
    output wire [25:0] mantissa_out
);

    wire guard_bit = mantissa_in[23];
    wire round_bit = mantissa_in[22];
    wire sticky_bit = |mantissa_in[21:0];

    wire rounding_condition = (round_bit & sticky_bit) | (guard_bit & round_bit);

    wire [22:0] mantissa_truncated = mantissa_in[46:24];
    wire [22:0] mantissa_rounded = mantissa_truncated + rounding_condition;

    assign mantissa_out = {mantissa_rounded, 3'b000};

endmodule
module booth_multiplier(
        input [23:0] A,
        input [6:0] B,
        input clk,
        output reg [30:0] P
    );
    
        reg [30:0] partial_sum;
        reg [7:0] booth_reg;
        reg [30:0] inter1,inter2,inter3;
        integer i;
    
        always @(posedge clk) begin
            booth_reg = {B, 1'b0};
            partial_sum = 0;
            
    
            for (i = 0; i < 4; i = i + 1) begin
                case (booth_reg[2:0])
                    3'b000, 3'b111: partial_sum = partial_sum;
                    3'b001, 3'b010: partial_sum = partial_sum + (A << (2 * i));
                    3'b011:          partial_sum = partial_sum + (A << (2 * i + 1));
                    3'b100:          partial_sum = partial_sum - (A << (2 * i + 1));
                    3'b101, 3'b110:  partial_sum = partial_sum - (A << (2 * i));
                endcase
                booth_reg = booth_reg >> 2;
            end
    
            
        end
        
        always @(posedge clk)
        begin
        inter3 <= partial_sum;
        inter2<=inter3;
        inter1<=inter2;
        P<=inter1;
        
        end
      
        
    endmodule
