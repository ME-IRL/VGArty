`timescale 1ns / 1ps

`default_nettype none

module top (
	input wire sys_clk,
	input wire sys_rst,

	input wire uart_rx,
	output wire uart_tx,
	output wire [7:0] debug,

	input wire [3:0] btn,
	output wire [3:0] led,

	output wire vga_hsync,
	output wire vga_vsync,
	output wire [2:0] vga_red,
	output wire [2:0] vga_green,
	output wire [2:0] vga_blue
);

	reg on;
	initial on <= 0;

	// Blinky as a test
	blinky #(
		.clk_freq_hz(100_000_000)
	) b (
		.clk(clk100),
		.q(led[0])
	);

	// Clock generator (see Xilinx UG768 [pg 357])
	wire clk100, clk65, clk2_unused, clk3_unused, clk4_unused, clk5_unused;
	wire clk_locked;

    wire sys_clk_buf;
	IBUF sysclk_buf(.I(sys_clk), .O(sys_clk_buf));
	
	wire clk_feedback, clk_feedback_bufd;
	BUFH feedback_buffer(.I(clk_feedback), .O(clk_feedback_bufd));
	
	PLLE2_BASE #(
		.BANDWIDTH("OPTIMIZED"), // OPTIMIZED, HIGH, LOW
		.CLKFBOUT_PHASE(0.0),   // Phase offset in degrees of CLKFB, (-360-360)
		.CLKIN1_PERIOD(10.0),   // Input clock period in ns resolution
		// CLKOUT0_DIVIDE - CLKOUT5_DIVIDE: divide amount for each CLKOUT(1-128)
		.CLKFBOUT_MULT(13),      // Multiply value for all CLKOUT (2-64)
		.CLKOUT0_DIVIDE(13),     // 100 MHz      (Clock for MIG)
		.CLKOUT1_DIVIDE(20),     // 65 MHz      (VGA Pixel Clock)
		.CLKOUT2_DIVIDE(16),    //  50 MHz      (Unused)
		.CLKOUT3_DIVIDE(32),    //  25 MHz      (Unused)
		.CLKOUT4_DIVIDE(8),     // 100 MHz      (Unused)
		.CLKOUT5_DIVIDE(8),     // 100 MHz      (Unused)
		// CLKOUT0_DUTY_CYCLE -- Duty cycle for each CLKOUT
		.CLKOUT0_DUTY_CYCLE(0.5),
		.CLKOUT1_DUTY_CYCLE(0.5),
		.CLKOUT2_DUTY_CYCLE(0.5),
		.CLKOUT3_DUTY_CYCLE(0.5),
		.CLKOUT4_DUTY_CYCLE(0.5),
		.CLKOUT5_DUTY_CYCLE(0.5),
		// CLKOUT0_PHASE -- phase offset for each CLKOUT
		.CLKOUT0_PHASE(0.0),
		.CLKOUT1_PHASE(0.0),
		.CLKOUT2_PHASE(0.0),
		.CLKOUT3_PHASE(0.0),
		.CLKOUT4_PHASE(0.0),
		.CLKOUT5_PHASE(0.0),
		.DIVCLK_DIVIDE(1),      // Master division value , (1-56)
		.STARTUP_WAIT("TRUE")   // Delay DONE until PLL Locks, ("TRUE"/"FALSE")
	) genclock(
		// Clock outputs: 1-bit (each) output
		.CLKOUT0(clk100),
		.CLKOUT1(clk65),
		.CLKOUT2(clk2_unused),
		.CLKOUT3(clk3_unused),
		.CLKOUT4(clk4_unused),
		.CLKOUT5(clk5_unused),
		.CLKFBOUT(clk_feedback), // 1-bit output, feedback clock
		.LOCKED(clk_locked),
		.CLKIN1(sys_clk_buf),
		.PWRDWN(1'b0),
		.RST(1'b0),
		.CLKFBIN(clk_feedback_bufd) // 1-bit input, feedback clock
	);

	wire wb_clk = clk65;
	reg wb_rst;
	initial wb_rst <= 1;
	always @(posedge wb_clk)
		wb_rst <= !(clk_locked && sys_rst);

	`include "wb_intercon.vh"

	assign wb_s2m_uart_err = 1'b0;
	assign wb_s2m_uart_rty = 1'b0;
	wire uart_int;
	
	uart_top uart (
		.wb_clk_i(wb_clk),
		.wb_rst_i(wb_rst),

		.wb_adr_i(wb_m2s_uart_adr),
		.wb_dat_i(wb_m2s_uart_dat),
		.wb_dat_o(wb_s2m_uart_dat),
		.wb_we_i (wb_m2s_uart_we),
		.wb_stb_i(wb_m2s_uart_stb),
		.wb_cyc_i(wb_m2s_uart_cyc),
		.wb_ack_o(wb_s2m_uart_ack),
		.wb_sel_i(wb_m2s_uart_sel),
		.int_o   (uart_int),

		// UART	signals
		.stx_pad_o(uart_tx),
		.srx_pad_i(uart_rx)
	);

	wire [31:0] interrupts;
	assign interrupts = {31'b0, uart_int};

	wire pixel;

	cpu core(
		.wb_clk_i(wb_clk),
		.wb_rst_i(wb_rst),

		.wb_adr_o(wb_m2s_cpu_adr),
		.wb_dat_o(wb_m2s_cpu_dat),
		.wb_sel_o(wb_m2s_cpu_sel),
		.wb_we_o (wb_m2s_cpu_we ),
		.wb_cyc_o(wb_m2s_cpu_cyc),
		.wb_stb_o(wb_m2s_cpu_stb),
		.wb_dat_i(wb_s2m_cpu_dat),
		.wb_ack_i(wb_s2m_cpu_ack),
		.wb_err_i(wb_s2m_cpu_err),
		
		.clk65(clk65),
		.hsync(vga_hsync),
		.vsync(vga_vsync),
		.pixel(pixel),

		.leds(led[3:1]),

		.interrupts_i(interrupts)
	);

	assign vga_red[0] = pixel;
	assign vga_green[0] = pixel;
	assign vga_blue[0] = pixel;

endmodule

`default_nettype wire