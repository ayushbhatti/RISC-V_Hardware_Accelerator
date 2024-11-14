`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/08/2024 11:00:47 AM
// Design Name: 
// Module Name: mac
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module mac
(
	input [3:0] inputa,
	input [3:0] inputb,
	input clk, clken, reset,
	output reg [7:0] result
);
	reg  [7:0] inputa_reg, inputb_reg, old_result;
	reg  reset_reg;
	wire [7:0] multab;
	
	assign multab = inputa_reg * inputb_reg;
	
	always @ (posedge clk)
	begin
		if (clken)
		begin
			inputa_reg <= inputa;
			inputb_reg <= inputb;
			reset_reg <= reset;
			result <= old_result + multab;
		end
		if(reset_reg)
		  old_result <=0;
		else 
		  old_result <= result;
	end
	
endmodule
