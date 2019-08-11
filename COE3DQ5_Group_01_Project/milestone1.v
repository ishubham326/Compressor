
`timescale 1ns/100ps
`default_nettype none

`include "define_state.h"
module milestone1 (
		/////// board clocks                      ////////////
		input logic clock,                   // 50 MHz clock
		input logic Resetn,
		input logic Enable,
// For SRAM
		output	logic [17:0] SRAM_address,
		output 	logic [15:0] SRAM_write_data,
		output	logic SRAM_we_n,
		input		logic [15:0] SRAM_read_data,
		output   logic M1_end
);
logic SRAM_ready;

//top_state_type top_state;
M1_state_type state;

//CODE ADDED//

//For addresses
logic [17:0] U_address; 
logic [17:0] V_address;
logic [17:0] Y_address;
logic [17:0] RGB_address;
//For storing U, V, Y values
logic [63:0] U_values; //8 values
logic [63:0] V_values; 
logic [31:0] Y_values; //4 values
logic [63:0] temp_U; //for shifting original U values
logic [63:0] temp_V; //for shifting original V values
logic [31:0] temp_prime; //to store temporary Prime odd values calculated
//For storing U', V', RGB values
logic [7:0] Uprime_values; //even
logic [7:0] Vprime_values; //even
logic [31:0] RGB_values; //Buffer to store calculated values before writing
logic [7:0] redo, rede, greeno, greene, blueo, bluee; //to store current calculated final values
logic [31:0] red_calc, green_calc, blue_calc; //calculated values using multipliers
logic [31:0] Uprime_odd; //odd calculated
logic [31:0] Vprime_odd; //odd calculated
//
logic FC_check; //First Cycle flag	
logic [7:0] some_counter; //column pixel counter
logic [7:0] pic_end; //row counter
//multipliers
logic [31:0] mult_op1, mult_op2, mult_op3, mult_op4, mult_op5, mult_op6, Mult_result1, Mult_result2, Mult_result3; //32 bit operands and final results used for calculations
logic [63:0] Mult_result1_long, Mult_result2_long, Mult_result3_long; //to perform calculations using 64 bits (to be concatenated later)


always_ff @(posedge clock or negedge Resetn) begin
	if (~Resetn) begin
		state <= S_M1_IDLE;
		SRAM_address <= 18'h00000;
		SRAM_write_data <= 16'h0000;
		SRAM_we_n <= 1'b1;
		U_address <= 18'd38400; 
		V_address <= 18'd57600;
		Y_address <= 18'h00000;
		RGB_address <= 18'd146944;
		U_values <= 64'b000000;
		V_values <= 64'b000000;
		Y_values <= 32'b00000;
		Uprime_values <= 16'b0000;
		Vprime_values <= 16'b0000;
		Uprime_odd <= 32'b00000;
		Vprime_odd <= 32'b00000;
		RGB_values <= 48'b000000;
		M1_end <= 1'b0;
		some_counter <= 8'b000;
		pic_end <= 8'b000;
		temp_U <= 64'b000000;
		temp_V <= 64'b000000;
		FC_check <= 1'b0;
		end 
		else begin
			case(state)
			S_M1_IDLE: begin
				if (Enable == 1 && pic_end != 240) begin
					// Start filling the SRAM
					//SRAM_address <= U_address;
					U_values <= 64'b000000;
					V_values <= 64'b000000;
					Y_values <= 32'b00000;
					SRAM_we_n <= 1'b1;
					Uprime_values <= 16'b0000;
					Vprime_values <= 16'b0000;
					Uprime_odd <= 32'b00000;
					Vprime_odd <= 32'b00000;
					RGB_values <= 48'b000000;
					some_counter <= 8'h000;
					temp_U <= 64'b000000;
					temp_V <= 64'b000000;
					SRAM_we_n <= 1;
					SRAM_address <= U_address; //ASSIGN SRAM ADDRESS TO READ U values
					U_address <= U_address + 1'h1; //increment address
					FC_check <= 1'b0;
					state <= LEAD_IN_0;		
				end
				else  if (pic_end >= 240) begin
					SRAM_we_n <= 1;
					M1_end <= 1'b1;	
				end
			end	
			LEAD_IN_0: begin //V values to be read
				SRAM_address <= V_address;
				V_address <= V_address + 1'h1;			
				state <= LEAD_IN_1;
			end
			
			LEAD_IN_1: begin //Y values to be read
				SRAM_address <= Y_address;
				Y_address <= Y_address + 1'h1;		
				state <= LEAD_IN_2;
			end
			
			LEAD_IN_2: begin //read U values again
				SRAM_address <= U_address;
				U_address <= U_address + 1'h1;		
				U_values[63:48] <= SRAM_read_data; //storing first read values
				state <= LEAD_IN_3;
			end
			
			LEAD_IN_3: begin //read V values again
				SRAM_address <= V_address;
				V_address <= V_address + 1'h1;
				V_values[63:48] <= SRAM_read_data; //storing first read
				state <= LEAD_IN_4;
			end
			
			LEAD_IN_4: begin
				Y_values[31:16] <= SRAM_read_data; //storing first read
				state <= LEAD_IN_5;
			end
			
			LEAD_IN_5:begin //storing second read
				U_values[47:32] <= SRAM_read_data;
				state <= COMM_CASE_1_0;			
			end
			//store values based on whether its first cycle
			COMM_CASE_1_0: begin
				if (FC_check == 0) begin 
					Uprime_values[7:0] <= U_values[63:56];
					Vprime_values[7:0] <= V_values[63:56];
					V_values[47:32] <= SRAM_read_data;
				end else begin
					Uprime_values[7:0] <= U_values[47:40];
					Vprime_values[7:0] <= V_values[47:40];
				end
				Uprime_odd[31:0] <= {{8{temp_prime[31]}},temp_prime[31:8]}; 
				SRAM_we_n <= 1;
				//SRAM_address assign
				if (some_counter >= 'd156)
					SRAM_address <= U_address;
				else begin
					SRAM_address <= U_address;
					U_address <= U_address + 1'h1;
				end
				state <= COMM_CASE_1_1;
			end
			//shifting values over
			COMM_CASE_1_1: begin
				Vprime_odd[31:0] <= {{8{temp_prime[31]}},temp_prime[31:8]};
				if (FC_check == 1) begin
					temp_U[63:8] <= U_values[55:0];
					temp_V[63:8] <= V_values[55:0];
				end						
				
				//SRAM_address assign
				if (some_counter >= 'd156)
					SRAM_address <= V_address;
				else begin
					SRAM_address <= V_address;
					V_address <= V_address + 1'h1;
				end
				state <= COMM_CASE_1_2;
			end
			//shifting values over
			COMM_CASE_1_2: begin
				if (FC_check == 1) begin
					U_values[63:0] <= temp_U[63:0];
					V_values[63:0] <= temp_V[63:0];
				end
				RGB_values[31:24] <= rede; //red	even	
				RGB_values[23:16] <= bluee; //blue even
				
				//SRAM_address assign
				if (some_counter >= 159)
					SRAM_address <= Y_address;
				else begin
					SRAM_address <= Y_address;	
					Y_address <= Y_address + 1'h1;
				end
				state <= COMM_CASE_1_3;				
			end
			//STARTING TO WRITE RGB data
			COMM_CASE_1_3: begin				
				if (FC_check == 0)
					U_values[31:16] <= SRAM_read_data;
				else
					U_values[23:8] <= SRAM_read_data;
				//RGB_values[39:32] <= greene; //green even
				//SRAM_address assign
				SRAM_address <= RGB_address;
				RGB_address <= RGB_address + 1'h1;	
				//some_counter <= some_counter + 1;
				SRAM_we_n <= 0;
				SRAM_write_data <= {{RGB_values[31:24]}, {greene[7:0]}}; //red and green
				state <= COMM_CASE_1_4;
			end
			
			COMM_CASE_1_4: begin
				if (FC_check == 0)
					V_values[31:16] <= SRAM_read_data;
				else
					V_values[23:8] <= SRAM_read_data;
					
				RGB_values[15:8] <= redo; //red	odd
				RGB_values[7:0] <= blueo; //blue	odd
				
				//SRAM_address assign
				SRAM_address <= RGB_address;
				RGB_address <= RGB_address + 1'h1;
				SRAM_write_data <= {{RGB_values[23:16]}, {redo[7:0]}};
				some_counter <= some_counter + 1;
				
				state <= COMM_CASE_1_5;	
			end
		
			COMM_CASE_1_5: begin
				//RGB_values[15:8] <= greeno; //green odd
				Y_values[15:0] <= SRAM_read_data;
				
				//SRAM_address assign
				SRAM_write_data <= {{greeno[7:0]}, {RGB_values[7:0]}};
				SRAM_address <= RGB_address;
				RGB_address <= RGB_address + 1'h1;
				//SRAM_we_n <= 1;
				if(some_counter == 159) //check for how many we have
					state <= LEAD_OUT_0;	
				else
					state <= COMM_CASE_2_0;
			end
			
			COMM_CASE_2_0: begin
				if (FC_check == 0) begin
					Uprime_values[7:0] <= U_values[55:48];
					Vprime_values[7:0] <= V_values[55:48];
				end else begin
					Uprime_values[7:0] <= U_values[47:40];
					Vprime_values[7:0] <= V_values[47:40];
				end
				Uprime_odd[31:0] <= {{8{temp_prime[31]}},temp_prime[31:8]};
				SRAM_we_n <= 1;
				//SRAM_address assign
				SRAM_address <= Y_address;
				Y_address <= Y_address + 1'h1;
				state <= COMM_CASE_2_1;
			end
			
			COMM_CASE_2_1: begin
				Vprime_odd[31:0] <= {{8{temp_prime[31]}},temp_prime[31:8]}; 
				state <= COMM_CASE_2_2;
			end
			
			COMM_CASE_2_2: begin
				if (FC_check == 1) begin
					temp_U[63:8] <= U_values[55:0];
					temp_V[63:8] <= V_values[55:0];
				end	
				RGB_values[31:24] <= rede; //red	even	
				RGB_values[23:16] <= bluee; //blue even
				state <= COMM_CASE_2_3;
			end
			
			COMM_CASE_2_3: begin
				if (FC_check == 1) begin
					U_values[63:0] <= temp_U[63:0];
					V_values[63:0] <= temp_V[63:0];
				end	
				//RGB_values[39:32] <= greene; //green
				Y_values[31:16] <= SRAM_read_data;
				//SRAM_address assign
				SRAM_address <= RGB_address;
				SRAM_we_n <= 0;
				SRAM_write_data <= {{RGB_values[31:24]}, {greene[7:0]}}; //red and green
				RGB_address <= RGB_address + 1'h1;	
				state <= COMM_CASE_2_4;
			end
			
			COMM_CASE_2_4: begin
				RGB_values[15:8] <= redo; //red	odd
				RGB_values[7:0] <= blueo; //blue	odd
				some_counter <= some_counter + 1;
				//SRAM_address assign
				SRAM_address <= RGB_address;
				RGB_address <= RGB_address + 1'h1;	
				SRAM_write_data <= {{RGB_values[23:16]}, {redo[7:0]}};
				FC_check <= 1;
				state <= COMM_CASE_2_5;
			end
			
			COMM_CASE_2_5: begin
				//RGB_values[15:8] <= greeno;
				//SRAM_address assign
				SRAM_address <= RGB_address;
				RGB_address <= RGB_address + 1'h1;	
				SRAM_write_data <= {{greeno[7:0]}, {RGB_values[7:0]}};
				//SRAM_we_n <= 1;
				if(some_counter == 159) begin
					state <= LEAD_OUT_0;	
				end
				else
					state <= COMM_CASE_1_0;
				//state <= COMM_CASE_1_0;		
			end
		
			LEAD_OUT_0: begin
				SRAM_we_n <= 1;
				Uprime_values[7:0] <= U_values[47:40];
				Vprime_values[7:0] <= V_values[47:40];		
				Uprime_odd[31:0] <= {{8{temp_prime[31]}},temp_prime[31:8]};
				state <= LEAD_OUT_1;
			end
			
			LEAD_OUT_1: begin
				Vprime_odd[31:0] <= {{8{temp_prime[31]}},temp_prime[31:8]};
				state <= LEAD_OUT_2;
			end
			
			LEAD_OUT_2: begin
				RGB_values[31:24] <= rede; //red		
				RGB_values[23:16] <= bluee; //blue	
				state <= LEAD_OUT_3;
			end
		
			LEAD_OUT_3: begin
				//RGB_values[39:32] <= greene; //green
				//SRAM_address assign
				SRAM_address <= RGB_address;
				SRAM_write_data <= {{RGB_values[31:24]}, {greene[7:0]}}; //red and green
				SRAM_we_n <= 0;
				RGB_address <= RGB_address + 1;
				state <= LEAD_OUT_4;
				
			end
				
			LEAD_OUT_4: begin
				RGB_values[15:8] <= redo; //red		
				RGB_values[7:0] <= blueo; //blue	
				FC_check <= 0;
				//SRAM_address assign
				SRAM_address <= RGB_address;
				SRAM_write_data <= {{RGB_values[23:16]}, {redo[7:0]}};	
				RGB_address <= RGB_address + 1;
				state <= LEAD_OUT_5;
				
			end
			
			LEAD_OUT_5: begin
				//RGB_values[15:8] <= greeno; //green1
				//SRAM_address assign
				SRAM_address <= RGB_address;
				SRAM_write_data <= {{greeno[7:0]}, {RGB_values[7:0]}};
				RGB_address <= RGB_address + 1'h1;
				//SRAM_we_n <= 1;
				pic_end <= pic_end + 1;
				//if (pic_end == 240)
					//M1_end <= 1'b1;
				//else
				state <= S_M1_IDLE;
			end
			default: state <= S_M1_IDLE;
			endcase			
				
end
end
//Used to assign multiplication operands based on which state we are in
always_comb begin
	mult_op1 = 0;
	mult_op2 = 0;
	mult_op3 = 0;
	mult_op4 = 0;
	mult_op5 = 0;
	mult_op6 = 0;
	case(state)
	COMM_CASE_1_0: begin
	if (FC_check == 0) begin
		mult_op1 = 32'd21;
		mult_op2 = U_values[63:56] + U_values[39:32];
	
		mult_op3 = -32'd52; 
		mult_op4 = U_values[63:56] + U_values[47:40];
	
		mult_op5 = 32'd159;
		mult_op6 = U_values[63:56] + U_values[55:48];
	end
	else if (some_counter == 158) begin
		mult_op1 = 32'd21;
		mult_op2 = U_values[63:56] + U_values[39:32];
	
		mult_op3 = -32'd52; 
		mult_op4 = U_values[55:48] + U_values[39:32];
	
		mult_op5 = 32'd159;
		mult_op6 = U_values[47:40] + U_values[39:32];
	end
	else begin
		mult_op1 = 32'd21;
		mult_op2 = U_values[63:56] + U_values[23:16];
	
		mult_op3 = -32'd52; 
		mult_op4 = U_values[55:48] + U_values[31:24];
	
		mult_op5 = 32'd159;
		mult_op6 = U_values[47:40] + U_values[39:32];
	end
	end
	
	COMM_CASE_1_1: begin
	if (FC_check == 0) begin
		mult_op1 = 32'd21;
		mult_op2 = V_values[63:56] + V_values[39:32];
	
		mult_op3 = -32'd52; 
		mult_op4 = V_values[63:56] + V_values[47:40];
	
		mult_op5 = 32'd159;
		mult_op6 = V_values[63:56] + V_values[55:48];
	end 
	else if (some_counter == 158) begin
		mult_op1 = 32'd21;
		mult_op2 = V_values[63:56] + V_values[39:32];
	
		mult_op3 = -32'd52; 
		mult_op4 = V_values[55:48] + V_values[39:32];
	
		mult_op5 = 32'd159;
		mult_op6 = V_values[47:40] + V_values[39:32];
	end
	else begin	
		mult_op1 = 32'd21;
		mult_op2 = V_values[63:56] + V_values[23:16];
		
		mult_op3 = -32'd52; 
		mult_op4 = V_values[55:48] + V_values[31:24];
		
		mult_op5 = 32'd159;
		mult_op6 = V_values[47:40] + V_values[39:32];
	end
	end
	
	COMM_CASE_1_2: begin
		mult_op1 = Y_values[31:24] + (-32'd16);
		mult_op2 = 32'd76284;
		
		mult_op3 = Vprime_values[7:0] + (-32'd128);
		mult_op4 = 32'd104595;
		
		mult_op5 = Uprime_values[7:0] + (-32'd128);
		mult_op6 = 32'd132251;
	end

	COMM_CASE_1_3: begin
		mult_op1 = Y_values[31:24] + (-32'd16);
		mult_op2 = 32'd76284;
		
		mult_op3 = Vprime_values[7:0] + (-32'd128);
		mult_op4 = -32'd53281;
		
		mult_op5 = Uprime_values[7:0] + (-32'd128);
		mult_op6 = -32'd25624;
	end
	
	COMM_CASE_1_4: begin
		mult_op1 = Y_values[23:16] + (-32'd16);
		mult_op2 = 32'd76284;
		
		mult_op3 = Vprime_odd[31:0] + (-32'd128);
		mult_op4 = 32'd104595;
		
		mult_op5 = Uprime_odd[31:0] + (-32'd128);
		mult_op6 = 32'd132251;
	end
	
	COMM_CASE_1_5: begin
		mult_op1 = Y_values[23:16] + (-32'd16);
		mult_op2 = 32'd76284;
		
		mult_op3 = Vprime_odd[31:0] + (-32'd128);
		mult_op4 = -32'd53281;
		
		mult_op5 = Uprime_odd[31:0] + (-32'd128);
		mult_op6 = -32'd25624;
	end
		
	COMM_CASE_2_0: begin
	if (FC_check == 0) begin
		mult_op1 = 32'd21;
		mult_op2 = U_values[63:56] + U_values[31:24];
	
		mult_op3 = -32'd52; 
		mult_op4 = U_values[63:56] + U_values[39:32];
	
		mult_op5 = 32'd159;
		mult_op6 = U_values[55:48] + U_values[47:40];
	end 
	else if (some_counter == 157) begin
		mult_op1 = 32'd21;
		mult_op2 = U_values[63:56] + U_values[31:24];
	
		mult_op3 = -32'd52; 
		mult_op4 = U_values[55:48] + U_values[31:24];
	
		mult_op5 = 32'd159;
		mult_op6 = U_values[47:40] + U_values[39:32];
	end else begin	
		mult_op1 = 32'd21;
		mult_op2 = U_values[63:56] + U_values[23:16];
	
		mult_op3 = -32'd52; 
		mult_op4 = U_values[55:48] + U_values[31:24];
	
		mult_op5 = 32'd159;
		mult_op6 = U_values[47:40] + U_values[39:32];
	end
	end
	
	COMM_CASE_2_1: begin
	if (FC_check == 0) begin
		mult_op1 = 32'd21;
		mult_op2 = V_values[63:56] + V_values[31:24];
	
		mult_op3 = -32'd52; 
		mult_op4 = V_values[63:56] + V_values[39:32];
	
		mult_op5 = 32'd159;
		mult_op6 = V_values[55:48] + V_values[47:40];
		
	end else if (some_counter == 157) begin
		mult_op1 = 32'd21;
		mult_op2 = V_values[63:56] + V_values[31:24];
	
		mult_op3 = -32'd52; 
		mult_op4 = V_values[55:48] + V_values[31:24];
	
		mult_op5 = 32'd159;
		mult_op6 = V_values[47:40] + V_values[39:32];
		
	end else begin	
		mult_op1 = 32'd21;
		mult_op2 = V_values[63:56] + V_values[23:16];
		
		mult_op3 = -32'd52; 
		mult_op4 = V_values[55:48] + V_values[31:24];
		
		mult_op5 = 32'd159;
		mult_op6 = V_values[47:40] + V_values[39:32];
	end
	end
	
	COMM_CASE_2_2: begin
		mult_op1 = Y_values[15:8] + (-32'd16);
		mult_op2 = 32'd76284;
		
		mult_op3 = Vprime_values[7:0] + (-32'd128);
		mult_op4 = 32'd104595;
		
		mult_op5 = Uprime_values[7:0] + (-32'd128);
		mult_op6 = 32'd132251;
	end

	COMM_CASE_2_3: begin
		mult_op1 = Y_values[15:8] + (-32'd16);
		mult_op2 = 32'd76284;
		
		mult_op3 = Vprime_values[7:0] + (-32'd128);
		mult_op4 = -32'd53281;
		
		mult_op5 = Uprime_values[7:0] + (-32'd128);
		mult_op6 = -32'd25624;
	end
	
	COMM_CASE_2_4: begin
		mult_op1 = Y_values[7:0] + (-32'd16);
		mult_op2 = 32'd76284;
		
		mult_op3 = Vprime_odd[31:0] + (-32'd128);
		mult_op4 = 32'd104595;
		
		mult_op5 = Uprime_odd[31:0] + (-32'd128);
		mult_op6 = 32'd132251;
	end
	
	COMM_CASE_2_5: begin
		mult_op1 = Y_values[7:0] + (-32'd16);
		mult_op2 = 32'd76284;
		
		mult_op3 = Vprime_odd[31:0] + (-32'd128);
		mult_op4 = -32'd53281;
		
		mult_op5 = Uprime_odd[31:0] + (-32'd128);
		mult_op6 = -32'd25624;
	end
	
	
	LEAD_OUT_0: begin
		mult_op1 = 32'd21;
		mult_op2 = U_values[63:56] + U_values[47:40];
		
		mult_op3 = -32'd52; 
		mult_op4 = U_values[55:48] + U_values[47:40];
		
		mult_op5 = 32'd159;
		mult_op6 = U_values[47:40] + U_values[47:40];
	end
	
	LEAD_OUT_1: begin
		mult_op1 = 32'd21;
		mult_op2 = V_values[63:56] + V_values[47:40];
		
		mult_op3 = -32'd52; 
		mult_op4 = V_values[55:48] + V_values[47:40];
		
		mult_op5 = 32'd159;
		mult_op6 = V_values[47:40] + V_values[47:40];
	end
	
	LEAD_OUT_2: begin
		mult_op1 = Y_values[15:8] + (-32'd16);
		mult_op2 = 32'd76284;
		
		mult_op3 = Vprime_values[7:0] + (-32'd128);
		mult_op4 = 32'd104595;
		
		mult_op5 = Uprime_values[7:0] + (-32'd128);
		mult_op6 = 32'd132251;
	end

	LEAD_OUT_3: begin
		mult_op1 = Y_values[15:8] + (-32'd16);
		mult_op2 = 32'd76284;
		
		mult_op3 = Vprime_values[7:0] + (-32'd128);
		mult_op4 = -32'd53281;
		
		mult_op5 = Uprime_values[7:0] + (-32'd128);
		mult_op6 = -32'd25624;
	end
	
	LEAD_OUT_4: begin
		mult_op1 = Y_values[7:0] + (-32'd16);
		mult_op2 = 32'd76284;
		
		mult_op3 = Vprime_odd[31:0] + (-32'd128);
		mult_op4 = 32'd104595;
		
		mult_op5 = Uprime_odd[31:0] + (-32'd128);
		mult_op6 = 32'd132251;
	end
	
	LEAD_OUT_5: begin
		mult_op1 = Y_values[7:0] + (-32'd16);
		mult_op2 = 32'd76284;
		
		mult_op3 = Vprime_odd[31:0] + (-32'd128);
		mult_op4 = -32'd53281;
		
		mult_op5 = Uprime_odd[31:0] + (-32'd128);
		mult_op6 = -32'd25624;
	end
	endcase
	
end
//doing multiplication using specific operands
assign Mult_result1_long = mult_op1* mult_op2;
assign Mult_result2_long = mult_op3* mult_op4;
assign Mult_result3_long = mult_op5* mult_op6;
//storing result in 32 bits
assign Mult_result1 = Mult_result1_long[31:0];
assign Mult_result2 = Mult_result2_long[31:0];
assign Mult_result3 = Mult_result3_long[31:0];
//odd prime value calculation
assign temp_prime[31:0] = Mult_result1 + Mult_result2 + Mult_result3 + 32'd128;
 
//performing final RGB calculations before writing them and storing them
always_comb begin
	red_calc = Mult_result1 + Mult_result2;
	green_calc = Mult_result1 + Mult_result2 + Mult_result3;
	blue_calc = Mult_result1 + Mult_result3;
	
	if(red_calc[31] == 1) begin
		redo = 8'd0;
		rede = 8'd0;
	end else 
	if(red_calc[30:24] > 0) begin
			redo = 8'd255;
			rede = 8'd255;
	end else begin
		redo = red_calc[23:16];
		rede = red_calc[23:16];
	end
	
	if(green_calc[31] == 1) begin
		greeno = 8'd0;
		greene = 8'd0;
	end else 
	if(green_calc[30:24] > 0) begin
			greeno = 8'd255;
			greene = 8'd255;
	end else begin
		greeno = green_calc[23:16];
		greene = green_calc[23:16];
	end
	
	if(blue_calc[31] == 1) begin
		blueo = 8'd0;
		bluee = 8'd0;
	end else 
	if(blue_calc[30:24] > 0) begin
			blueo = 8'd255;
			bluee = 8'd255;
	end else begin
		blueo = blue_calc[23:16];
		bluee = blue_calc[23:16];
	end
	
end

`ifdef SIMULATION
	logic[63:0] U;
	logic[31:0] Y;
	logic[63:0] V;
	assign U = U_values;
	assign V = V_values;
	assign Y = Y_values;
`endif	
endmodule
//CODE ADDED//
















