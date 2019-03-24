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
    input  clk,
    output LED1,
    output LED2,
    output LED3,
    output LED4,
    output LED5
    );

	reg[15:0] div_cntr1;
	reg[7:0]  div_cntr2;
    reg[5:0]  sec_cntr;
    reg[5:0]  minute_cntr;
	reg[1:0]  dec_cntr;
	reg half_sec_pulse;
    reg sec_pulse;
    reg minute_pulse;
    reg hour_pulse;
	
	always@(posedge clk)
		begin
        div_cntr1 <= div_cntr1 + 1;
		if (div_cntr1 == 0) 
            begin
            div_cntr2 <= div_cntr2 + 1; //somewhat randomness:
                                        //div_cntr2 is unnitialized
			if (div_cntr2 == 91) 
				begin
				//div_cntr2 <= 0;
				half_sec_pulse <= 1;  
				end
			else if(div_cntr2 == (91*2)) 
				begin
				div_cntr2 <= 0;
				half_sec_pulse <= 1;  
                sec_pulse <= 1; 
				end
            end
		else
            begin
			half_sec_pulse <= 0;
            sec_pulse <= 0;
            end
		
		if (half_sec_pulse == 1)
			dec_cntr <= dec_cntr + 1;
			
		end	
		
        always@(posedge sec_pulse)
            begin
            sec_cntr <= sec_cntr + 1;
            if(sec_cntr >= 60)
                begin
                sec_cntr <= 0;
                minute_pulse <= 1;
                end
            else
                begin
                minute_pulse <= 0;
                end
            end

        always@(posedge minute_pulse)
            begin
            minute_cntr <= minute_cntr + 1;
            if(minute_cntr >= 60)
                begin
                minute_cntr <= 0;
                hour_pulse <= 1;
                end
            else
                hour_pulse <=0;
            end
		
	assign LED1 = (dec_cntr[0] == 1) ; //blink every 0.5 sec
	assign LED2 = (sec_cntr[0] == 1) ; //blink every 1 sec
	assign LED3 = (minute_cntr[0] == 1) ; //blink every 60 sec
	assign LED4 = (minute_pulse == 1) ;
    assign LED5 = (hour_pulse == 1);

 endmodule
