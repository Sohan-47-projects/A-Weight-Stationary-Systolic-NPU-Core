`timescale 1ns/1ps
module PE (
    input  logic              clk,
    input  logic              rst_n,

    input  logic              load_w,
    input  logic signed [15:0] w_in,

    input  logic signed [15:0] a_in,
    input  logic signed [31:0] ps_in,

    output logic signed [15:0] a_out,
    output logic signed [31:0] ps_out
);

    logic signed [15:0] w_reg;
    logic signed [31:0] product;


    logic signed [31:0] a_ext;
    logic signed [31:0] w_ext;

    assign a_ext = {{16{a_in[15]}}, a_in};
    assign w_ext = {{16{w_reg[15]}}, w_reg};

    
    assign product = a_ext * w_ext;

    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            w_reg <= '0;
        else if (load_w)
            w_reg <= w_in;
    end

    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_out  <= '0;
            ps_out <= '0;
        end
        else begin
            a_out  <= a_in;
            ps_out <= product + ps_in;
        end
    end

endmodule
