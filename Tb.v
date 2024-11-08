`timescale 1ns / 1ps

module Top_Module_tb;
    reg clk;
    reg [31:0] Num1, Num2;
    wire [31:0] out;

    // Instantiate the design under test (DUT)
    Top_Module uut (
        .clk(clk),
        .Num1(Num1),
        .Num2(Num2),
        .out(out)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10 ns clock period
    end

    // Test cases
    initial begin
        // Display header
        $display("Time\t\tNum1\t\t\tNum2\t\t\tExpected Out\t\tActual Out");

        // Test 1: Multiply 2.0 * 2.0
        Num1 = 32'h40000000; // 2.0 in IEEE 754 format
        Num2 = 32'h40000000; // 2.0 in IEEE 754 format
        #50; // Wait for 5 clock cycles (latency of multiplier)
        $display("%0dns\t%h\t%h\t%h\t%h", $time, Num1, Num2, 32'h40400000, out); // Expected: 4.0 (0x40400000)

        // Test 2: Multiply 1.5 * -2.5
        Num1 = 32'h3FC00000; // 1.5 in IEEE 754 format
        Num2 = 32'hC0200000; // -2.5 in IEEE 754 format
        #50;
        $display("%0dns\t%h\t%h\t%h\t%h", $time, Num1, Num2, 32'hC03E0000, out); // Expected: -3.75 (0xC03E0000)

        // Test 3: Multiply -3.75 * 0.5
        Num1 = 32'hC03E0000; // -3.75 in IEEE 754 format
        Num2 = 32'h3F000000; // 0.5 in IEEE 754 format
        #50;
        $display("%0dns\t%h\t%h\t%h\t%h", $time, Num1, Num2, 32'hBF800000, out); // Expected: -1.875 (0xBF800000)

        // Test 4: Multiply 0.0 * 4.5
        Num1 = 32'h00000000; // 0.0 in IEEE 754 format
        Num2 = 32'h40900000; // 4.5 in IEEE 754 format
        #50;
        $display("%0dns\t%h\t%h\t%h\t%h", $time, Num1, Num2, 32'h00000000, out); // Expected: 0.0 (0x00000000)

        // Test 5: Multiply 1.0 * 1.0
        Num1 = 32'h3F800000; // 1.0 in IEEE 754 format
        Num2 = 32'h3F800000; // 1.0 in IEEE 754 format
        #50;
        $display("%0dns\t%h\t%h\t%h\t%h", $time, Num1, Num2, 32'h3F800000, out); // Expected: 1.0 (0x3F800000)

        // Test 6: Multiply 1000.0 * 0.001
        Num1 = 32'h447A0000; // 1000.0 in IEEE 754 format
        Num2 = 32'h3A83126F; // 0.001 in IEEE 754 format
        #50;
        $display("%0dns\t%h\t%h\t%h\t%h", $time, Num1, Num2, 32'h3F800000, out); // Expected: 1.0 (0x3F800000)

        // End of tests
        $finish;
    end
endmodule
