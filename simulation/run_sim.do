# ModelSim / QuestaSim Simulation Script for t2a_spi
# Run from the simulation/ directory:
#   vsim -do run_sim.do          (GUI with waveforms)
#   vsim -c -do "do run_sim.do; quit -f"   (batch / CLI)

if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

vlog ../rtl/t2a_spi.v
vlog ../testbench/tb.v

vsim -voptargs="+acc" work.tb

# Add waveforms when running in GUI mode
if {![batch_mode]} {
    add wave -divider "Clock & Reset"
    add wave -bin /tb/clk_50MHz
    add wave -bin /tb/reset_n
    add wave -divider "Control & Status"
    add wave -bin /tb/start
    add wave -bin /tb/cs_out
    add wave -bin /tb/busy
    add wave -divider "SPI Bus"
    add wave -bin /tb/sclk_out
    add wave -bin /tb/expected_sclk
    add wave -bin /tb/mosi_output
    add wave -bin /tb/miso_input
    add wave -divider "Parallel Data"
    add wave -hex /tb/tx_data
    add wave -hex /tb/mosi_shadow_reg
    add wave -hex /tb/expected_rx_data
    add wave -hex /tb/rx_data
    add wave -divider "Internal FSM"
    add wave -bin /tb/uut/state
    add wave -bin /tb/uut/first_half
    add wave -unsigned /tb/uut/cycle_count
    add wave -unsigned /tb/uut/bit_count
}

# Run for 15 us (covers one full cycle of test vectors in tb.v;
# $stop is commented out in tb.v, so a bounded run duration is used).
run 15us

if {![batch_mode]} {
    wave zoom full
}
