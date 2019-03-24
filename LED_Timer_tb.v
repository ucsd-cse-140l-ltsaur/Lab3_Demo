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

module LED_Timer_tb; 
  reg clk; 
  wire LED1, LED2, LED3, LED4, LED5; 
    
  LED_Timer U0 (
    .clk    (clk),
    .LED1   (LED1),
    .LED2   (LED2),
    .LED3   (LED3),
    .LED4   (LED4),
    .LED5   (LED5)
    );	
	
    
  initial begin
    clk = 0; 
  end 
    
  always  
    #83 clk = !clk; 
    
  initial  begin
    $dumpfile ("LED_Rotation.vcd"); 
    $dumpvars; 
  end 
    
  initial  begin
    $display("\t\ttime,\tclk,\tLED1,\tLED2,\tLED3,\tLED4,\tLED5"); 
    $monitor("%d,\t%b,\t%b,\t%b,\t%d",$time, clk,LED1,LED2,LED3, LED4, LED5); 
  end 
    
  initial 
  #1000000000 $finish; 
    
  //Rest of testbench code after this line 
    
endmodule
