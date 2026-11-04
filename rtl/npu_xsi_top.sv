
`timescale 1ns / 1ps

module npu_xsi_top #(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter DEPTH = 64,
    parameter ADDR_WIDTH = 6,

    parameter WEIGHT_WIDTH = ROWS * COLS * 16,
    parameter OUTPUT_WIDTH = ROWS * COLS * 32
)(
    input  logic clk,
    input  logic rst_n,

    input  logic start,
    input  logic [ADDR_WIDTH-1:0] weight_tile_addr,
    input  logic [ADDR_WIDTH-1:0] output_tile_addr,
  
    input  logic weight_wr_en,
    input  logic [ADDR_WIDTH-1:0] weight_wr_addr,
    input  logic [WEIGHT_WIDTH-1:0] weight_wr_data,
   
    input  logic [ROWS*16-1:0] A_in,
    input  logic input_done,
 
    output logic busy,
    output logic done,
    output logic compute_active,
   
    input  logic output_rd_en,
    input  logic [ADDR_WIDTH-1:0] output_rd_addr,
    output logic [OUTPUT_WIDTH-1:0] output_rd_data,
    output logic output_rd_valid
);

    
    logic signed [15:0] activation_lanes [0:ROWS-1];

    genvar r;
    generate
        for (r = 0; r < ROWS; r = r + 1) begin : GEN_ACTIVATIONS
            assign activation_lanes[r] =
                A_in[ROWS*16-1-(r*16) -: 16];
        end
    endgenerate

    accelerator_controller #(
        .ROWS(ROWS),
        .COLS(COLS),
        .DEPTH(DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .OUTPUT_WIDTH(OUTPUT_WIDTH)
    ) controller (
        .clk(clk),
        .rst_n(rst_n),

        .start(start),
        .weight_tile_addr(weight_tile_addr),
        .output_tile_addr(output_tile_addr),

        .weight_wr_en(weight_wr_en),
        .weight_wr_addr(weight_wr_addr),
        .weight_wr_data(weight_wr_data),

        .A_in(activation_lanes),
        .input_done(input_done),

        .busy(busy),
        .done(done),
        .compute_active(compute_active),

        .output_rd_en(output_rd_en),
        .output_rd_addr(output_rd_addr),
        .output_rd_data(output_rd_data),
        .output_rd_valid(output_rd_valid)
    );

endmodule
