# ADS8862-SPI-RAM

A small RTL design and simulation verification project for ADS8862 ADC data acquisition and RAM buffering.

## Project Overview

This project implements an FPGA-side acquisition interface for the ADS8862 16-bit SAR ADC.

The design generates the required conversion and serial clock timing, receives 16-bit ADC data through the serial interface, and stores the sampled data into Block RAM.

SystemVerilog testbench and an ADS8862 behavioral model are used for functional simulation and timing analysis.

## Features

- ADS8862 conversion control
- SPI serial clock generation
- 16-bit serial ADC data acquisition
- Serial-to-parallel data conversion
- ADC data valid generation
- Block RAM data buffering
- Configurable conversion wait and sampling interval
- SystemVerilog Testbench
- ADS8862 behavioral model
- ModelSim and Vivado simulation verification

## Architecture

```text
        ADS8862 Model
             |
             | DOUT
             v
    +-------------------+
    | ADS8862 SPI Master|
    +---------+---------+
              |
              | 16-bit ADC Data
              v
       +-------------+
       | Block RAM   |
       +-------------+
