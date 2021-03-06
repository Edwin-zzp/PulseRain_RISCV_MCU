/*
###############################################################################
# Copyright (c) 2019, PulseRain Technology LLC 
#
# This program is distributed under a dual license: an open source license, 
# and a commercial license. 
# 
# The open source license under which this program is distributed is the 
# GNU Public License version 3 (GPLv3).
#
# And for those who want to use this program in ways that are incompatible
# with the GPLv3, PulseRain Technology LLC offers commercial license instead.
# Please contact PulseRain Technology LLC (www.pulserain.com) for more detail.
#
###############################################################################
*/

`include "common.vh"
`include "config.vh"

`default_nettype none


module mem_controller (

    //=======================================================================
    // clock / reset
    //=======================================================================

        input   wire                                                    clk,
        input   wire                                                    reset_n,
        input   wire                                                    sync_reset,

    //=======================================================================
    // memory interface
    //=======================================================================
        input  wire  [`MEM_ADDR_BITS - 1 : 0]                           mem_addr,
        input  wire                                                     mem_read_en,
        input  wire  [`XLEN_BYTES - 1 : 0]                              mem_write_en,
        input  wire  [`XLEN - 1 : 0]                                    mem_write_data,
        
        output wire  [`XLEN - 1 : 0]                                    mem_read_data,
        output wire                                                     mem_write_ack,
        output wire                                                     mem_read_ack,
        
        
        input  wire                                                     ext_dram_ack,
        input  wire  [`XLEN - 1 : 0]                                    ext_dram_mem_read_data,
        
        output wire  [`MEM_ADDR_BITS - 1 : 0]                           ext_dram_mem_addr,
        output wire                                                     ext_dram_mem_read_en,
        output wire                                                     ext_dram_mem_write_en,
        output wire  [`XLEN_BYTES - 1 : 0]                              ext_dram_mem_byte_enable,
        output wire  [`XLEN - 1 : 0]                                    ext_dram_mem_write_data,
        
        output wire                                                     dram_rw_pending,
        output wire  [`MEM_ADDR_BITS - 1 : 0]                           mem_addr_ack
        
);
    //=======================================================================
    // signal
    //=======================================================================
        wire                                              mem_sram0_dram1; 
        wire [15 : 0]                                     dout_high;
        wire [15 : 0]                                     dout_low;
        
        reg [15 : 0]                                      dout_high_d1;
        reg [15 : 0]                                      dout_low_d1;
        
        reg [15 : 0]                                      dout_high_d2;
        reg [15 : 0]                                      dout_low_d2;
        
        reg                                               mem_sram0_dram1_d1;
        reg                                               mem_read_en_d1;
        
        wire                                              sram_read_ack_pre;
        reg                                               sram_read_ack_pre_pre;
        reg                                               sram_read_ack;
        
        reg                                               sram_write_ack_pre;
        
        reg                                               sram_write_ack;
                
        wire                                              dram_ack;
        wire  [`XLEN - 1 : 0]                             dram_mem_read_data;
        
        reg   [`MEM_ADDR_BITS - 1 : 0]                    mem_read_addr_reg;
        
        
                
    //=======================================================================
    // SRAM
    //=======================================================================
        /* verilator lint_off UNSIGNED */
        assign mem_sram0_dram1 = (mem_addr >= (`SRAM_SIZE_IN_BYTES / 4)) ? 1'b1 : 1'b0; 
           
            generate 
                
                if (`SRAM_SIZE_IN_BYTES != 0) begin 
                    single_port_ram #(.ADDR_WIDTH (`SRAM_ADDR_BITS), .DATA_WIDTH (16), .HIGH1_LOW0(1) ) ram_high_i (
                        .addr (mem_addr [`SRAM_ADDR_BITS - 1 : 0]),
                        .din (mem_write_data [31 : 16]),
                        .write_en (mem_write_en[3 : 2] & {~mem_sram0_dram1, ~mem_sram0_dram1} ),
                        .clk (clk),
                        .dout (dout_high));

                    single_port_ram #(.ADDR_WIDTH (`SRAM_ADDR_BITS), .DATA_WIDTH (16), .HIGH1_LOW0(0) ) ram_low_i (
                        .addr (mem_addr[`SRAM_ADDR_BITS - 1 : 0]),
                        .din (mem_write_data [15 : 0]),
                        .write_en (mem_write_en[1 : 0] & {~mem_sram0_dram1, ~mem_sram0_dram1} ),
                        .clk (clk),
                        .dout (dout_low));
                end
            endgenerate

            /*

            single_port_ram_sim_high #(.ADDR_WIDTH (`SRAM_ADDR_BITS), .DATA_WIDTH (16) ) ram_high_i (
                .addr (mem_addr[`SRAM_ADDR_BITS - 1 : 0]),
                .din (mem_write_data [31 : 16]),
                .write_en (mem_write_en[3 : 2]),
                .clk (clk),
                .dout (dout_high));
              
            single_port_ram_sim_low #(.ADDR_WIDTH (`SRAM_ADDR_BITS), .DATA_WIDTH (16) ) ram_low_i (
                .addr (mem_addr[`SRAM_ADDR_BITS - 1 : 0]),
                .din (mem_write_data [15 : 0]),
                .write_en (mem_write_en[1 : 0]),
                .clk (clk),
                .dout (dout_low));
*/


       // assign mem_read_data = {dout_high, dout_low};
        assign mem_read_data = dram_ack ? dram_mem_read_data : {dout_high_d1, dout_low_d1};
       //  assign mem_read_data = {dout_high_d2, dout_low_d2};

        assign sram_read_ack_pre = mem_read_en_d1 & (~mem_sram0_dram1_d1);
        
        always @(posedge clk, negedge reset_n) begin : ack_proc
            if (!reset_n) begin
                sram_read_ack <= 0;
              //  sram_read_ack_pre <= 0;
                sram_read_ack_pre_pre <= 0;
                dout_high_d1 <= 0;
                dout_low_d1  <= 0;
                dout_high_d2 <= 0;
                dout_low_d2  <= 0;
                
                sram_write_ack <= 0;
                sram_write_ack_pre <= 0;
                
                mem_sram0_dram1_d1 <= 0;
                mem_read_en_d1 <= 0;
                
                mem_read_addr_reg <= 0;
                
            end else begin
               
                mem_sram0_dram1_d1 <= mem_sram0_dram1;
                mem_read_en_d1 <= mem_read_en;
                
               // sram_read_ack_pre <= mem_read_en & (~mem_sram0_dram1);
                sram_read_ack <= sram_read_ack_pre;
         
        //        sram_read_ack_pre_pre <= mem_read_en & (~mem_sram0_dram1);
          //      sram_read_ack_pre <= sram_read_ack_pre_pre;
            //    sram_read_ack <= sram_read_ack_pre;
                
            //    sram_read_ack <= mem_read_en & (~mem_sram0_dram1);
                
                dout_high_d1 <= dout_high;
                dout_low_d1  <= dout_low;
                
                dout_high_d2 <= dout_high_d1;
                dout_low_d2  <= dout_low_d1;
                
                sram_write_ack <= (|mem_write_en) & (~mem_sram0_dram1);
               
             //  sram_write_ack_pre <= (|mem_write_en) & (~mem_sram0_dram1);
             //  sram_write_ack <= sram_write_ack_pre;
             
                if (mem_read_en & (~mem_sram0_dram1) ) begin
                    mem_read_addr_reg <= mem_addr;
                end else if (ext_dram_mem_read_en) begin
                    mem_read_addr_reg <= ext_dram_mem_addr;
                end
                
            end
        end : ack_proc
        
        assign mem_addr_ack = mem_read_addr_reg;
        
       // assign sram_write_ack = (|mem_write_en) & (~mem_sram0_dram1);

    //=======================================================================
    // DRAM
    //=======================================================================
    
        assign mem_write_ack = sram_write_ack | dram_ack;
        assign mem_read_ack  = sram_read_ack | dram_ack;

        dram_rw_buffer dram_rw_buffer_i (
            .clk     (clk),
            .reset_n (reset_n),
     
            .dram_mem_addr     (mem_addr),
            .dram_mem_read_en  (mem_read_en & mem_sram0_dram1),
            .dram_mem_write_en ((|mem_write_en) & mem_sram0_dram1),
            
            .dram_mem_byte_enable (mem_write_en),
            .dram_mem_write_data  (mem_write_data),
            
            .ext_dram_ack (ext_dram_ack),
            .ext_dram_mem_read_data (ext_dram_mem_read_data),
            
            .ext_dram_mem_addr        (ext_dram_mem_addr),
            .ext_dram_mem_read_en     (ext_dram_mem_read_en),
            .ext_dram_mem_write_en    (ext_dram_mem_write_en),
            .ext_dram_mem_byte_enable (ext_dram_mem_byte_enable),
            .ext_dram_mem_write_data  (ext_dram_mem_write_data),
            .dram_ack                 (dram_ack),
            .dram_mem_read_data       (dram_mem_read_data),
            
            .dram_rw_pending          (dram_rw_pending)
        );
        
        
endmodule

`default_nettype wire