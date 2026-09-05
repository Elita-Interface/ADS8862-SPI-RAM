`timescale 1ns / 1ps

module ads8862_spi_master
#(
    parameter int CLK_FREQ_HZ       = 100_000_000,
    parameter int SCLK_FREQ_HZ      = 10_000_000,
    
     // ------------------------------------------------------------
    // ADS8862 CONVST 时序参数
    // ------------------------------------------------------------
    // 当前采用 3-Wire CS Mode Without Busy Indicator。
    //
    // Datasheet 中：
    //   tCONV(min) = 500 ns
    //   tCONV(max) = 930 ns
    //
    // 系统时钟为 100 MHz：
    //   1 个 clk 周期 = 10 ns
    //
    // 因此这里将 CONVST 保持高电平 100 个 clk：
    //   100 × 10 ns = 1000 ns
    //
    // 1000 ns > 930 ns，可以覆盖 ADC 最坏转换时间，
    // 并留出约 70 ns 的时序裕量。
    //
    // 原始设计为 4 个 clk，即约 40 ns。
    // 虽然满足 CONVST 最小高脉宽要求，但对于当前
    // 3-Wire CS Without Busy 工作流程，不能保证在转换
    // 结束时 CONVST 仍保持为高电平。
    parameter int CONVST_HIGH_CYC   = 100, //1000ns
    
    parameter int CONV_WAIT_CYC     = 60,
    parameter int SAMPLE_GAP_CYC = 20,
    
     // ADS8862 接口模式配置:
    // 在 3-Wire CS mode, DIN=1（CONVST 上升沿时）→ CS Mode
    // 使用参数（Parameter）来配置
    // 参数化方便后续配置接口.
    parameter bit ADC_DIN_LEVEL  = 1'b1 
)
(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic        adc_dout,
    output logic        adc_convst,
    output logic        adc_sclk,
    output logic        adc_din,
    output logic [15:0] data_out,
    output logic        data_valid,
    output logic        busy,
    output logic [2:0]  state_dbg,
    output logic [4:0]  bit_cnt_dbg
);

    localparam int SCLK_HALF_DIV = (CLK_FREQ_HZ / (SCLK_FREQ_HZ * 2));
    localparam int HALF_DIV      = (SCLK_HALF_DIV < 1) ? 1 : SCLK_HALF_DIV;

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_CONV_HIGH,
        ST_CONV_WAIT,
        ST_SHIFT,
        ST_DONE,
        ST_GAP
    } state_t;

    state_t      state;
    logic [15:0] shift_reg;
    int          delay_cnt;
    int          sclk_cnt;
    int          bit_cnt;

    // -----------------------------------------------------------------
    // DIN 引脚配置
    // -----------------------------------------------------------------
    // Original baseline:
    //     assign adc_din = 1'b0;
    //
    // Datasheet review:
    //     当前设计目标是 ADS8862 的 3线制 CS 模式。
    //     在该模式下，当 CONVST 信号上升沿到来时，DIN 必须为高电平。
    //
    // Improvement:
    //     将 DIN 的电平配置改为通过参数（Parameter）控制，而不是将其永久写死为某一个固定电平。
    //
    // Default:
    //     ADC_DIN_LEVEL = 1'b1 -> ADS8862 3-Wire CS mode
    //
    // Note:
    //     将此参数设置为 0 仅会改变 DIN 的电平状态。
    //     当前的状态机本身尚未实现完整的 ADS8862 菊花链（Daisy-chain）数据传输协议。
    // -----------------------------------------------------------------
    assign adc_din = ADC_DIN_LEVEL;

    assign busy        = (state != ST_IDLE);
    assign state_dbg   = state;
    assign bit_cnt_dbg = bit_cnt[4:0];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= ST_IDLE;
            adc_convst <= 1'b0;
            adc_sclk   <= 1'b0;
            data_out   <= 16'd0;
            data_valid <= 1'b0;
            shift_reg  <= 16'd0;
            delay_cnt  <= 0;
            sclk_cnt   <= 0;
            bit_cnt    <= 0;
        end
        else begin
            data_valid <= 1'b0;

            case (state)
                ST_IDLE: begin
                    adc_convst <= 1'b0;
                    adc_sclk   <= 1'b0;
                    shift_reg  <= 16'd0;
                    delay_cnt  <= 0;
                    sclk_cnt   <= 0;
                    bit_cnt    <= 0;
                    if (start) begin
                        adc_convst <= 1'b1;
                        state      <= ST_CONV_HIGH;
                    end
                end
                
                ST_CONV_HIGH: begin
                // ADS8862 转换阶段：
               // CONVST 上升沿已经在 ST_IDLE 中产生，用于启动一次 ADC 转换。
               //
               // 当前保持 CONVST 为高电平 CONVST_HIGH_CYC 个系统时钟。
               // 默认：
              //     CONVST_HIGH_CYC = 100
              //     clk = 100 MHz
              // 因此高电平持续时间约为：
              //     100 × 10 ns = 1000 ns
              //
             // 该时间大于 ADS8862 的最大转换时间 tCONV(max)=930 ns，
             // 用于保证 ADC 在最坏情况下也已经完成转换。
                    if (delay_cnt == CONVST_HIGH_CYC - 1) begin
                        adc_convst <= 1'b0;
                        delay_cnt  <= 0;
                        state      <= ST_CONV_WAIT;
                    end
                    else begin
                        delay_cnt <= delay_cnt + 1;
                    end
                end

                ST_CONV_WAIT: begin
                    if (delay_cnt == CONV_WAIT_CYC - 1) begin
                        delay_cnt <= 0;
                        sclk_cnt  <= 0;
                        bit_cnt   <= 0;
                        adc_sclk  <= 1'b1;
                        state     <= ST_SHIFT;
                    end
                    else begin
                        delay_cnt <= delay_cnt + 1;
                    end
                end

                ST_SHIFT: begin
                    if (sclk_cnt == HALF_DIV - 1) begin
                        sclk_cnt <= 0;
                        adc_sclk <= ~adc_sclk;

                        if (adc_sclk == 1'b0) begin
                            shift_reg <= {shift_reg[14:0], adc_dout};
                            bit_cnt   <= bit_cnt + 1;

                            if (bit_cnt == 15) begin
                                data_out <= {shift_reg[14:0], adc_dout};
                                state    <= ST_DONE;
                            end
                        end
                    end
                    else begin
                        sclk_cnt <= sclk_cnt + 1;
                    end
                end

                ST_DONE: begin
                    adc_sclk   <= 1'b0;
                    data_valid <= 1'b1;
                    delay_cnt  <= 0;
                    state      <= ST_GAP;
                end

                ST_GAP: begin
                    if (delay_cnt == SAMPLE_GAP_CYC - 1) begin
                        delay_cnt <= 0;
                        state     <= ST_IDLE;
                    end
                    else begin
                        delay_cnt <= delay_cnt + 1;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
