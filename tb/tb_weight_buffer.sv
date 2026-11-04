
`timescale 1ns / 1ps

module tb_weight_buffer;

    localparam DEPTH      = 64;
    localparam ADDR_WIDTH = 6;
    localparam DATA_WIDTH = 256;

    logic clk;
    logic rst_n;

    logic wr_en;
    logic [ADDR_WIDTH-1:0] wr_addr;
    logic [DATA_WIDTH-1:0] wr_data;

    logic rd_en;
    logic [ADDR_WIDTH-1:0] rd_addr;
    logic [DATA_WIDTH-1:0] rd_data;
    logic rd_valid;

    logic [DATA_WIDTH-1:0] expected [0:DEPTH-1];

    integer errors;
    integer i;


    weight_buffer DUT (
        .clk      (clk),
        .rst_n    (rst_n),

        .wr_en    (wr_en),
        .wr_addr  (wr_addr),
        .wr_data  (wr_data),

        .rd_en    (rd_en),
        .rd_addr  (rd_addr),
        .rd_data  (rd_data),
        .rd_valid (rd_valid)
    );

    
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin

        errors = 0;

        wr_en   = 0;
        wr_addr = 0;
        wr_data = 0;

        rd_en   = 0;
        rd_addr = 0;

        rst_n = 0;

       
        $display("WEIGHT BUFFER TEST");
        $display("64 TILES x 256 BITS");
    

        // Release reset
        repeat (2) @(negedge clk);
        rst_n = 1;

      

        $display("\nTEST 1: Writing 64 tiles");

        for (i = 0; i < DEPTH; i = i + 1) begin

            @(negedge clk);

            wr_en   = 1;
            wr_addr = i;

            
            wr_data = {16{(16'h1234 + i)}};

            expected[i] = {16{(16'h1234 + i)}};

        end

        @(negedge clk);
        wr_en = 0;

        $display("PASS: All 64 tiles written");

       
        $display("\nTEST 2: Reading 64 tiles");

        for (i = 0; i < DEPTH; i = i + 1) begin

            @(negedge clk);

            rd_en   = 1;
            rd_addr = i;

            @(posedge clk);
            #1;

            if (rd_valid && rd_data === expected[i]) begin
                $display("PASS: Tile %0d", i);
            end
            else begin
                $display("FAIL: Tile %0d", i);
                errors = errors + 1;
            end

        end

        @(negedge clk);
        rd_en = 0;

       

        $display("\nTEST 3: Back-to-back reads");

        for (i = 63; i >= 0; i = i - 1) begin

            @(negedge clk);

            rd_en   = 1;
            rd_addr = i;

            @(posedge clk);
            #1;

            if (!rd_valid || rd_data !== expected[i]) begin
                $display("FAIL: Back-to-back read tile %0d", i);
                errors = errors + 1;
            end

        end

        @(negedge clk);
        rd_en = 0;

        

        $display("\nTEST 4: Simultaneous read/write");

        @(negedge clk);

        wr_en   = 1;
        wr_addr = 6'd10;
        wr_data = {16{16'hBEEF}};

        rd_en   = 1;
        rd_addr = 6'd10;

       
        @(posedge clk);
        #1;

        @(negedge clk);

        wr_en = 0;
        rd_en = 1;
        rd_addr = 6'd10;

        @(posedge clk);
        #1;

        expected[10] = {16{16'hBEEF}};

        if (rd_valid && rd_data === expected[10]) begin
            $display("PASS: Updated tile read correctly");
        end
        else begin
            $display("FAIL: Updated tile read");
            errors = errors + 1;
        end

        @(negedge clk);
        rd_en = 0;

       

       

        if (errors == 0)
            $display("ALL WEIGHT BUFFER TESTS PASSED");
        else
            $display("TEST FAILED: %0d errors", errors);

       

        $finish;

    end

endmodule
