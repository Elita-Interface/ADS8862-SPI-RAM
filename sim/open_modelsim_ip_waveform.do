transcript on

# ============================================================
# 每次仿真重新建立 work 库，避免使用旧的编译结果
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
# 编译 RTL 与 Testbench
# ============================================================
vlog -sv ../rtl/ADS8862_model_3W_CS.sv
vlog -sv ../rtl/ads8862_spi_master.sv
vlog -sv ../rtl/adc_ram_top_ip.sv
vlog -sv tb_adc_ram_top_ip.sv


# ============================================================
# 启动 Testbench 仿真
# ============================================================
vsim -voptargs=+acc work.tb_adc_ram_top_ip


# ============================================================
# 添加主要波形信号
# ============================================================

# Testbench 基本控制信号
add wave -radix binary /tb_adc_ram_top_ip/clk
add wave -radix binary /tb_adc_ram_top_ip/rst_n
add wave -radix binary /tb_adc_ram_top_ip/run

# ADS8862 SPI 接口信号
add wave -radix binary /tb_adc_ram_top_ip/adc_convst
add wave -radix binary /tb_adc_ram_top_ip/adc_sclk

# 本次 Datasheet Review 后重点增加观察 DIN：
# 3-Wire CS 模式下 DIN 默认应保持高电平
add wave -radix binary /tb_adc_ram_top_ip/adc_din

add wave -radix binary /tb_adc_ram_top_ip/adc_dout

# SPI Master 接收结果
add wave -radix hex    /tb_adc_ram_top_ip/adc_data_dbg
add wave -radix binary /tb_adc_ram_top_ip/adc_data_valid_dbg

# Block RAM 写入/读取信号
add wave -radix binary   /tb_adc_ram_top_ip/ram_we
add wave -radix unsigned /tb_adc_ram_top_ip/ram_addr
add wave -radix hex      /tb_adc_ram_top_ip/ram_din
add wave -radix hex      /tb_adc_ram_top_ip/ram_dout

# Debug 与完成信号
add wave -radix unsigned /tb_adc_ram_top_ip/spi_state_dbg
add wave -radix binary   /tb_adc_ram_top_ip/done


# ============================================================
# GUI 波形观察时间
#
# 原始设计约 39.9 us 完成，因此原脚本运行 39850 ns。
#
# 修改后：
#   CONVST_HIGH_CYC: 4 -> 100
#   每次转换增加约 960 ns
#   16 次采样总时间增加约 15 us
#
# Vivado 回归中 done 约在 55 us 左右拉高。
# Testbench 在 done 后 200 ns 执行 $finish。
#
# 因此这里运行到约 55.15 us：
#   - 可以观察到 done = 1
#   - 又尽量停在 $finish 之前，便于 GUI 查看波形
# ============================================================
run 55.15 us

wave zoom full
