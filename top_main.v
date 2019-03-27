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

// UART of Lattice iCEstick

module uart (
         
         input wire   clk_in        ,  //etern pin defined in pcf file
         input wire   from_pc       ,  //pin 9 UART RxD (from PC to Dev)
         output wire  to_ir         ,
         output wire  sd            ,
         input wire   i_serial_data ,
         output wire  o_serial_data ,
         
         output       test1         ,
         output       test2         ,
         output       test3         ,
         output [7:0] led   
         );

// parameters (constants)
parameter clk_freq = 27'd12000000;  // in Hz for 12MHz clock

reg [26:0]  rst_count ;
wire        i_rst ;
wire        CLKOP ;
wire        CLKOS ;        

wire [7:0]  o_rx_data       ; //output from UART RX
reg  [7:0]  uart_rx_data    ; //latch UART rx data for delay pulse

wire        o_rx_data_ready ; //output from UART RX
wire        uart_rx_rdy     ; //UART RX is read
wire        uart_rx_data_rdy; //UART data is latched

wire        U1_o_rdy     ;
wire        U1_data_ready; //narrow pulse for uart tx to tx data
wire        U1_rdy       ; //wider pulse for local logic to latch in data
wire [7:0]  U1_o_data    ;

wire        i_start_tx      ;  //connect to UART TX
wire [7:0]  i_tx_data       ;  //connect to UART TX
wire        tsr_is_empty    ;  //has data tx out   
 
// internal reset generation
// no more than 0.044 sec reset high
wire [7:0] i_rst_test; 
//assign i_rst_test[7:0] = {uart_rx_data[7]^1'b0, uart_rx_data[6]^1'b1,                    0, uart_rx_data[4]^1'b0,
//                          uart_rx_data[3]^1'b0, uart_rx_data[2]^1'b0, uart_rx_data[1]^1'b1, uart_rx_data[0]^1'b1};
// --- use esc char to reset (0x1B)
assign i_rst_test[7:0] = {is_uart_rx_b7_0, is_uart_rx_b6_0, is_uart_rx_b5_0, is_uart_rx_b4_1,
                          is_uart_rx_b3_1, is_uart_rx_b2_0, is_uart_rx_b1_1, is_uart_rx_b0_1};

always @ (posedge clk_in) begin
    if (rst_count >= (clk_freq/2)) begin
	     
	    if(&i_rst_test) begin //letter is ESC 
	       //generate reset pulse to U1
	       rst_count <= 0;
	    end
    end else begin                   
            rst_count <= rst_count + 1;
    end
	
end
	
assign i_rst = ~rst_count[19] ;

// PLL instantiation
ice_pll ice_pll_inst(
     .REFERENCECLK ( clk_in        ),  // input 12MHz
     .PLLOUTCORE   ( CLKOP         ),  // output 38MHz
     .PLLOUTGLOBAL ( PLLOUTGLOBAL  ),
     .RESET        ( 1'b1  )
     );

reg [5:0] clk_count ; 
reg CLKOS ;

always @ (posedge CLKOP) begin
    if ( clk_count == 9 ) clk_count <= 0 ;
    else clk_count <= clk_count + 1 ;          //0 - 9
    end

always @ (posedge CLKOP) begin
    if ( clk_count == 9 ) CLKOS <= ~CLKOS ;    //1.9Mhz
    end

// UART RX instantiation
uart_rx_fsm uut1 (                   
     .i_clk                 ( CLKOP           ), //38MHz
     .i_rst                 ( i_rst           ),
     .i_rx_clk              ( CLKOS           ),
     .i_start_rx            ( 1'b1            ),
     .i_loopback_en         ( 1'b0            ),
     .i_parity_even         ( 1'b0            ),
     .i_parity_en           ( 1'b0            ),               
     .i_no_of_data_bits     ( 2'b10           ),  
     .i_stick_parity_en     ( 1'b0            ),
     .i_clear_linestatusreg ( 1'b0            ),               
     .i_clear_rxdataready   ( 1'b0            ),
     .o_rx_data             ( o_rx_data       ), 
     .o_timeout             (                 ),               
     .bit_sample_en         ( bit_sample_en   ), 
     .o_parity_error        (                 ),
     .o_framing_error       (                 ),
     .o_break_interrupt     (                 ),               
     .o_rx_data_ready       ( o_rx_data_ready ),
     .i_int_serial_data     (                 ),
     .i_serial_data         ( from_pc         ) // from_pc UART signal
    );

reg [3:0] count ;
reg [17:0] shift_reg1 ;  //increase by 1 to delay strobe
reg [19:0] shift_reg2 ;
wire [15:0] shift_reg1_wire;

always @ (posedge CLKOS) count <= count + 1 ; //1.9MHz/16 = 1187500 3% error from 115200

always @ (posedge CLKOP) begin  //38MHz
    if(i_rst) begin
	    shift_reg2[19:0] <= 5'h00000;
	end
	else begin
        shift_reg2[19:0] <= {shift_reg2[18:0], o_rx_data_ready} ; //38Mhz
	end
end

always @ (posedge CLKOS) begin  //1.9MHz
    if(i_rst) begin
	    shift_reg1[17:0] <= {2'b00, 4'h0000};
	end
	else begin
        shift_reg1[17:0] <= {shift_reg1[16:0], rx_rdy} ; //1.9MHz
    end		
end

//implicity defined rx_rdy as 1 bit wire
assign rx_rdy = |shift_reg2 ; //catching 0...000 (20 bit 0s)
assign uart_rx_rdy = |shift_reg1 ; //used to latch in uart rx data

//wire uart_rx_rdy4tx = shift_reg1[1]; //used to set up the mux of uart rx or local data

//delay uart_rx_data_rdy strob by 1 1.9MHz clk tick
assign shift_reg1_wire[15:0] = shift_reg1[16:1];
assign uart_rx_data_rdy = ((&i_rst_test))? 0:(|shift_reg1_wire); 
//latch in UART Rx Data
// this logic is in clk_in domain and 
// uart_rx_rdy is at CLKOS 1.9MHz from PLL
// sync the signal first
reg [1:0] uart_rx_rdy_sync_tap;

wire l_uart_rx_rdy_sync_posedge = uart_rx_rdy_sync_tap[0] & ~uart_rx_rdy_sync_tap[1];
always @ (posedge clk_in)
begin
    if(i_rst) begin
	    uart_rx_rdy_sync_tap[1:0] <= 2'b00;
		uart_rx_data[7:0] <= 2'h00;
	end
	else begin
	    uart_rx_rdy_sync_tap[1:0] <= {uart_rx_rdy_sync_tap[0], uart_rx_rdy};

        if( l_uart_rx_rdy_sync_posedge) 
            uart_rx_data[7:0] <= {o_rx_data[7:6], o_rx_data[5], o_rx_data[4:0]} ; //flip bit5 to convert to uppter case
		else
		    uart_rx_data <= uart_rx_data;
	end
end


//---------------------------------------
// interface to U1 module
//  r1 + r2 are input data to U1 
// local variables
reg [7:0] r1, r2; //4-bit buffers
reg [1:0] U1_input_count; //internal state machine
reg U1_start;
reg ctrl_from_UartRx;
reg U1_substrate;
reg [7:0] ctrl_from_UartRx_char;
//reg U1_valid_num;

wire [7:0] U1_p_test;
wire [7:0] U1_n_test;
wire [3:0] U1_num_test;
wire U1_p_test_wire;
wire U1_n_test_wire;
wire U1_valid_num_wire;

assign is_uart_rx_b0_1 = uart_rx_data[0] ^ 1'b0;
assign is_uart_rx_b1_1 = uart_rx_data[1] ^ 1'b0;
assign is_uart_rx_b2_1 = uart_rx_data[2] ^ 1'b0;
assign is_uart_rx_b3_1 = uart_rx_data[3] ^ 1'b0;
assign is_uart_rx_b4_1 = uart_rx_data[4] ^ 1'b0;
assign is_uart_rx_b5_1 = uart_rx_data[5] ^ 1'b0;
assign is_uart_rx_b6_1 = uart_rx_data[6] ^ 1'b0;
assign is_uart_rx_b7_1 = uart_rx_data[7] ^ 1'b0;
assign is_uart_rx_b0_0 = uart_rx_data[0] ^ 1'b1;
assign is_uart_rx_b1_0 = uart_rx_data[1] ^ 1'b1;
assign is_uart_rx_b2_0 = uart_rx_data[2] ^ 1'b1;
assign is_uart_rx_b3_0 = uart_rx_data[3] ^ 1'b1;
assign is_uart_rx_b4_0 = uart_rx_data[4] ^ 1'b1;
assign is_uart_rx_b5_0 = uart_rx_data[5] ^ 1'b1;
assign is_uart_rx_b6_0 = uart_rx_data[6] ^ 1'b1;
assign is_uart_rx_b7_0 = uart_rx_data[7] ^ 1'b1;

assign U1_p_test[7:0] = {is_uart_rx_b7_0 , is_uart_rx_b6_0 , is_uart_rx_b5_1, is_uart_rx_b4_0,
                            is_uart_rx_b3_1 , is_uart_rx_b2_0 , is_uart_rx_b1_1, is_uart_rx_b0_1};

assign U1_n_test[7:0] = {is_uart_rx_b7_0 , is_uart_rx_b6_0 , is_uart_rx_b5_1, is_uart_rx_b4_0,
                            is_uart_rx_b3_1 , is_uart_rx_b2_1 , is_uart_rx_b1_0, is_uart_rx_b0_1};
					   					   
assign U1_num_test[3:0] ={is_uart_rx_b7_0, is_uart_rx_b6_0 , is_uart_rx_b5_1, is_uart_rx_b4_1};		

assign  U1_pluse_wire     = (&U1_p_test);
assign 	U1_substrate_wire = (&U1_n_test);
assign  U1_valid_num_wire = (&U1_num_test);
   
//------------------------------------------------------------------------
// use uart_rx_rdy to make sure UART Rx data is latched in
// logci is running at clk_in domain, uart_rx_data_rdy is running at 
// CLKOS 1.9MHz from PLL.  resync this signal first
reg [7:0] l_uart_rx_data_rdy_tap;
always @ (posedge clk_in) 
begin
    if(i_rst)
	    l_uart_rx_data_rdy_tap[7:0] <= 2'h00;
	else begin
	    l_uart_rx_data_rdy_tap[7:0] <= {l_uart_rx_data_rdy_tap[6:0], uart_rx_data_rdy};
	end
end
wire uart_rx_data_rdy_sync = l_uart_rx_data_rdy_tap[0] & l_uart_rx_data_rdy_tap [1] & 
                             ~l_uart_rx_data_rdy_tap[6] & ~l_uart_rx_data_rdy_tap[7];
always @ (posedge uart_rx_data_rdy_sync or posedge i_rst)
begin
    if(i_rst) begin
        U1_input_count <= 2'b00;
        U1_start <= 1'b0;
		ctrl_from_UartRx <= 1'b0;
        r1 <= 2'h00;
        r2 <= 2'h00;
    end else 
	begin 
	    if ( U1_input_count >= 2'b10) begin
	        if ( U1_pluse_wire) begin // 3th letter is '+' or '-'
				U1_substrate <= 0;
	            U1_start <= 1'b1;
		    end else 
			if ( U1_substrate_wire) begin
			    U1_substrate <= 1'b1;
		        U1_start <= 1'b1;
		    end 
			else begin
			    U1_substrate <= 0;
			end		
            ctrl_from_UartRx <= 0;
	        U1_input_count <= 2'b00;
	    end else 
		begin
	        if(U1_valid_num_wire) begin
	            if ( U1_input_count == 2'b00)
	                r1[7:0] <= uart_rx_data[7:0];
	            else if ( U1_input_count == 2'b01)
	                r2[7:0] <= uart_rx_data[7:0];					 	
		        U1_input_count <= U1_input_count + 1;
				ctrl_from_UartRx <= 0;
		    end 
			else begin 
			    ctrl_from_UartRx_char[7:0] <= uart_rx_data[7:0];
				ctrl_from_UartRx <= 1;
		        U1_input_count <= 2'b00;
			end
	        U1_start <= 0;
		end
    end
end



//---------------------- timer module
wire o_sec_tick;
wire o_min_tick;
wire o_hr_tick;
wire i_U0_clk = clk_in;  //CLKOP or clk_in or CLKOS
wire [7:0] U0_debug_led;

LED_Timer U0(
.i_rst      (i_rst)     ,  //reset
.i_clk      (i_U0_clk)  ,  //system clk 12MHz 
.o_sec_tick (o_sec_tick),  //0.5sec 1 and 0.5sec 0
.o_min_tick (o_min_tick),  //30 sec 1 and 30 sec 0
.o_hr_tick  (o_hr_tick) ,  //30 min 1 and 30 min 0
.o_LED      (U0_debug_led[7:0]) //output to wrapper's LEDs
);

//-------------------- U1 module
//-------------------- Lab3 ----------------------
wire i_sec_clk = o_sec_tick;
wire i_min_clk = o_min_tick;
wire i_hr_clk = o_hr_tick;

wire [7:0] U1_debug_led;
wire o_debug_test1;
wire o_debug_test2;
wire o_debug_test3;
wire [7:0] ctrl_from_UartRx_char_wire;
assign ctrl_from_UartRx_char_wire[7:0] = ctrl_from_UartRx_char[7:0];
wire [7:0] r1_wire;
assign r1_wire[7:0] = r1[7:0];
wire [7:0] r2_wire;
assign r2_wire[7:0] = r2[7:0];

// define input clk
wire i_U1_clk = clk_in;  //CLKOP or clk_in or CLKOS
reg [2:0] U1_start_tap;

// generate start strob, sync to input clk
always @ (posedge i_U1_clk)begin
    if(i_rst)
	    U1_start_tap[2:0] <= 3'b000;
	else 
	    U1_start_tap[2:0] <= {U1_start_tap[1:0], U1_start};
end
wire input_U1_start;
assign input_U1_start = U1_start_tap[0] & ~U1_start_tap[2];

wire U1_txdata_hold;
wire U1_tx_buf_is_empty;
assign  U1_tx_buf_is_empty = ~(U1_txdata_hold | uart_rx_rdy | (~tsr_is_empty));

Lab3_140L U1(
 .i_rst     (i_rst)                   , // reset signal
 .i_clk_in  (i_U1_clk)               , // System Clk
 
 .i_sec_in  (i_sec_clk)               ,
 .i_min_in  (i_min_clk)               ,
 .i_hr_in   (i_hr_clk)                ,
 
 .i_ctrl_signal (ctrl_from_UartRx)          , // 1: ctrl has one byte of control data from 
                                        //    UART RX (Terminal at PC)
 .i_ctrl  (ctrl_from_UartRx_char_wire[7:0]) , //ctrl letter
 
 .i_data_rdy (input_U1_start)      , //(data from UART Rx is rdy, posedge)
 .i_OPsignal (U1_substrate)        , // 1: '-', 0: '+'
 .i_data1    (r1_wire[7:0])           , // 8bit data 1
 .i_data2    (r2_wire[7:0])           , // 8bit data 1
  
 .i_buf_rdy  (U1_tx_buf_is_empty)     , //UART tx buffer is ready to get 1 byte of new data
 .o_data     (U1_o_data[7:0])  ,
 .o_rdy      (U1_o_rdy)        , //output rdy pulse, 2 i_clk_in cycles
 
 .o_debug_test1 (o_debug_test1)       , //output test point1
 .o_debug_test2 (o_debug_test2)       , //output test point2
 .o_debug_test3 (o_debug_test3)       , //output test point3
 .o_debug_led   (U1_debug_led)        //output LED
);

//assign U1_o_data[7:5] 
//convert U1_o_data 000~1FF to ASCII chars @,A,B,C,...,_
wire [7:0] o_U1_2_UART_data;
assign o_U1_2_UART_data[7:0] = {l_U1_o_data[7:0]}; //{U1_o_data[7:0]};
wire l_U1_o_rdy;
assign l_U1_o_rdy = U1_o_rdy;
//--------------------------------  -----------------------------------------------------------
// generate U1 data ready pulse.
// local variables
reg [19:0] U1_shift_reg1 ;  
reg [19:0] U1_shift_reg2 ;
wire        U1_shift_tmp;
reg U1_data_rdy;
reg U1_data_rdy_sync;
reg [5:0] U1_data_rdy_tap;
wire U1_data_rdy_tap_tst = U1_data_rdy_tap[0] & U1_data_rdy_tap[1] & (~U1_data_rdy_tap[5]);
reg [3:0] uart_tx_bit_delay_tap;
reg [1:0] uart_tx_bit_clk_posedge;


reg [7:0] l_U1_o_data;
	  
always @ (posedge CLKOP)  //38MHz
begin
    if(i_rst) begin
	    uart_tx_bit_clk_posedge <= 2'b00;
		uart_tx_bit_delay_tap <= 1'h0;
	    U1_data_rdy_tap[5:0] <= 6'b000000;
	    U1_data_rdy      <= 1'b0;
		U1_data_rdy_sync <= 1'b0;
		U1_shift_reg2[19:0] <= 5'h00000;
	end
	else begin
	    U1_shift_reg2[19:0] <= {U1_shift_reg2[18:0], U1_data_rdy_sync};
		
		//catching the rising edge of U1_o_rdy
	    U1_data_rdy_tap[5:0] <= {U1_data_rdy_tap[4:0], l_U1_o_rdy};  
		
		if(U1_data_rdy_tap_tst)
		    l_U1_o_data[7:0] <= U1_o_data[7:0];
		else
		    l_U1_o_data[7:0] <= l_U1_o_data[7:0];
			
		//catching uart tx block i_clk_in, which is a slow ck @ 1.9MHz/16
	    uart_tx_bit_clk_posedge[1:0] <= {uart_tx_bit_clk_posedge[0], count[3]};
	    
		// latch in @ posedge of l_U1_o_rdy 
		// and wait for current uart tx is finished
		// ignore rising edge if preparing for tx one byte as no buffer at tx
		if(U1_data_rdy_tap_tst & !U1_shift_tmp & !U1_data_rdy)  begin
		    uart_tx_bit_delay_tap <= 1'h0;
		    U1_data_rdy <= 1'b1;
        end			
		else if(U1_shift_tmp)  begin
		    uart_tx_bit_delay_tap <= uart_tx_bit_delay_tap;
		    U1_data_rdy <= 1'b0;  //clear the status as only one bit is needed in the tap line
		end		
		else begin
		    U1_data_rdy <= U1_data_rdy;
			uart_tx_bit_delay_tap <= uart_tx_bit_delay_tap;
		end
	    
		//set U1_data_rdy_sync after tx uart is idle
		if(uart_rx_rdy | !tsr_is_empty) begin //wait for tx release and tx fifo empty 
		    uart_tx_bit_delay_tap <= 1'h0;
	        U1_data_rdy_sync <= 1'b0;
	    end else
		begin
		    //wait until the previous tx is done + 2 bit cycles (3 i_clks posedge to uart_tx)
		    if(U1_data_rdy) begin  
			
			    if((uart_tx_bit_clk_posedge[0] & !uart_tx_bit_clk_posedge[1])) 
			        uart_tx_bit_delay_tap[3:0] <= {uart_tx_bit_delay_tap[2:0], 1'b1};
				else
				    uart_tx_bit_delay_tap <= uart_tx_bit_delay_tap;
					
                if(uart_tx_bit_delay_tap[3])						
	                U1_data_rdy_sync <= 1'b1;
				else
				    U1_data_rdy_sync <= U1_data_rdy_sync;
					
			end 
			else begin
			    U1_data_rdy_sync <= 1'b0;
				uart_tx_bit_delay_tap <= uart_tx_bit_delay_tap;
			end
		end
	end
end

assign U1_shift_tmp = |U1_shift_reg2 ; //catching 0...000 (20 bit 0s)

//always @ (posedge CLKOP) U1_shift_reg2[19:0] <= {U1_shift_reg2[18:0], U1_data_rdy_sync} ; //38Mhz
always @ (posedge CLKOS) begin  //1.9MHz
    if(i_rst)
	    U1_shift_reg1[19:0] <= 5'h00000;
	else
        U1_shift_reg1[19:0] <= {U1_shift_reg1[18:0], U1_shift_tmp} ; //1.9MHz
end

//delay U1_rdy strob by 1 1.9MHz clk tick
wire [19:0] U1_shift_reg1_wire1 = U1_shift_reg1[19:0]; //use wire to control the starting time
assign U1_rdy = |U1_shift_reg1_wire1; //last for 20 1.9MHz clk

reg U1_tx_sm;
reg [3:0] tx_sm_count;

//count is on PLL same as U1_rdy
always @ (posedge count[3]) begin  //118KHz bit clk (16 1.9MHz clk) is enough to sample U1_rdy
    if(i_rst) begin
	    U1_tx_sm <= 1'b0;
		//db_test_point <= 1'h0;
	end
	else begin
	    if(U1_tx_sm) 
		begin
		    if(tsr_is_empty) begin
			    
				tx_sm_count [3:0] <= {tx_sm_count [2:0], 1'b0};
				
				if(tx_sm_count[3] == 1'b1)
			        U1_tx_sm <= 1'b0;
				else
				    U1_tx_sm <= U1_tx_sm;
			end
			else begin
			    tx_sm_count <= tx_sm_count;
			end
		end 
		else if(U1_rdy) 
		begin
		    //db_test_point <= 1'h0;		
		    tx_sm_count [3:0] <= 1'h1;
	        U1_tx_sm <= 1'b1;
		end
		else begin
		    tx_sm_count <= tx_sm_count;
			U1_tx_sm <= U1_tx_sm;
		end
	end
end

assign U1_txdata_hold = U1_tx_sm;

wire [15:0] U1_shift_reg1_wire2 = U1_shift_reg1[17:2]; //use wire to control the starting time
assign U1_data_ready = |U1_shift_reg1_wire2;

wire [7:0] o_uart_data_byte;

assign o_uart_data_byte [7:0] = (U1_txdata_hold)? o_U1_2_UART_data[7:0] : uart_rx_data[7:0];

//determine the input -- from U1 or loopback from UART RX
assign  i_start_tx = U1_data_ready | uart_rx_data_rdy;
assign	i_tx_data[7:0] = o_uart_data_byte[7:0];
//assign	i_tx_data[7:0] = uart_rx_data[7:0];
//assign  i_start_tx = uart_rx_data_rdy;

// UART TX instantiation
uart_tx_fsm uut2(                                
    .i_clk                 ( count[3]      ),   
    .i_rst                 ( i_rst         ),   
    .i_tx_data             ( i_tx_data  ),   
    .i_start_tx            ( i_start_tx    ),   
    .i_tx_en               ( 1'b1          ),   
    .i_tx_en_div2          ( 1'b0          ),   
    .i_break_control       ( 1'b0          ),   
    .o_tx_en_stop          (  ),                
    .i_loopback_en         ( 1'b0          ),   
    .i_stop_bit_15         ( 1'b0          ),   
    .i_stop_bit_2          ( 1'b0          ),   
    .i_parity_even         ( 1'b0          ),   
    .i_parity_en           ( 1'b0          ),   
    .i_no_of_data_bits     ( 2'b11         ),   
    .i_stick_parity_en     ( 1'b0          ),   
    .i_clear_linestatusreg ( 1'b0          ),   
    .o_tsr_empty           (tsr_is_empty),                
    .o_int_serial_data     (  ),                
    .o_serial_data_local   ( o_serial_data )    //pin 8 UART TXD (from Dev to PC)
    );                                          

/*
//-------------------------------------------------------------------------------
// write to IR tx
 reg [4:0] ir_tx_reg ;  
 wire ir_tx ;
 
 assign sd = 0 ;  // 0: enable  
 always @ (posedge CLKOP) ir_tx_reg[4:0] <= {ir_tx_reg[3:0], bit_sample_en} ; 
 assign ir_tx = |ir_tx_reg ;
 assign to_ir = ir_tx & ~from_pc ;
  
 // test points
 assign test1 =  to_ir ;   //data to IR 
 assign test2 =  from_pc ; //RxD
 assign test3 =  i_rst ;   //internal reset (active low for 0.5sec)
//---------------------------------------------------------------------------------
*/

// DUT module can control 3 test pins
assign test1 =  o_debug_test1;   // 
assign test2 =  o_debug_test2;   //
assign test3 =  o_debug_test3;   //
//-----------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------
// LED and DEBUG
//sample and hold reg
reg [4:0] debug_test;
reg [4:0] debug_test1;
reg [4:0] debug_test2;
reg [4:0] debug_test3;

//from wrapper to U1
wire db_uart_rx_rdy = uart_rx_rdy;
wire db_uart_rx_data_rdy = uart_rx_data_rdy;
wire db_U1_input_count0 = U1_input_count[0];
wire db_U1_start = U1_start;
wire db_input_U1_start = input_U1_start;
wire db_U1_valid_num_wire = U1_valid_num_wire;

//from U1 to wrapper
wire db_U1_o_rdy = U1_o_rdy;
wire db_U1_shift_tmp = U1_shift_tmp;
wire db_U1_data_rdy = U1_data_rdy;
wire db_U1_rdy = U1_rdy;
wire db_U1_data_rdy_sync = U1_data_rdy_sync;
wire db_U1_txdata_hold = U1_txdata_hold;
wire db_U1_tx_sm = U1_tx_sm;

wire db_tsr_is_empty = tsr_is_empty;

/*
reg [1:0] db_tsr_is_empty_edge;
wire db_tsr_is_empty_posedge;
wire db_tsr_is_empty_negedge;

always @ (posedge CLKOS)
begin
    if(i_rst)
	    db_tsr_is_empty_edge <= 2'b00;
	else
	    db_tsr_is_empty_edge[1:0] <= {db_tsr_is_empty_edge[0], db_tsr_is_empty};
end
assign db_tsr_is_empty_posedge = db_tsr_is_empty_edge[0] & ~db_tsr_is_empty_edge[1];
assign db_tsr_is_empty_negedge = db_tsr_is_empty_edge[1] & ~db_tsr_is_empty_edge[0];
*/

wire [3:0] db_count = count[3:0];
wire [3:0] db_tx_sm_count = tx_sm_count[3:0];
/*
wire [7:0] db_uart_rx_dat_wire = uart_rx_data [7:0]
reg [7:0] db_uart_rx_char_0;
reg [7:0] db_uart_rx_char_1;
reg [7:0] db_uart_rx_char_2;

wire [3:0] db_uart_tx_bit_delay_tap = uart_tx_bit_delay_tap[3:0];
wire [1:0] db_uart_tx_bit_clk_posedge = uart_tx_bit_clk_posedge[1:0];
*/



//sampling rate at 38MHz at PLL domain
//consume more pwr to catch transitions of logic
always @ (posedge CLKOP) begin  //sample at 38MHz high speek clk
    if(i_rst) begin
	    debug_test  <= 5'b00000;
		debug_test1 <= 5'b00000;
		debug_test2 <= 5'b00000;
		debug_test3 <= 5'b00000;
    end else 
	    
	    // test0
	    // output from DUT
		if(db_U1_o_rdy)              //check this pulse ever goes high 
		debug_test[0] <= 1'b1; 
		debug_test[1] <= db_U1_o_rdy;//check it goes low at the end
	    if(db_U1_rdy)
	    debug_test[2] <= 1'b1;	       //check DUT module generate a pulse, should be high
		debug_test[3] <= db_U1_rdy; //strobe, check if go low
		debug_test[4] <= db_U1_txdata_hold; //mux for selecting data src to uart tx
		// test1
		// output from DUT
		
//		if(db_tsr_is_empty_posedge)
//		debug_test1[0] <= 1'b1;
//		if(db_tsr_is_empty_negedge)
//		debug_test1[1] <= 1'b1;
		
		debug_test1[0] <= db_tsr_is_empty; //check if it stay high at the end
		debug_test1[1] <= db_U1_tx_sm;
		debug_test1[2] <= db_count[2] & ~db_count[3];
		
		if(db_tx_sm_count[3] & db_tx_sm_count[2]) //3:0 4'b11xx
		debug_test1[3] <= 1'b1;
		if(db_tx_sm_count[0] & ~db_tx_sm_count[3]) //3:0 4'b0xx1
		debug_test1[4] <= 1'b1;
	    
		// test2
		// output from UART RX
//		debug_test2[0] <= db_test_point[0];
//		debug_test2[1] <= db_test_point[1];
//		debug_test2[2] <= db_test_point[2];
//		debug_test2[3] <= db_test_point[3];
//		debug_test2[4] <= db_tsr_is_empty & db_U1_tx_sm;


	    if(db_uart_rx_rdy)
		debug_test2[0] <= 1'b1;
		if(db_uart_rx_data_rdy)
		debug_test2[1] <= 1'b1;
		if(U1_valid_num_wire)
		debug_test2[2] <= 1'b1;
		if(db_U1_input_count0)
		debug_test2[3] <= 1'b1;
		if(db_U1_start)
		debug_test2[4] <= 1'b1;
		
		//test3
		//output from UART RX
        if(db_input_U1_start)
		debug_test3[0] <= 1'b1;
		//output to UART TX
		debug_test3[1] <= db_count[3] & ~db_count[2];
		debug_test3[2] <= db_count[2] & ~db_count[3];
		if(db_tx_sm_count[1] & ~db_tx_sm_count[3]) //3:0 4'b0x1x
		debug_test3[3] <= 1'b1;
		debug_test3[4] <= |db_tx_sm_count;  //should go to 4'b1111		
end


/*
//sampling rate at 118KHz at PLL domain
//used to catch slow transition or output after the operations
//input to DUT module

wire [7:0] db_DUT_in1 = r1_wire[7:0];
wire [7:0] db_DUT_in2 = r2_wire[7:0];
wire [7:0] db_DUT_in3 = ctrl_from_UartRx_char_wire[7:0]; //control char
wire       db_DUT_in4 = ctrl_from_UartRx;
wire       db_DUT_in5 = U1_substrate;

wire [7:0] db_DUT_out1 = U1_o_data[7:0];

wire db_ctrl_from_UartRx = ctrl_from_UartRx;
wire db_U1_substrate = U1_substrate;

always @ (posedge count[3]) begin  //sample at 118KHz low speek clk
    if(i_rst) begin
	    debug_test  <= 5'b00000;
		debug_test1 <= 5'b00000;
		debug_test2 <= 5'b00000;
		debug_test3 <= 5'b00000;
    end else 
	begin
	
	    // test0
	    // output from DUT
		debug_test[0] <= db_U1_shift_tmp;//check it goes low at the end
		debug_test[1] <= db_U1_rdy; //strobe, check if go low
		debug_test[2] <= db_U1_txdata_hold; //mux for selecting data src to uart tx
//		if(db_tsr_is_empty_posedge)
//		debug_test[3] <= 1'b1;
//		if(db_tsr_is_empty_negedge)
//		debug_test[4] <= 1'b1;
		
		debug_test1[0] <= db_tsr_is_empty; //check if it stay high at the end
		debug_test1[1] <= db_U1_tx_sm;
		debug_test1[2] <= db_count[2] & ~db_count[3];
	    
		// test2
		// output from UART RX
//		debug_test2[0] <= db_test_point[0];
//		debug_test2[1] <= db_test_point[1];
//		debug_test2[2] <= db_test_point[2];
//		debug_test2[3] <= db_test_point[3];
//		debug_test2[4] <= db_tsr_is_empty & db_U1_tx_sm;

		
		//test3
		//output from UART RX
		debug_test3[1] <= db_count[3] & ~db_count[2];
		debug_test3[2] <= db_count[2] & ~db_count[3];
		debug_test3[4] <= |db_tx_sm_count;  //should go to 4'b1111
		
    end
end
*/

// MUX: select the output to LEDs
wire [7:0] debug_CR_test;
assign debug_CR_test[7:0] = {is_uart_rx_b7_0 , is_uart_rx_b6_0 , is_uart_rx_b5_0, is_uart_rx_b4_0,
                             is_uart_rx_b3_1 , is_uart_rx_b2_1 , is_uart_rx_b1_0, is_uart_rx_b0_1};
assign debug_is_CR = &debug_CR_test;  

wire [7:0] debug_DEL_test; // DEL 0x7F  
assign debug_DEL_test[7:0] = {is_uart_rx_b7_0 , is_uart_rx_b6_1 , is_uart_rx_b5_1, is_uart_rx_b4_1,
                              is_uart_rx_b3_1 , is_uart_rx_b2_1 , is_uart_rx_b1_1, is_uart_rx_b0_1};
assign debug_is_DEL = &debug_DEL_test;  

wire [7:0] debug_BS_test; // 40 = 0x28 bachspace
assign debug_BS_test[7:0] = {is_uart_rx_b7_0 , is_uart_rx_b6_0 , is_uart_rx_b5_1, is_uart_rx_b4_0,
                              is_uart_rx_b3_1 , is_uart_rx_b2_0 , is_uart_rx_b1_0, is_uart_rx_b0_0};
assign debug_is_BS = &debug_BS_test;  

wire [7:0] debug_TAB_test; // 41 = 0x29 TAB
assign debug_TAB_test[7:0] = {is_uart_rx_b7_0 , is_uart_rx_b6_0 , is_uart_rx_b5_1, is_uart_rx_b4_0,
                              is_uart_rx_b3_1 , is_uart_rx_b2_0 , is_uart_rx_b1_0, is_uart_rx_b0_1};
assign debug_is_TAB = &debug_TAB_test;  
/*
wire [7:0] debug_91_test; //  91 = 0x5b [
assign debug_91_test[7:0] = {is_uart_rx_b7_0 , is_uart_rx_b6_1 , is_uart_rx_b5_0, is_uart_rx_b4_1,
                              is_uart_rx_b3_1 , is_uart_rx_b2_0 , is_uart_rx_b1_1, is_uart_rx_b0_1};
assign debug_is_91 = &debug_91_test;  

wire [7:0] debug_93_test; //  93 = 0x5d ]
assign debug_93_test[7:0] = {is_uart_rx_b7_0 , is_uart_rx_b6_1 , is_uart_rx_b5_0, is_uart_rx_b4_1,
                              is_uart_rx_b3_1 , is_uart_rx_b2_1 , is_uart_rx_b1_0, is_uart_rx_b0_1};
assign debug_is_93 = &debug_93_test;  
*/

wire [7:0] debug_wire;
assign debug_wire[7:0] = 
                         debug_is_CR?  {1'b0,1'b0, 1'b0, debug_test[4:0]}:  
                         debug_is_DEL? {1'b0,1'b0, 1'b0, debug_test1[4:0]}:
						 debug_is_BS?  {1'b0,1'b0, 1'b0, debug_test2[4:0]}: 
						 debug_is_TAB? {1'b0,1'b0, 1'b0, debug_test3[4:0]}: 
//						 debug_is_91?  {1'b0,1'b0, 1'b0, debug_test4[4:0]}: // '['
//						 debug_is_93?  {1'b0,1'b0, 1'b0, debug_test5[4:0]}: // ']'
						 U1_debug_led[7:0];
//                         uart_rx_data[7:0];
						 
 assign led[0] = debug_wire[0];                      
 assign led[1] = debug_wire[1];                      
 assign led[2] = debug_wire[2];                      
 assign led[3] = debug_wire[3];                      
 assign led[4] = debug_wire[4];                      

endmodule
