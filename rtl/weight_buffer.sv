`timescale 1ns / 1ps
module weight_buffer #(

    parameter DEPTH = 64,
    parameter ADDR_WIDTH = 6,
    parameter DATA_WIDTH = 256
)
(
    input  logic                  clk,
    input  logic                  rst_n,

    input  logic                  wr_en,
    input  logic [ADDR_WIDTH-1:0] wr_addr,
    input  logic [DATA_WIDTH-1:0] wr_data,

    input  logic                  rd_en,
    input  logic [ADDR_WIDTH-1:0] rd_addr,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  rd_valid
);


    (* ram_style = "block" *)
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always_ff @(posedge clk) begin

        if (wr_en)
            mem[wr_addr] <= wr_data;

        if (!rst_n) begin
            rd_valid <= 1'b0;
        end
        else begin
            rd_valid <= rd_en;

            if (rd_en)
                rd_data <= mem[rd_addr];
        end

    end

endmodule