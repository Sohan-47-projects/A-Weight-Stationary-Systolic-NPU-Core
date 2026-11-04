`timescale 1ns / 1ps
module accelerator_controller #(
    parameter ROWS       = 4,
    parameter COLS       = 4,
    parameter DEPTH      = 64,
    parameter ADDR_WIDTH = 6,

    parameter WEIGHT_WIDTH = ROWS * COLS * 16,
    parameter OUTPUT_WIDTH = ROWS * COLS * 32
)(
    input logic clk,
    input logic rst_n,


    input logic start,
    input logic [ADDR_WIDTH-1:0] weight_tile_addr,
    input logic [ADDR_WIDTH-1:0] output_tile_addr,

    
    input logic weight_wr_en,
    input logic [ADDR_WIDTH-1:0] weight_wr_addr,
    input logic [WEIGHT_WIDTH-1:0] weight_wr_data,

    
    input logic signed [15:0] A_in [0:ROWS-1],
    input logic input_done,

    
    output logic busy,
    output logic done,
    output logic compute_active,

    
    input logic output_rd_en,
    input logic [ADDR_WIDTH-1:0] output_rd_addr,
    output logic [OUTPUT_WIDTH-1:0] output_rd_data,
    output logic output_rd_valid
);

    
    typedef enum logic [2:0] {
        IDLE,
        READ_WEIGHT,
        WAIT_WEIGHT,
        LOAD_ARRAY,
        COMPUTE,
        WRITE_OUTPUT,
        DONE
    } state_t;

    state_t state;

   
    logic [ADDR_WIDTH-1:0] weight_addr_reg;
    logic [ADDR_WIDTH-1:0] output_addr_reg;

    logic [31:0] compute_cycle;
    logic input_done_seen;

    logic [OUTPUT_WIDTH-1:0] tile_reg;

    integer collected_count;
    integer valid_count;

    

    logic weight_rd_en;
    logic [ADDR_WIDTH-1:0] weight_rd_addr;

    logic [WEIGHT_WIDTH-1:0] weight_rd_data;
    logic weight_rd_valid;

    

    logic load_w;

    logic signed [15:0] W_in [0:ROWS-1][0:COLS-1];

    logic signed [15:0] array_A_in [0:ROWS-1];
    logic signed [31:0] array_PS_in [0:COLS-1];

    logic signed [15:0] A_out [0:ROWS-1];
    logic signed [31:0] PS_out [0:COLS-1];

    

    logic output_wr_en;
    logic [ADDR_WIDTH-1:0] output_wr_addr;
    logic [OUTPUT_WIDTH-1:0] output_wr_data;



    logic [COLS-1:0] result_valid;

    integer result_row [0:COLS-1];

    integer j;
    integer row_index;

    

    assign busy = (state != IDLE) && (state != DONE);

    assign done = (state == DONE);

    assign compute_active = (state == COMPUTE);

    

    assign weight_rd_en = (state == READ_WEIGHT);

    assign weight_rd_addr = weight_addr_reg;

    weight_buffer #(
        .DEPTH      (DEPTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (WEIGHT_WIDTH)
    ) weight_mem (
        .clk     (clk),
        .rst_n   (rst_n),

        .wr_en   (weight_wr_en),
        .wr_addr (weight_wr_addr),
        .wr_data (weight_wr_data),

        .rd_en   (weight_rd_en),
        .rd_addr (weight_rd_addr),
        .rd_data (weight_rd_data),
        .rd_valid(weight_rd_valid)
    );

    
    always_ff @(posedge clk) begin
        if (state == WAIT_WEIGHT && weight_rd_valid) begin

            for (integer r = 0; r < ROWS; r = r + 1) begin
                for (integer c = 0; c < COLS; c = c + 1) begin

                    W_in[r][c] <=
                        weight_rd_data[
                            WEIGHT_WIDTH-1-((r*COLS+c)*16) -: 16
                        ];

                end
            end

        end
    end

    

    assign load_w = (state == LOAD_ARRAY);

    always_comb begin

        for (integer r = 0; r < ROWS; r = r + 1)
            array_A_in[r] = '0;

        for (integer c = 0; c < COLS; c = c + 1)
            array_PS_in[c] = '0;

        if (state == COMPUTE) begin

            for (integer r = 0; r < ROWS; r = r + 1)
                array_A_in[r] = A_in[r];

        end

    end

    systolic_array #(
        .ROWS (ROWS),
        .COLS (COLS)
    ) array (
        .clk    (clk),
        .rst_n  (rst_n),

        .load_w (load_w),
        .W_in   (W_in),

        .A_in   (array_A_in),
        .PS_in  (array_PS_in),

        .A_out  (A_out),
        .PS_out (PS_out)
    );

    
    always_comb begin

        result_valid = '0;
        valid_count = 0;

        for (integer c = 0; c < COLS; c = c + 1) begin

            result_row[c] = 0;

            

            if (compute_cycle > 0) begin

                row_index =
                    (compute_cycle - 1) - c - (ROWS - 1);

                if (row_index >= 0 && row_index < ROWS) begin

                    result_valid[c] = 1'b1;
                    result_row[c] = row_index;

                    valid_count = valid_count + 1;

                end

            end

        end

    end

    

    assign output_wr_en   = (state == WRITE_OUTPUT);
    assign output_wr_addr = output_addr_reg;
    assign output_wr_data = tile_reg;

    output_buffer #(
        .DEPTH      (DEPTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (OUTPUT_WIDTH)
    ) output_mem (
        .clk     (clk),
        .rst_n   (rst_n),

        .wr_en   (output_wr_en),
        .wr_addr (output_wr_addr),
        .wr_data (output_wr_data),

        .rd_en   (output_rd_en),
        .rd_addr (output_rd_addr),
        .rd_data (output_rd_data),
        .rd_valid(output_rd_valid)
    );

   

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            state            <= IDLE;

            weight_addr_reg  <= '0;
            output_addr_reg  <= '0;

            compute_cycle    <= 0;
            input_done_seen  <= 0;

            collected_count  <= 0;
            tile_reg         <= '0;

        end
        else begin

            case (state)



                IDLE: begin

                    if (start) begin

                        weight_addr_reg <= weight_tile_addr;
                        output_addr_reg <= output_tile_addr;

                        state <= READ_WEIGHT;

                    end

                end

             

                READ_WEIGHT: begin

                    state <= WAIT_WEIGHT;

                end

               

                WAIT_WEIGHT: begin

                    if (weight_rd_valid) begin

                        state <= LOAD_ARRAY;

                    end

                end


                LOAD_ARRAY: begin

                    compute_cycle   <= 0;
                    input_done_seen <= 0;

                    collected_count <= 0;
                    tile_reg        <= '0;

                    state <= COMPUTE;

                end


                COMPUTE: begin

                    compute_cycle <= compute_cycle + 1;

                    if (input_done)
                        input_done_seen <= 1'b1;

                    for (integer c = 0; c < COLS; c = c + 1) begin

                        if (result_valid[c]) begin

                            tile_reg[
                                OUTPUT_WIDTH-1-
                                ((result_row[c]*COLS+c)*32) -: 32
                            ] <= PS_out[c];

                        end

                    end

                    collected_count <=
                        collected_count + valid_count;

                   
                    if (
                        (input_done_seen || input_done) &&
                        (collected_count + valid_count == ROWS*COLS)
                    ) begin

                        state <= WRITE_OUTPUT;

                    end

                end

                

                WRITE_OUTPUT: begin

                    state <= DONE;

                end


                DONE: begin

                    state <= IDLE;

                end

                default: begin

                    state <= IDLE;

                end

            endcase

        end

    end

endmodule
