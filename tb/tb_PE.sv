
`timescale 1ns/1ps

module tb_PE;

    logic clk;
    logic rst_n;

    logic load_w;
    logic signed [15:0] w_in;
    logic signed [15:0] a_in;
    logic signed [31:0] ps_in;

    logic signed [15:0] a_out;
    logic signed [31:0] ps_out;

 
    PE dut (
        .clk(clk),
        .rst_n(rst_n),
        .load_w(load_w),
        .w_in(w_in),
        .a_in(a_in),
        .ps_in(ps_in),
        .a_out(a_out),
        .ps_out(ps_out)
    );

    
    initial clk = 0;
    always #5 clk = ~clk;

    task automatic check(
        input logic signed [15:0] expected_a,
        input logic signed [31:0] expected_ps,
        input string test_name
    );
        begin
            #1;
            if (a_out !== expected_a || ps_out !== expected_ps) begin
                $display("FAIL: %s | A=%0d expected=%0d | PS=%0d expected=%0d",
                         test_name, a_out, expected_a, ps_out, expected_ps);
                $fatal;
            end
            else begin
                $display("PASS: %s", test_name);
            end
        end
    endtask

    initial begin
        $dumpfile("pe.vcd");
        $dumpvars(0, tb_PE);

        rst_n  = 0;
        load_w = 0;
        w_in   = 0;
        a_in   = 0;
        ps_in  = 0;

        
        repeat (2) @(posedge clk);
        #1;
        rst_n = 1;

        
        @(negedge clk);
        load_w = 1;
        w_in = 5;

        @(negedge clk);
        load_w = 0;

        // 5 * 3 + 0 = 15
        a_in = 3;
        ps_in = 0;
        @(posedge clk);
        check(3, 15, "Positive multiplication");

        // 5 * -4 + 10 = -10
        @(negedge clk);
        a_in = -4;
        ps_in = 10;
        @(posedge clk);
        check(-4, -10, "Signed multiplication");

        // 5 * -3 + 20 = 5
        @(negedge clk);
        a_in = -3;
        ps_in = 20;
        @(posedge clk);
        check(-3, 5, "Negative activation");

        // 5 * 6 + 100 = 130
        @(negedge clk);
        a_in = 6;
        ps_in = 100;
        @(posedge clk);
        check(6, 130, "Partial sum accumulation");

        $display("\nALL TESTS PASSED");
        $finish;
    end

endmodule
