

module time_sync
  (input wb_clk_i, input rst_i,
   input cyc_i, input stb_i, input [2:0] adr_i,
   input we_i, input [31:0] dat_i, output [31:0] dat_o, output ack_o,
   input sys_clk_i, output [31:0] master_time_o,
   input pps_in, input exp_pps_in, output exp_pps_out,
   output reg int_o );
   
   wire [31:0] master_time_rcvd;
   reg [31:0]  master_time;
   reg [31:0]  delta_time;

   reg 	       internal_tick;
   wire        sync_rcvd, pps_ext;
   reg [31:0]  tick_time, tick_time_wb;
   wire        tick_free_run;
   reg 	       tick_int_enable, tick_source, external_sync;
   reg [31:0]  tick_interval;
   
   // Generate master time
   always @(posedge sys_clk_i)
     if(rst_i)
       master_time <= 0;
     else if(external_sync & sync_rcvd)
       master_time <= master_time_rcvd + delta_time;
     else
       master_time <= master_time + 1;
   assign      master_time_o = master_time;
   
   time_sender time_sender
     (.clk(sys_clk_i),.rst(rst_i),
      .master_time(master_time),
      .send_sync(internal_tick),
      .exp_pps_out(exp_pps_out) );

   time_receiver time_receiver
     (.clk(sys_clk_i),.rst(rst_i),
      .master_time(master_time_rcvd),
      .sync_rcvd(sync_rcvd),
      .exp_pps_in(exp_pps_in) );

   assign     ack_o = stb_i;

   always @(posedge wb_clk_i)
     if(rst_i)
       begin
	  tick_source <= 0;
	  tick_int_enable <= 0;
	  external_sync <= 0;
	  tick_interval <= 100000-1;  // default to 1K times per second
	  delta_time <= 0;
       end
     else if(stb_i & we_i)
       if(adr_i[2:0] == 2)
	 delta_time <= dat_i;
       else if(adr_i[2:0] == 1)
	 tick_interval <= dat_i;
       else
	 begin
	    tick_source <= dat_i[0];
	    tick_int_enable <= dat_i[1];
	    external_sync <= dat_i[2];
	 end
   
   always @(posedge sys_clk_i)
     if(internal_tick)
       tick_time <= master_time;

   always @(posedge wb_clk_i)
     tick_time_wb <= tick_time;
   
   assign dat_o = tick_time_wb;

   always @(posedge sys_clk_i)
     internal_tick <= (tick_source == 0) ? tick_free_run : pps_ext;

   reg [31:0] counter;
   always @(posedge sys_clk_i)
     if(rst_i)
       counter <= 0;
     else if(tick_free_run)
       counter <= 0;
     else
       counter <= counter + 1;
   assign     tick_free_run = (counter >= tick_interval);
   
   // Properly Latch and edge detect External PPS input
   reg 	      pps_in_d1, pps_in_d2;
   always @(posedge sys_clk_i)
     begin
	pps_in_d1 <= pps_in;
	pps_in_d2 <= pps_in_d1;
     end
   assign pps_ext = pps_in_d1 & ~pps_in_d2;

   // Need to register this?
   reg 	  internal_tick_d1;
   always @(posedge sys_clk_i) internal_tick_d1 <= internal_tick;
   
   always @(posedge wb_clk_i)
     if(rst_i)
       int_o <= 0;
     else if(tick_int_enable & (internal_tick | internal_tick_d1))
       int_o <= 1;
     else
       int_o <= 0;
   
endmodule // time_sync
