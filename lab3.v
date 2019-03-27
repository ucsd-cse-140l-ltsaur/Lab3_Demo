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

//-------------------- Lab3 ----------------------
module Lab3_140L (
 input wire i_rst                 , // reset signal
 input wire i_clk_in              , // System Clk
 
 input wire i_sec_in              ,
 input wire i_min_in              ,
 input wire i_hr_in               ,
 
 input wire i_ctrl_signal         , // 1: ctrl has one byte of control data from 
                                    //    UART RX (Terminal at PC)
 input wire [7:0] i_ctrl          , //ctrl letter
 
 input wire i_data_rdy            , //(data from UART Rx is rdy, posedge)
 input wire i_OPsignal            , // 1: '-', 0: '+'
 input wire [7:0] i_data1         , // 8bit data 1
 input wire [7:0] i_data2         , // 8bit data 1
  
 input wire i_buf_rdy             , //UART tx buffer is ready to get 1 byte of new data
 output wire [7:0] o_data         ,
 output wire o_rdy                , //output rdy pulse, 2 i_clk_in cycles
 
 output wire o_debug_test1        , //output test point1
 output wire o_debug_test2        , //output test point2
 output wire o_debug_test3        , //output test point3
 output wire [7:0] o_debug_led     //output LED
);

//------------ latch in data x, and y
reg [1:0] i_data_rdy_tap;
reg [7:0] x, y;
wire i_data_rdy_local_posedge;
assign i_data_rdy_local_posedge = i_data_rdy_tap[0] & ~i_data_rdy_tap[1]; 

// combine strobs generated within 2 cycles of i_clk_in
always @(posedge i_clk_in) begin
    if(i_rst) begin
        i_data_rdy_tap[1:0] <= 2'b00;
        x <= 2'h00;
        y <= 2'h00;

    end
    else begin
        i_data_rdy_tap[1:0] <= {i_data_rdy_tap[0], i_data_rdy};

        if(i_data_rdy_local_posedge) begin      
            x[7:0] <= i_data1[7:0];
            y[7:0] <= i_data2[7:0];
            
            //if (i_OPsignal) begin
            //end
            //else begin
            //end
        end
        else begin
            x <= x;
            y <= y;
        end
    end
end



//------------ Add your adder here ----------
//reset your logic
reg [5:0] l_sec_reg;
reg l_minute_pulse;

reg [5:0] l_minute_reg; 
reg l_hr_pulse;

reg [4:0] l_hr_reg;
reg l_day_pulse;

//update l_sec_reg
wire [5:0] sec_cntr_wire;
assign sec_cntr_wire [5:0] = {l_sec_reg [5:0]};

wire [5:0] test_59_sec;
assign test_59_sec = {sec_cntr_wire[5] ^ 1'b0, sec_cntr_wire[4] ^ 1'b0, sec_cntr_wire[3] ^ 1'b0,
                      sec_cntr_wire[2] ^ 1'b1, sec_cntr_wire[1] ^ 1'b0, sec_cntr_wire[0] ^ 1'b0}; //0x3B

wire [5:0] test_57_sec;
assign test_57_sec = {sec_cntr_wire[5] ^ 1'b0, sec_cntr_wire[4] ^ 1'b0, sec_cntr_wire[3] ^ 1'b0,
                      sec_cntr_wire[2] ^ 1'b1, sec_cntr_wire[1] ^ 1'b1, sec_cntr_wire[0] ^ 1'b0}; //0x39

wire [5:0] test_29_sec;
assign test_29_sec = {sec_cntr_wire[5] ^ 1'b1, sec_cntr_wire[4] ^ 1'b0, sec_cntr_wire[3] ^ 1'b0,
                      sec_cntr_wire[2] ^ 1'b0, sec_cntr_wire[1] ^ 1'b1, sec_cntr_wire[0] ^ 1'b0}; //0x1D
                    
wire is_59_sec = (&test_59_sec);
wire is_57_sec = (&test_57_sec);
wire is_29_sec = (&test_29_sec);
reg [3:0] sec_h_digit;
reg [3:0] sec_l_digit;
always@(posedge i_sec_in or posedge i_rst) begin
    if (i_rst) begin
        l_sec_reg[5:0] <= 6'b000000;
        l_minute_pulse <= 0;
    end 
    else begin
        
        if(is_59_sec) begin
            l_sec_reg[5:0] <= 6'b000000;
        end 
        else begin
            l_sec_reg[5:0] <= l_sec_reg[5:0] + 1'b1;
            if (is_57_sec)
                l_minute_pulse <= 1'b1;     
            else if (is_29_sec) 
                l_minute_pulse <= 1'b0;
            else
                l_minute_pulse <= l_minute_pulse;
        end
        
        //caculate sec one clk before latch in
        if(l_sec_reg > 49) begin
            sec_l_digit <= l_sec_reg - 50;
            sec_h_digit <= 5;
        end
        else if(l_sec_reg > 39)  begin
            sec_l_digit <= l_sec_reg - 40;
            sec_h_digit <= 4;
        end 
        else if(l_sec_reg > 29)  begin
            sec_l_digit <= l_sec_reg - 30;
            sec_h_digit <= 3;
        end 
        else if(l_sec_reg > 19)  begin
            sec_l_digit <= l_sec_reg - 20;
            sec_h_digit <= 2;
        end 
        else if(l_sec_reg > 9)  begin
            sec_l_digit <= l_sec_reg - 10;
            sec_h_digit <= 1;
        end 
        else begin      
            sec_l_digit <= l_sec_reg;
            sec_h_digit <= 0;
        end         
    end
end

//update minutes
wire l_minute_pulse_wire;
assign l_minute_pulse_wire = l_minute_pulse;

wire [5:0] minute_cntr_wire;
assign minute_cntr_wire[5:0] = {l_minute_reg[5:0]};

wire [5:0] test_59_min;
assign test_59_min = {minute_cntr_wire[5] ^ 1'b0, minute_cntr_wire[4] ^ 1'b0, minute_cntr_wire[3] ^ 1'b0,
                      minute_cntr_wire[2] ^ 1'b1, minute_cntr_wire[1] ^ 1'b0, minute_cntr_wire[0] ^ 1'b0}; //0x3B
                    
wire [5:0] test_29_min;
assign test_29_min = {minute_cntr_wire[5] ^ 1'b1, minute_cntr_wire[4] ^ 1'b0, minute_cntr_wire[3] ^ 1'b0,
                      minute_cntr_wire[2] ^ 1'b0, minute_cntr_wire[1] ^ 1'b1, minute_cntr_wire[0] ^ 1'b0}; //0x1D
                      
wire is_59_min = &test_59_min;
wire is_29_min = &test_29_min;

reg l_hr_pulse_reg;
reg [3:0] min_h_digit;
reg [3:0] min_l_digit;
reg [1:0] minute_pulse_tap;
wire l_minute_pulse_posedge;
assign l_minute_pulse_posedge = minute_pulse_tap[0] & ~minute_pulse_tap[1];

always@(posedge i_sec_in or posedge i_rst) begin
    if (i_rst) begin
        l_minute_reg[5:0] <= 6'b000000;
        l_hr_pulse_reg <= 0;
        min_h_digit <= 0;
        min_l_digit <= 0;
        minute_pulse_tap <= 0;
    end
    else begin
        minute_pulse_tap[1:0] <= {minute_pulse_tap[0], l_minute_pulse_wire};
        if(l_minute_pulse_posedge) begin
            if(is_59_min) begin
                l_minute_reg[5:0] <= 6'b000000;
                l_hr_pulse_reg <= 1'b1;
            end
            else begin
                l_minute_reg <= l_minute_reg + 1;
                if(is_29_min)
                    l_hr_pulse_reg <= 1'b0;
                else 
                    l_hr_pulse_reg <= l_hr_pulse_reg;
            end     
        end
        else begin
        
            if(is_59_min & is_57_sec)
                l_hr_pulse_reg <= 1'b1;
            else if(is_29_min & is_57_sec)
                l_hr_pulse_reg <= 1'b0;
            else 
                l_hr_pulse_reg <= l_hr_pulse_reg;   
        
            l_minute_reg <= l_minute_reg;
            
            //caculate minute before latch in
            if(l_minute_reg > 49) begin
                min_l_digit <= l_minute_reg - 50;
                min_h_digit <= 5;
            end
            else if(l_minute_reg > 39)  begin
                min_l_digit <= l_minute_reg - 40;
                min_h_digit <= 4;
            end 
            else if(l_minute_reg > 29)  begin
                min_l_digit <= l_minute_reg - 30;
                min_h_digit <= 3;
            end 
            else if(l_minute_reg > 19)  begin
                min_l_digit <= l_minute_reg - 20;
                min_h_digit <= 2;
            end 
            else if(l_minute_reg > 9)  begin
                min_l_digit <= l_minute_reg - 10;
                min_h_digit <= 1;
            end 
            else begin      
                min_l_digit <= l_minute_reg;
                min_h_digit <= 0;
            end         

        end
    end
end 

wire l_hr_pulse_wire;
assign l_hr_pulse_wire = l_hr_pulse_reg;

wire [4:0] l_hr_wire;
assign l_hr_wire[4:0] = {l_hr_reg[4:0]};

wire [4:0] test_23_hr;
assign test_23_hr = {l_hr_wire[4] ^ 1'b0, l_hr_wire[3] ^ 1'b1,
                     l_hr_wire[2] ^ 1'b0, l_hr_wire[1] ^ 1'b0, l_hr_wire[0] ^ 1'b0}; //0x17
wire is_23_hr = &test_23_hr;

reg [3:0] hr_h_digit;
reg [3:0] hr_l_digit;
reg [1:0] hr_pulse_tap;
wire l_hr_pulse_posedge;
assign l_hr_pulse_posedge = hr_pulse_tap[0] & ~hr_pulse_tap[1];

always @ (posedge i_sec_in or posedge i_rst) begin
    if(i_rst) begin
        l_hr_reg[4:0] <= 5'b00000;
        hr_h_digit <= 0;
        hr_l_digit <= 0;
        hr_pulse_tap <= 0;
    end
    else begin
        hr_pulse_tap[1:0] <= {hr_pulse_tap[0], l_hr_pulse_wire};
        
        if(l_hr_pulse_posedge) begin
            if(is_23_hr) begin
                l_hr_reg[4:0] <= 5'b00000;
            end
            else begin
                l_hr_reg[4:0] <= l_hr_reg[4:0] + 1'b1;
            end 
        end
        else begin
            //convert hr into 2 decimal digits for display
            if(l_hr_reg > 19) begin
                hr_l_digit <= l_hr_reg - 20;
                hr_h_digit <= 2;
            end
            else if(l_hr_reg > 9)  begin
                hr_l_digit <= l_hr_reg - 10;
                hr_h_digit <= 1;
            end         
            else begin
                hr_l_digit <= l_hr_reg;
                hr_h_digit <= 0;
            end 
            l_hr_reg <= l_hr_reg;           
        end

    end
end

//report local time

//-------- generate o_rdy strobes
reg [7:0] l_o_rdy_tap;

wire l_o_rdy_wire;
assign l_o_rdy_wire = l_o_rdy_tap[7]; 
assign o_rdy = l_o_rdy_wire;

//parameter BUF_LENGH = 8;
//parameter BUF_SIZE_1 = 3;

reg l_o_data_start;
reg [7:0] l_buffer [3:0];
reg [3:0] l_buf_in_indx;
reg [3:0] l_buf_out_indx;
reg [3:0] l_buf_out_indx2;
wire l_bus_wake_up;
wire l_bus_clk_in = i_clk_in;

wire l_i_buf_rdy = i_buf_rdy;
wire l_i_buf_rdy_b = ~l_i_buf_rdy;
wire l_l_o_rdy_tap_nor = ~(|l_o_rdy_tap);
wire l_o_rdy_tap_and = &l_o_rdy_tap;
wire l_buf_in_neq_out = (l_buf_in_indx ^ l_buf_out_indx);

reg [7:0] l_buf_hold;
wire [7:0] l_buf_hold_wire;
assign l_buf_hold_wire [7:0] = l_buf_hold[7:0];
assign o_data[7:0] = l_buf_hold_wire [7:0];

always @ (posedge l_bus_clk_in ) begin
    if(i_rst) begin
        l_buf_out_indx  <= 0;       
        l_buf_out_indx2 <= 1;       
        l_o_data_start <= 0;
        l_o_rdy_tap <= 0;
        l_buf_hold  <= 0;
    end
    else begin
        // for generating a ready strobe to top level
        l_o_rdy_tap[7:0] <= {l_o_rdy_tap[6:0], l_o_data_start};

        if (l_buf_in_neq_out) begin
        
            if(l_l_o_rdy_tap_nor) begin
                if(l_i_buf_rdy) begin
                    l_o_data_start <= 1;
                    l_buf_hold[7:0] <= l_buffer[l_buf_out_indx2][7:0];
                end
            end
            else 
                l_buf_hold <= l_buf_hold;

            //if((~l_o_rdy_tap[2]) & l_o_rdy_tap[1] & l_o_rdy_tap[0]) begin
            //end
        
            if(l_o_rdy_tap_and) begin //l_o_data_start == 1
                if(l_i_buf_rdy_b) begin
                    l_o_data_start <= 0; 
                    l_buf_out_indx <= l_buf_out_indx2;
                    l_buf_out_indx2 <= l_buf_out_indx2 + 1;
                end 
            end     
            else begin
                l_buf_out_indx <= l_buf_out_indx;
                l_buf_out_indx2 <= l_buf_out_indx2;
            end
        end     
        
        
    end
end


// output to circular buffer
wire l_sleep_clk;
assign l_sleep_clk = i_sec_in;

reg l_sleep_reg;

wire l_output_clk;
assign l_output_clk = (l_sleep_reg)? l_sleep_clk: l_sleep_clk;

reg [3:0] l_buf_indx1;
reg [1:0] l_sec_tap;
reg [3:0] l_state;

wire l_state_or = |l_state;
wire l_state_nor = ~l_state_or;
wire l_sec_tap_posedge = (l_sec_tap[0] & (~l_sec_tap[1]));
wire l_sec_tap_negedge = (l_sec_tap[1] & (~l_sec_tap[0]));
wire l_buf_indx1_neq_out = (l_buf_indx1 ^ l_buf_out_indx);

always @ (posedge l_bus_clk_in ) begin
    if(i_rst) begin
        l_state <= 0;
        l_sec_tap <= 0;
        //l_sleep_reg <= 1;
        l_buf_in_indx <= 0;
        l_buf_indx1 <= 1;

    end
    else begin
        l_sec_tap[1:0] <= {l_sec_tap[0], i_sec_in};
        
        if(l_state_nor)
            if(l_sec_tap_negedge) begin
                l_state <= 1;
            end
        else
            l_state <= l_state;
        
        if(|l_state) begin      
            if (l_buf_indx1_neq_out) begin
                if(l_state == 1) begin
                    l_state <= 2;
                    l_buffer[l_buf_indx1][7:0]<= {1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1}; //CR, 0x0D
                    l_buf_in_indx <= l_buf_indx1;
                    l_buf_indx1 <= l_buf_indx1+1;
                
                end
                else if(l_state == 2) begin
                    l_state <= 3;
                    l_buffer[l_buf_indx1][7:0] <= {1'b0, 1'b0, 1'b1, 1'b1, hr_h_digit[3:0]}; 
                    l_buf_in_indx <= l_buf_indx1;
                    l_buf_indx1 <= l_buf_indx1+1;

                end
                else if(l_state == 3) begin
                    l_state <= 4;   
                    l_buffer[l_buf_indx1][7:0] <= {1'b0, 1'b0, 1'b1, 1'b1, hr_l_digit[3:0]}; 
                    l_buf_in_indx <= l_buf_indx1;
                    l_buf_indx1 <= l_buf_indx1+1;
                end
                else if(l_state == 4) begin
                    l_state <= 5;
                    l_buffer[l_buf_indx1][7:0] <= {1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b0, 1'b1, 1'b0}; //: 3A
                    l_buf_in_indx <= l_buf_indx1;
                    l_buf_indx1 <= l_buf_indx1+1;               
                end
                else if(l_state == 5) begin
                    l_state <= 6;   
                    l_buffer[l_buf_indx1][7:0] <= {1'b0, 1'b0, 1'b1, 1'b1, min_h_digit[3:0]}; 
                    l_buf_in_indx <= l_buf_indx1;
                    l_buf_indx1 <= l_buf_indx1+1;

                end
                else if(l_state == 6) begin
                    l_state <= 7;
                    l_buffer[l_buf_indx1][7:0] <= {1'b0, 1'b0, 1'b1, 1'b1, min_l_digit[3:0]}; 
                    l_buf_in_indx <= l_buf_indx1;
                    l_buf_indx1 <= l_buf_indx1+1;
                end
                else if(l_state == 7) begin
                    l_state <= 8;
                    l_buffer[l_buf_indx1][7:0] <= {1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b0, 1'b1, 1'b0}; //: 3A
                    l_buf_in_indx <= l_buf_indx1;
                    l_buf_indx1 <= l_buf_indx1+1;
                end
                else if(l_state == 8) begin
                    l_state <= 9;       
        
                    l_buffer[l_buf_indx1][7:0] <= {1'b0, 1'b0, 1'b1, 1'b1, sec_h_digit[3:0]}; 
                    l_buf_in_indx <= l_buf_indx1;
                    l_buf_indx1 <= l_buf_indx1+1;
                end
                else if(l_state == 9) begin
                    l_state <= 10;
                    l_buffer[l_buf_indx1][7:0] <= {1'b0, 1'b0, 1'b1, 1'b1, sec_l_digit[3:0]}; 
                    //l_buf_in_indx <= l_buf_indx1;
                    //l_buf_indx1 <= l_buf_indx1+1;
                end
                else if(l_state == 10) begin
                    l_state <= 11;
                    l_buffer[l_buf_indx1][7:0] <= l_buffer[l_buf_indx1][7:0];
                    l_buf_in_indx <= l_buf_indx1;
                    l_buf_indx1 <= l_buf_indx1+1;
                end
                else begin
                    l_state <= 0;
                    l_buf_in_indx <= l_buf_in_indx;
                    l_buf_indx1 <= l_buf_indx1;
                end
            end
        end
    end 
end




//---------------------------------------------------------------------------------------------
// displace control
assign is_uart_rx_b0_1 = i_ctrl[0] ^ 1'b0;
assign is_uart_rx_b1_1 = i_ctrl[1] ^ 1'b0;
assign is_uart_rx_b2_1 = i_ctrl[2] ^ 1'b0;
assign is_uart_rx_b3_1 = i_ctrl[3] ^ 1'b0;
assign is_uart_rx_b4_1 = i_ctrl[4] ^ 1'b0;
assign is_uart_rx_b5_1 = i_ctrl[5] ^ 1'b0;
assign is_uart_rx_b6_1 = i_ctrl[6] ^ 1'b0;
assign is_uart_rx_b7_1 = i_ctrl[7] ^ 1'b0;
assign is_uart_rx_b0_0 = i_ctrl[0] ^ 1'b1;
assign is_uart_rx_b1_0 = i_ctrl[1] ^ 1'b1;
assign is_uart_rx_b2_0 = i_ctrl[2] ^ 1'b1;
assign is_uart_rx_b3_0 = i_ctrl[3] ^ 1'b1;
assign is_uart_rx_b4_0 = i_ctrl[4] ^ 1'b1;
assign is_uart_rx_b5_0 = i_ctrl[5] ^ 1'b1;
assign is_uart_rx_b6_0 = i_ctrl[6] ^ 1'b1;
assign is_uart_rx_b7_0 = i_ctrl[7] ^ 1'b1;


wire [7:0] debug_CR_test; //CR 0x0D
assign debug_CR_test[7:0] = {is_uart_rx_b7_0 , is_uart_rx_b6_0 , is_uart_rx_b5_0, is_uart_rx_b4_0,
                             is_uart_rx_b3_1 , is_uart_rx_b2_1 , is_uart_rx_b1_0, is_uart_rx_b0_1};

wire [7:0] debug_z_test; //z 0x7A
assign debug_z_test[7:0] = {is_uart_rx_b7_0 , is_uart_rx_b6_1 , is_uart_rx_b5_1, is_uart_rx_b4_1,
                              is_uart_rx_b3_1 , is_uart_rx_b2_0, is_uart_rx_b1_1, is_uart_rx_b0_0};

wire [7:0] debug_LB_test; //{ 0x7B
assign debug_LB_test[7:0] = {is_uart_rx_b7_0 , is_uart_rx_b6_1 , is_uart_rx_b5_1, is_uart_rx_b4_1,
                              is_uart_rx_b3_1 , is_uart_rx_b2_0, is_uart_rx_b1_1, is_uart_rx_b0_1};
                              
wire [7:0] debug_OR_test; //| 0x7C
assign debug_OR_test[7:0] = {is_uart_rx_b7_0 , is_uart_rx_b6_1 , is_uart_rx_b5_1, is_uart_rx_b4_1,
                              is_uart_rx_b3_1 , is_uart_rx_b2_1, is_uart_rx_b1_0, is_uart_rx_b0_0};                           
wire [7:0] debug_RB_test; //} 0x7D
assign debug_RB_test[7:0] = {is_uart_rx_b7_0 , is_uart_rx_b6_1 , is_uart_rx_b5_1, is_uart_rx_b4_1,
                              is_uart_rx_b3_1 , is_uart_rx_b2_1, is_uart_rx_b1_0, is_uart_rx_b0_1};
wire [7:0] debug_NOT_test; //~ 0x7E
assign debug_NOT_test[7:0] = {is_uart_rx_b7_0 , is_uart_rx_b6_1 , is_uart_rx_b5_1, is_uart_rx_b4_1,
                              is_uart_rx_b3_1 , is_uart_rx_b2_1, is_uart_rx_b1_1, is_uart_rx_b0_0};
wire [7:0] debug_DEL_test; // DEL 0x7F
assign debug_DEL_test[7:0] = {is_uart_rx_b7_0 , is_uart_rx_b6_1 , is_uart_rx_b5_1, is_uart_rx_b4_1,
                              is_uart_rx_b3_1 , is_uart_rx_b2_1 , is_uart_rx_b1_1, is_uart_rx_b0_1};
  
assign debug_is_CR = &debug_CR_test;  

wire debug_is_z;
assign debug_is_z = &debug_z_test; 
 
wire debug_is_LB;
assign debug_is_LB = &debug_LB_test;  

assign debug_is_OR = &debug_OR_test;  

wire debug_is_RB;
assign debug_is_RB = &debug_RB_test;  

assign debug_is_NOT = &debug_NOT_test;  
assign debug_is_DEL = &debug_DEL_test;  
reg [7:0] debug_reg;

assign debug_x = |i_data1;
assign debug_y = |i_data2;
assign debug_cin = i_OPsignal;
assign debug_i_sec_in = i_sec_in;
assign debug_i_buf_rdy = i_buf_rdy;
assign debug_o_rdy = o_rdy;
wire debug_o_data_start;
assign debug_o_data_start = l_o_data_start;
//wire debug_start_update;
//assign debug_start_update = l_start_update;
wire [7:0] debug_buf_hold;
assign debug_buf_hold[7:0] = l_buf_hold_wire[7:0];

wire [5:0] debug_l_minute_reg;
assign debug_l_minute_reg[5:0] = l_minute_reg[5:0];
wire [4:0] debug_l_hr_reg;
assign debug_l_hr_reg[4:0] = l_hr_reg[4:0];
wire [5:0] debug_l_sec_reg;
assign debug_l_sec_reg = l_sec_reg[5:0];

always @ (posedge i_clk_in)
begin

    if(i_rst) begin
        debug_reg[7:0] <= {2'h00};
    end else

    if (i_ctrl_signal) begin

            if(debug_is_z) begin
                debug_reg[7:0] <= 0; //local results           
            end else
            if(debug_is_OR) begin
                debug_reg[7:0] <= {1'b0,1'b0,1'b0, l_minute_pulse_wire, debug_l_sec_reg[3:0]}; //local results         
            end else
            if(debug_is_NOT) begin
                debug_reg[7:0] <= {1'b0,1'b0,1'b0, l_hr_pulse_wire, debug_l_minute_reg[3:0]}; //local results          
            end  else 
            if(debug_is_LB) begin //{
                debug_reg[7:0] <= {1'b0,1'b0,l_hr_pulse_wire, debug_l_hr_reg[3:0]};
            end else        
            if(debug_is_RB) begin //}
                debug_reg[7:0] <= {1'b0,1'b0, is_59_min, debug_l_minute_reg[3:0]};
            end 
            else 
            begin
                debug_reg[7:0] <= {2'hFF};
            end 
    
    end 
    
    else begin

        debug_reg[0] <= debug_i_sec_in;
        
        if(debug_i_buf_rdy)
        debug_reg[1] <= 1'b1;
        debug_reg[2] <= debug_i_buf_rdy;
        
        if(debug_o_rdy)
        debug_reg[3] <= 1'b1;
        debug_reg[4] <= debug_o_rdy;
        
        debug_reg[7:5] <= {1'b0,1'b0,1'b0};  //results drive to interface
    end
end

assign o_debug_led[7:0] = debug_reg[7:0];

endmodule
         

