module ram (
	input wire clk,

	input wire [6:0] wx,
	input wire [9:0] wy,
    input wire [7:0] d,

	input wire [6:0] rx,
	input wire [9:0] ry,
	output reg [7:0] q,
	input wire we
);

	reg [7:0] mem [0:98303];
	
	initial begin;
		$readmemb("image.mem", mem);
	end
	
	always @(posedge clk) begin
		if(we) begin
			mem[{wy, wx}] <= d;
		end else begin
			q <= mem[{ry, rx}];
		end
	end

endmodule