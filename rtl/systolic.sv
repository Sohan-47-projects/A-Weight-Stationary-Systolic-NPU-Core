`timescale 1ns / 1ps
module systolic_array #(
    parameter ROWS = 4,
    parameter COLS = 4
)(
    input  logic clk,
    input  logic rst_n,

    
    input  logic load_w,
    input  logic signed [15:0] W_in [0:ROWS-1][0:COLS-1],

    input  logic signed [15:0] A_in [0:ROWS-1],

    input  logic signed [31:0] PS_in [0:COLS-1],

    output logic signed [15:0] A_out [0:ROWS-1],
    output logic signed [31:0] PS_out [0:COLS-1]
);

    
    logic signed [15:0] A_link [0:ROWS-1][0:COLS];

    logic signed [31:0] PS_link [0:ROWS][0:COLS-1];


    genvar i, j;

    generate
        for (i = 0; i < ROWS; i = i + 1) begin : ROW_INPUTS
            assign A_link[i][0] = A_in[i];
            assign A_out[i] = A_link[i][COLS];
        end

        for (j = 0; j < COLS; j = j + 1) begin : COL_INPUTS
            assign PS_link[0][j] = PS_in[j];
            assign PS_out[j] = PS_link[ROWS][j];
        end
    endgenerate

    generate
        for (i = 0; i < ROWS; i = i + 1) begin : ROW
            for (j = 0; j < COLS; j = j + 1) begin : COL

                PE pe_inst (
                    .clk    (clk),
                    .rst_n  (rst_n),

                    .load_w (load_w),
                    .w_in   (W_in[i][j]),

                    .a_in   (A_link[i][j]),
                    .ps_in  (PS_link[i][j]),

                    .a_out  (A_link[i][j+1]),
                    .ps_out (PS_link[i+1][j])
                );

            end
        end
    endgenerate

endmodule
