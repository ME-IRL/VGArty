`default_nettype none

module cpu (
	input  wire        wb_clk_i,
	input  wire        wb_rst_i,
	
	output reg  [31:0] wb_adr_o,
	output reg  [31:0] wb_dat_o,
	output reg   [3:0] wb_sel_o,
	output reg         wb_we_o,
	output reg         wb_cyc_o,
	output reg         wb_stb_o,
	input  wire [31:0] wb_dat_i,
	input  wire        wb_ack_i,
	input  wire        wb_err_i,


    output wire [2:0] leds,

	input wire clk65,
	output wire vsync,
	output wire hsync,
    output wire pixel,

	input  wire [31:0] interrupts_i
);
    // reg [7:0] frame[0:98303];
    wire [6:0] wx;
    wire [9:0] wy;
    wire [7:0] d;
    wire [6:0] rx;
    wire [9:0] ry;
    wire [7:0] q;
    wire we;

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

	reg [10:0] px;
	reg [9:0] py;

    assign rx = px[10:3];
    assign ry = py;
    assign pixel = (q[7-px[2:0]] && (px < 1024 && py < 768));

    assign wx = addrx;
    assign wy = addry;
    assign d = read_data;

    // VGA Code
	initial begin
		px <= 0;
		py <= 0;
	end

    // Generate HSYNC and VSYNC
	assign hsync = ~(px >= (1024 + 24) && px < (1024 + 24 + 136));
	assign vsync = ~(py >= (768 + 3) && py < (768 + 3 + 6));
	
    // Pixel counter
	always @(posedge wb_clk_i) begin
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

    reg writing;
    initial writing <= 0;

    reg [6:0] addrx;
    reg [9:0] addry;

    assign leds[0] = writing;
    assign leds[1] = interrupts_i[0];

    localparam RESET = 0;
    localparam INIT1 = 1;
    localparam INIT2 = 2;
    localparam INIT3 = 3;
    localparam INIT4 = 4;
    localparam READY = 5;
    reg [2:0] uart_state = RESET;

    initial wb_sel_o <= 4'b1;
    initial wb_adr_o <= 32'b0;
    initial wb_dat_o <= 32'b0;
    initial wb_we_o <= 1'b0;

    initial wb_cyc_o <= 1'b0;
    initial wb_stb_o <= 1'b0;

    reg uart_reading = 0;
    reg [31:0] read_data = 32'b0;

    // reg select = 0;
    // wire [6:0] ax, bx;
    // wire [9:0] ay, by;
    // wire [7:0] qa, qb;
    // dpram frame (
    //     .data_a(read_data[7:0]),
    //     .data_b(read_data[7:0]),
    //     .addr_ax(ax),
    //     .addr_ay(ay),
    //     .addr_bx(bx),
    //     .addr_by(by),
    //     .we_a(writing && select),
    //     .we_b(writing && !select),
    //     .clk(wb_ack_i),
    //     .q_a(qa),
    //     .q_b(qb)
    // );

    // assign ax = 0;
    // assign ay = 0;
    // assign pixel = 0;

    // assign ax = select ? addrx : px[9:3];
    // assign ay = select ? addry : py;
    // assign pixel = select ? qb[px[2:0]] : qa[px[2:0]];

    // Main wishbone bus signals
    always @(posedge wb_clk_i) begin
        if((wb_rst_i) || ((wb_err_i)&&(wb_cyc_o))) begin // RESET
            wb_cyc_o <= 1'b0;
            wb_stb_o <= 1'b0;
        end else if(wb_stb_o) begin // BUS REQUEST
            if(wb_ack_i) begin
                wb_cyc_o <= 1'b0;
                wb_stb_o <= 1'b0;
                if(!wb_we_o)
                    read_data <= wb_dat_i;
            end
        end else if(wb_cyc_o) begin // BUS WAIT
        end else begin // IDLE
        end

        // Initialize UART core
        if(wb_rst_i) begin
            uart_state <= RESET;
        end else begin
            case(uart_state)
                RESET: begin
                    if(!wb_cyc_o) begin
                        wb_adr_o <= 32'd3; // Line Control Register
                        wb_dat_o <= 8'b1000_0011;
                        wb_we_o <= 1'b1;

                        wb_cyc_o <= 1'b1;
                        wb_stb_o <= 1'b1;
                        uart_state <= INIT1;
                    end
                end
                INIT1: begin
                    if(!wb_cyc_o) begin
                        wb_adr_o <= 32'd0; // Divisor Latch Byte 1 (LSB)
                        // wb_dat_o <= 8'b0011_0110; // For 100MHz
                        // wb_dat_o <= 8'd13; // For 25MHz
                        wb_dat_o <= 8'd35; // For 65MHz
                        wb_we_o <= 1'b1;

                        wb_cyc_o <= 1'b1;
                        wb_stb_o <= 1'b1;
                        uart_state <= INIT2;
                    end
                end
                INIT2: begin
                    if(!wb_cyc_o) begin
                        wb_adr_o <= 32'd3; // Line Control Register
                        wb_dat_o <= 8'b0000_0011;
                        wb_we_o <= 1'b1;

                        wb_cyc_o <= 1'b1;
                        wb_stb_o <= 1'b1;
                        uart_state <= INIT3;
                    end
                end
                INIT3: begin
                    if(!wb_cyc_o) begin
                        wb_adr_o <= 32'd2; // FIFO Control (W)
                        wb_dat_o <= 8'b0000_0000;
                        wb_we_o <= 1'b1;

                        wb_cyc_o <= 1'b1;
                        wb_stb_o <= 1'b1;
                        uart_state <= INIT4;
                    end
                end
                INIT4: begin
                    if(!wb_cyc_o) begin
                        wb_adr_o <= 32'd1; // Interrupt Enable
                        wb_dat_o <= 8'b0000_0001;
                        wb_we_o <= 1'b1;

                        wb_cyc_o <= 1'b1;
                        wb_stb_o <= 1'b1;
                        uart_state <= READY;
                    end
                end
                READY: begin
                    if(!wb_cyc_o) begin
                        wb_we_o <= 1'b0;
                    end
                end
                default: uart_state <= RESET;
            endcase
        end
        
        if(!wb_rst_i && uart_state == READY) begin
            // Data available
            if(interrupts_i[0]) begin
                // Send read
                if(!wb_cyc_o && !uart_reading) begin
                    wb_adr_o <= 32'd0;
                    wb_we_o <= 1'b0;

                    wb_cyc_o <= 1'b1;
                    wb_stb_o <= 1'b1;
                    uart_reading <= 1;
                end
            end
            // Wait for read
            if(!wb_cyc_o && uart_reading) begin
                uart_reading <= 0;
                if(!writing && (read_data[7:0] == 8'hAA)) begin
                    // we <= 1;
                    writing <= 1;
                    // addrx <= 0;
                    // addry <= 0;
                end else if (writing) begin
                    // we <= 1;
                    if(addrx == 127) begin
                        addrx <= 0;
                        if(addry == 767) begin
                            addry <= 0;
                            writing <= 0;
                            // we <= 0;
                        end else begin
                            addry <= addry + 1;
                        end
                    end else begin
                        addrx <= addrx + 1;
                    end
                end
            end
        end else begin
            // we <= 0;
            
            // writing <= 0;
            uart_reading <= 0;
            read_data <= 0;
        end
    end

    assign we = !wb_cyc_o && uart_reading;

endmodule

`default_nettype wire