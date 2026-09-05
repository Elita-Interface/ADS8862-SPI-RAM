`timescale 1ns / 1ns

module ADS8862_model_3W_CS
#(
    parameter real T_CONVST = 500ns
)
(
    input  logic CONVST,
    input  logic SCLK,
    input  logic DIN,
    output logic DOUT
);

    localparam real t_WH_CNV_MIN = 10ns;
    localparam real td_CNV_DO    = 12.3ns;

    logic [15:0] shift_reg;
    logic        conv_valid;
    logic        conv_done;
    real         convst_start_time;
    real         convst_pulse_width;

    initial begin
        DOUT       = 1'bz;
        conv_done  = 1'b0;
        conv_valid = 1'b0;
    end

    always @(posedge CONVST) begin
        convst_start_time = $realtime;
        DOUT       = 1'bz;
        conv_done  = 1'b0;
        conv_valid = 1'b0;
    end

    always @(negedge CONVST) begin
        convst_pulse_width = $realtime - convst_start_time;
        if (convst_pulse_width >= t_WH_CNV_MIN) begin
            automatic real time_remain = T_CONVST - convst_pulse_width;
            conv_valid = 1'b1;

            if (time_remain > 0) begin
                #time_remain;
            end

            #td_CNV_DO;

            shift_reg = $urandom_range(0, 65535);
            conv_done = 1'b1;
        end
        else begin
            DOUT       = 1'bz;
            conv_done  = 1'b0;
            conv_valid = 1'b0;
        end
    end

    always @(negedge SCLK) begin
        if (!CONVST && conv_done && conv_valid) begin
            DOUT      = shift_reg[15];
            shift_reg = {shift_reg[14:0], 1'b0};
        end
        else begin
            DOUT = 1'bz;
        end
    end

endmodule
