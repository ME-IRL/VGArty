`timescale 1ns / 1ns
`default_nettype none

module tb;
	
    reg clk = 0;
    // always #5 begin // 100MHz
    // always #10 begin // 50MHz
    always #8 begin // ~65MHz
        clk = ~clk;
    end

    reg uart_rx = 1;
    wire uart_tx;

    initial begin
        $display("Starting simulatrion");
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
        #30000000;
        $finish;
    end

    wire vga_hsync;
    wire vga_vsync;
    wire [2:0] vga_red;
    wire [2:0] vga_green;
    wire [2:0] vga_blue;

	vga myvga(
		.clk65(clk),
		.hsync(vga_hsync),
		.vsync(vga_vsync),
		.r(vga_red),
		.g(vga_green),
		.b(vga_blue)
	);

endmodule

`default_nettype wire