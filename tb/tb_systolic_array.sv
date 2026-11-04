`timescale 1ns / 1ps
module tb_systolic_array;

    localparam ROWS = 4;
    localparam COLS = 4;

    logic clk;
    logic rst_n;
    logic load_w;

    logic signed [15:0] W_in [0:3][0:3];
    logic signed [15:0] A_in [0:3];
    logic signed [31:0] PS_in [0:3];

    logic signed [15:0] A_out [0:3];
    logic signed [31:0] PS_out [0:3];

    integer A_ref [0:3][0:3];
    integer B_ref [0:3][0:3];
    integer C_ref [0:3][0:3];

    integer i, j, k;
    integer cycle;
    integer m;
    integer errors;
    integer checks;

    systolic_array #(
        .ROWS(ROWS),
        .COLS(COLS)
    ) dut (
        .clk    (clk),
        .rst_n  (rst_n),
        .load_w (load_w),
        .W_in   (W_in),
        .A_in   (A_in),
        .PS_in  (PS_in),
        .A_out  (A_out),
        .PS_out (PS_out)
    );

    
    always #5 clk = ~clk;

    initial begin

        clk     = 0;
        rst_n   = 0;
        load_w  = 0;
        errors  = 0;
        checks  = 0;

        // Matrix A
        A_ref[0][0] =  1; A_ref[0][1] =  2;
        A_ref[0][2] =  3; A_ref[0][3] =  4;

        A_ref[1][0] = -1; A_ref[1][1] =  2;
        A_ref[1][2] = -3; A_ref[1][3] =  1;

        A_ref[2][0] =  5; A_ref[2][1] =  0;
        A_ref[2][2] =  2; A_ref[2][3] = -2;

        A_ref[3][0] =  3; A_ref[3][1] = -1;
        A_ref[3][2] =  1; A_ref[3][3] =  2;

        // Matrix B
        B_ref[0][0] =  1; B_ref[0][1] =  2;
        B_ref[0][2] = -1; B_ref[0][3] =  3;

        B_ref[1][0] =  0; B_ref[1][1] = -2;
        B_ref[1][2] =  4; B_ref[1][3] =  1;

        B_ref[2][0] =  2; B_ref[2][1] =  1;
        B_ref[2][2] =  3; B_ref[2][3] = -1;

        B_ref[3][0] = -1; B_ref[3][1] =  2;
        B_ref[3][2] =  0; B_ref[3][3] =  2;

        // C = A * B
        for (i = 0; i < ROWS; i = i + 1) begin
            for (j = 0; j < COLS; j = j + 1) begin
                C_ref[i][j] = 0;

                for (k = 0; k < ROWS; k = k + 1) begin
                    C_ref[i][j] =
                        C_ref[i][j] +
                        A_ref[i][k] * B_ref[k][j];
                end
            end
        end

     
        for (i = 0; i < ROWS; i = i + 1) begin
            A_in[i] = 0;
            PS_in[i] = 0;

            for (j = 0; j < COLS; j = j + 1)
                W_in[i][j] = 0;
        end

        
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1;

        
        load_w = 1;

        for (i = 0; i < ROWS; i = i + 1)
            for (j = 0; j < COLS; j = j + 1)
                W_in[i][j] = B_ref[i][j];

        @(posedge clk);
        @(negedge clk);
        load_w = 0;

        
        
        $display("Computing C = A * B");
        
        
        for (cycle = 0; cycle < 10; cycle = cycle + 1) begin

            @(negedge clk);

            for (k = 0; k < ROWS; k = k + 1) begin

                m = cycle - k;

                if (m >= 0 && m < ROWS)
                    A_in[k] = A_ref[m][k];
                else
                    A_in[k] = 0;

            end

            
            for (j = 0; j < COLS; j = j + 1)
                PS_in[j] = 0;

            @(posedge clk);
            #1;

         
            for (j = 0; j < COLS; j = j + 1) begin

                m = cycle - j - 3;

                if (m >= 0 && m < ROWS) begin

                    checks = checks + 1;

                    if (PS_out[j] !== C_ref[m][j]) begin
                        errors = errors + 1;

                        $display(
                            "FAIL C[%0d][%0d]: expected %0d, got %0d",
                            m, j, C_ref[m][j], PS_out[j]
                        );
                    end
                    else begin
                        $display(
                            "PASS C[%0d][%0d] = %0d",
                            m, j, PS_out[j]
                        );
                    end

                end
            end
        end

        
        $display("Checks: %0d / 16", checks);
        $display("Errors: %0d", errors);

        if (errors == 0 && checks == 16)
            $display("ALL MATRIX MULTIPLICATION TESTS PASSED");
        else
            $display("TEST FAILED");

     

        $finish;
    end

endmodule
