`timescale 1ns / 1ps

`default_nettype none

module top (
	input wire sys_clk,
	input wire sys_rst,

	input wire uart_rx,
	output wire [3:0] led,

	output wire vga_hsync,
	output wire vga_vsync,
	output wire [2:0] vga_red,
	output wire [2:0] vga_green,
	output wire [2:0] vga_blue
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

	wire idle, ready;
	wire [7:0] data;

	UART_RX #(
		.CLOCK_FREQUENCY(65_000_000),
		.BAUD_RATE(115200)
	) uart (
		.clockIN(clk65),
		.nRxResetIN(1),
		.rxIN(uart_rx),
		.rxIdleOUT(idle),
		.rxReadyOUT(ready),
		.rxDataOUT(data)
	);

	reg [6:0] wx;
    reg [9:0] wy;
    reg [7:0] d;
    wire [6:0] rx;
    wire [9:0] ry;
    wire [7:0] q;
    reg we;

    ram frame (
        .clk(clk65),
        .wx(wx),
        .wy(wy),
        .d(d),
        
        .rx(rx),
        .ry(ry),
        .q(q),
        .we(we)
    );

	reg writing = 0;
	reg prev = 0;
	assign led[0] = writing;

	always @(posedge clk65) begin
		prev <= ready;
		if(ready && !prev) begin // New input data
			if(writing) begin // If already in writing mode, write
				d <= data;
				we <= 1;

				// And then update pixel write address
				if(wx == 127) begin
					wx <= 0;
					if(wy == 767) begin
						wy <= 0;
						writing <= 0; // Leave writing mode when the entire frame is filled
					end else begin
						wy <= wy + 1;
					end
				end else begin
					wx <= wx + 1;
				end
			end else begin // If not in writing mode,
				if(data == 8'hAA) // Check if start byte
					writing <= 1; // Enter writing mode
			end
		end else we <= 0; // No input data, read
	end

	// XY Counter
	reg [10:0] px;
	reg [9:0] py;
	always @(posedge clk65) begin
		if(px >= (1024+24+136+160-1)) begin
			px <= 0;
			if(py >= (768+3+6+29-1)) begin
				py <= 0;
			end else begin
				py <= py + 1;
			end
		end else begin
			px <= px + 1;
		end
	end

	// VGA Output
	assign vga_hsync = ~(px >= (1024 + 24) && px < (1024 + 24 + 136));
	assign vga_vsync = ~(py >= (768 + 3) && py < (768 + 3 + 6));

	assign rx = px[10:3];
    assign ry = py;
	wire pixel = (q[7-px[2:0]] && (px < 1024 && py < 768));

	assign vga_red[0] = pixel;
	assign vga_green[0] = pixel;
	assign vga_blue[0] = pixel;

endmodule

`default_nettype wire