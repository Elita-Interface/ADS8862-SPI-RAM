transcript on

# ============================================================
# 每次运行前重新建立 work 库，
# 避免继续使用之前编译的旧版本 RTL。
# ============================================================
if {[file exists work]} {
    vdel -lib work -all
}
vlib work


# ============================================================
# 编译 Xilinx Block Memory Generator 仿真模型
# ============================================================
vlog -sv ../ip/blk_mem_gen_0/simulation/blk_mem_gen_v8_4.v
vlog -sv ../ip/blk_mem_gen_0/sim/blk_mem_gen_0.v


# ============================================================
# 编译 ADS8862 行为模型、RTL 和 Testbench
# ============================================================
vlog -sv ../rtl/ADS8862_model_3W_CS.sv
vlog -sv ../rtl/ads8862_spi_master.sv
vlog -sv ../rtl/adc_ram_top_ip.sv
vlog -sv tb_adc_ram_top_ip.sv


# ============================================================
# 启动顶层 Testbench
# ============================================================
vsim -voptargs=+acc work.tb_adc_ram_top_ip


# ============================================================
# 添加主要观察信号
# ============================================================

# Testbench 基本控制
add wave -radix binary /tb_adc_ram_top_ip/clk
add wave -radix binary /tb_adc_ram_top_ip/rst_n
add wave -radix binary /tb_adc_ram_top_ip/run

# ADS8862 SPI 接口
add wave -radix binary /tb_adc_ram_top_ip/adc_convst
add wave -radix binary /tb_adc_ram_top_ip/adc_sclk

# 本次 Datasheet Review 后新增：
# 3-Wire CS 模式下 DIN 默认应保持高电平
add wave -radix binary /tb_adc_ram_top_ip/adc_din

add wave -radix binary /tb_adc_ram_top_ip/adc_dout

# SPI Master 接收结果
add wave -radix hex    /tb_adc_ram_top_ip/adc_data_dbg
add wave -radix binary /tb_adc_ram_top_ip/adc_data_valid_dbg

# Block RAM 读写
add wave -radix binary   /tb_adc_ram_top_ip/ram_we
add wave -radix unsigned /tb_adc_ram_top_ip/ram_addr
add wave -radix hex      /tb_adc_ram_top_ip/ram_din
add wave -radix hex      /tb_adc_ram_top_ip/ram_dout

# 调试和结束状态
add wave -radix unsigned /tb_adc_ram_top_ip/spi_state_dbg
add wave -radix binary   /tb_adc_ram_top_ip/done


# ============================================================
# 完整回归仿真
#
# 原脚本使用：
#     run 50 us
#
# 修改 CONVST 时序后，整个测试时间已经超过 50 us。
# Testbench 本身包含 $finish，因此这里使用 run -all，
# 让仿真一直运行到 testbench 正常结束。
# ============================================================
run -all

wave zoom full
