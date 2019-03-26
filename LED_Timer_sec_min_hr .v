// --------------------------------------------------------------------
// >>>>>>>>>>>>>>>>>>>>>>>>> COPYRIGHT NOTICE <<<<<<<<<<<<<<<<<<<<<<<<<
// --------------------------------------------------------------------
// Copyright (c) 2019 by UCSD CSE 140L
// --------------------------------------------------------------------
//
// Permission:
//
//   This code for use in UCSD CSE 140L.
//   It is synthesisable for Lattice iCEstick 40HX.  
//
// Disclaimer:
//
//   This Verilog source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  
//
// --------------------------------------------------------------------
//           
//                     Lih-Feng Tsaur
//                     UCSD CSE Department
//                     9500 Gilman Dr, La Jolla, CA 92093
//                     U.S.A
//
// --------------------------------------------------------------------
//
// Revision History : 0.0

module LED_Timer(
input  wire i_rst,       //reset
input  wire i_clk,       //system clk 12MHz 
output wire o_sec_tick,  //0.5sec 1 and 0.5sec 0
output wire o_min_tick,  //30 sec 1 and 30 sec 0
output wire o_hr_tick,   //30 min 1 and 30 min 0
output wire [7:0] o_LED  //output to wrapper's LEDs
);

reg[15:0] div_cntr1;    //0~4'hB71A  or 48E5~FFFF 
reg[7:0]  div_cntr2;    //0~2'h7F (0.5sec) 80-FF (0.5sec)
reg[5:0]  sec_cntr;     //0~2'd59
reg[5:0]  minute_cntr;  //0~2'd59
wire sec_pulse_wire;
reg  minute_pulse_reg;
wire minute_pulse_wire;
reg  hour_pulse_reg;
wire hour_pulse_wire;

always@(posedge i_clk) begin
	if (i_rst) begin
	    div_cntr1[15:0] <= 4'h48E5;
        div_cntr2[7:0]  <= 2'h00;
	end 
	else begin
	    //react to 6M i_clk cycles (every 0.5sec)
	    //every 0.5 sec, there are 12,000,000/2 = 6,000,000 cycles
		// 6M = 46785 (cntr1 = 4'hB71B-1) x 128 (cntr2 = 2'h80) 
        div_cntr1[15:0] <= div_cntr1[15:0] + 1'b1;
		if (&div_cntr1) begin
			div_cntr1[15:0] <= 4'h48E5;			
            div_cntr2[7:0] <= div_cntr2[7:0] + 1'b1; 
        end					
	end	
end
	
assign sec_pulse_wire = div_cntr2[7]; //0.5sec 0n and 0.5sec off
assign o_sec_tick = sec_pulse_wire;

wire [5:0] sec_cntr_wire;
assign sec_cntr_wire [5:0] = {sec_cntr [5:0]};

wire [5:0] test_59_sec;
assign test_59_sec = {sec_cntr_wire[5] ^ 1'b0, sec_cntr_wire[4] ^ 1'b0, sec_cntr_wire[3] ^ 1'b0,
                      sec_cntr_wire[2] ^ 1'b1, sec_cntr_wire[1] ^ 1'b0, sec_cntr_wire[0] ^ 1'b0}; //0x3B

wire [5:0] test_29_sec;
assign test_29_sec = {sec_cntr_wire[5] ^ 1'b1, sec_cntr_wire[4] ^ 1'b0, sec_cntr_wire[3] ^ 1'b0,
                      sec_cntr_wire[2] ^ 1'b0, sec_cntr_wire[1] ^ 1'b1, sec_cntr_wire[0] ^ 1'b0}; //0x1D
					
wire is_59_sec = (&test_59_sec);
wire is_29_sec = (&test_29_sec);

always@(posedge sec_pulse_wire or posedge i_rst) begin
	if (i_rst) begin
        sec_cntr[5:0] <= 6'b000000;
		minute_pulse_reg <= 0;
	end 
	else begin
        sec_cntr[5:0] <= sec_cntr[5:0] + 1'b1;
		
        if(is_59_sec) begin
            sec_cntr[5:0] <= 6'b000000;
            minute_pulse_reg <= 1'b0;
        end 
		else if (is_29_sec) begin
            minute_pulse_reg <= 1'b1;
        end
		
    end
end

wire minute_pulse_wire = minute_pulse_reg;
assign o_min_tick = minute_pulse_wire;

wire [5:0] minute_cntr_wire;
assign minute_cntr_wire[5:0] = minute_cntr[5:0];
wire test_59_min = {minute_cntr_wire[5] ^ 1'b0, minute_cntr_wire[4] ^ 1'b0, minute_cntr_wire[3] ^ 1'b0,
                    minute_cntr_wire[2] ^ 1'b1, minute_cntr_wire[1] ^ 1'b0, minute_cntr_wire[0] ^ 1'b0}; //0x3B
wire test_29_min = {minute_cntr_wire[5] ^ 1'b1, minute_cntr_wire[4] ^ 1'b0, minute_cntr_wire[3] ^ 1'b0,
                    minute_cntr_wire[2] ^ 1'b0, minute_cntr_wire[1] ^ 1'b1, minute_cntr_wire[0] ^ 1'b0}; //0x1D
wire is_59_min = &test_59_min;
wire is_29_min = &test_29_min;
	
always@(posedge minute_pulse_wire or posedge i_rst) begin
	if (i_rst) begin
	    minute_cntr[5:0] <= 5'b00000;
		hour_pulse_reg <= 0;
	end
	else begin
        minute_cntr[5:0] <= minute_cntr[5:0] + 1'b1;
        if(is_59_min) begin
            minute_cntr[5:0] <= 5'b00000;
            hour_pulse_reg <= 1'b0;
        end
        else if(is_29_min) begin
            hour_pulse_reg <= 1'b1;
        end
	end
end	

assign hour_pulse_wire = hour_pulse_reg;
assign o_hr_tick = hour_pulse_wire;

assign o_LED[0] = sec_pulse_wire;                      //blink every 0.5 sec
assign o_LED[1] = sec_cntr_wire[0];                    //blink every 1 sec
assign o_LED[2] = sec_cntr_wire[1];                    //blink every 2 sec
assign o_LED[3] = minute_pulse_wire & ~sec_pulse_wire; //blink every 30 sec
assign o_LED[4] = hour_pulse_wire & ~sec_pulse_wire;   //blink every 30 minutes

endmodule
