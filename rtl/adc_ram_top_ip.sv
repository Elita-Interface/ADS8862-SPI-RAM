`timescale 1ns / 1ps

module adc_ram_top_ip
#(
    parameter int DATA_NUM   = 16,
    parameter int ADDR_WIDTH = 4
)
(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  run,
    input  logic                  adc_dout,
    output logic                  adc_convst,
    output logic                  adc_sclk,
    output logic                  adc_din,
    output logic                  done,
    output logic                  ram_we,
    output logic [ADDR_WIDTH-1:0] ram_addr,
    output logic [15:0]           ram_din,
    output logic [15:0]           ram_dout,
    output logic [15:0]           adc_data_dbg,
    output logic                  adc_data_valid_dbg,
    output logic [2:0]            spi_state_dbg
);

    typedef enum logic [1:0] {
        TOP_IDLE,
        TOP_CAPTURE,
        TOP_READ,
        TOP_DONE
    } top_state_t;

    top_state_t state;

    logic                  spi_start;
    logic                  spi_busy;
    logic [15:0]           spi_data;
    logic                  spi_valid;
    logic [ADDR_WIDTH-1:0] wr_addr;
    logic [ADDR_WIDTH-1:0] rd_addr;
    logic [4:0]            spi_bit_cnt_dbg;

    assign adc_data_dbg       = spi_data;
    assign adc_data_valid_dbg = spi_valid;
    assign ram_din            = spi_data;

    ads8862_spi_master u_spi_master (
        .clk         (clk),
        .rst_n       (rst_n),
        .start       (spi_start),
        .adc_dout    (adc_dout),
        .adc_convst  (adc_convst),
        .adc_sclk    (adc_sclk),
        .adc_din     (adc_din),
        .data_out    (spi_data),
        .data_valid  (spi_valid),
        .busy        (spi_busy),
        .state_dbg   (spi_state_dbg),
        .bit_cnt_dbg (spi_bit_cnt_dbg)
    );

    blk_mem_gen_0 u_bram (
        .clka  (clk),
        .wea   ({ram_we}),
        .addra (ram_addr),
        .dina  (ram_din),
        .douta (ram_dout)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= TOP_IDLE;
            spi_start <= 1'b0;
            done      <= 1'b0;
            ram_we    <= 1'b0;
            ram_addr  <= '0;
            wr_addr   <= '0;
            rd_addr   <= '0;
        end
        else begin
            spi_start <= 1'b0;
            ram_we    <= 1'b0;

            case (state)
                TOP_IDLE: begin
                    done     <= 1'b0;
                    wr_addr  <= '0;
                    rd_addr  <= '0;
                    ram_addr <= '0;
                    if (run) begin
                        spi_start <= 1'b1;
                        state     <= TOP_CAPTURE;
                    end
                end

                TOP_CAPTURE: begin
                    if (spi_valid) begin
                        ram_we   <= 1'b1;
                        ram_addr <= wr_addr;

                        if (wr_addr == DATA_NUM - 1) begin
                            rd_addr <= '0;
                            state   <= TOP_READ;
                        end
                        else begin
                            wr_addr <= wr_addr + 1'b1;
                        end
                    end
                    else if (!spi_busy && !spi_start) begin
                        spi_start <= 1'b1;
                    end
                end

                TOP_READ: begin
                    ram_addr <= rd_addr;
                    if (rd_addr == DATA_NUM - 1) begin
                        state <= TOP_DONE;
                    end
                    else begin
                        rd_addr <= rd_addr + 1'b1;
                    end
                end

                TOP_DONE: begin
                    done <= 1'b1;
                    if (!run) begin
                        state <= TOP_IDLE;
                    end
                end

                default: begin
                    state <= TOP_IDLE;
                end
            endcase
        end
    end

endmodule
