

module freq_detect #(
	parameter  WIDTH= 16,
	parameter  F0 	= 01
)(
	input  wire		Rst_n_i												,
	input  wire		Clk_ref_i											,
	input  wire		Clk_test_i										,
  input  wire		SCAN_MODE_IN									,
  input  wire		SCAN_CLK		 									,
  input  wire		SCAN_RSTN		 									,  
	input  wire		Start_i												,
	input  wire		[4:0]FullScaleInitial					,
	input  wire		[4:0]LowerBoundInitial				,
	input  wire		[4:0]UpperBoundInitial				,
	input  wire		[10:0]MagnifyInitial					,
	input  wire		[4:0]MagnifyUpperLimit				,
	output  reg 	[WIDTH-1:0]	FullScale					,
	output wire		[WIDTH-1:0]	FreqCounterResult	,			
	output  reg  	Finish_o											,
	output  reg		Warning_o											,
	output  reg		Stuck_o
);

reg  			Finish_o			;

//main state machine
parameter		IDLE 	= 3'b000;
parameter		PREPARE = 3'b100;
parameter		COUNTER = 3'b001;
parameter		DETECT 	= 3'b010;

//regs and wires
reg 			[2:0]		cstate				;
reg 			[2:0]		nstate				;
reg 			[WIDTH-1:0]	Magnify		;
reg 			[WIDTH-1:0]	UpperBound;
reg 			[WIDTH-1:0]	LowerBound;
reg				counter_start					;
reg				Start_i_delay1				;
wire			Start_i_pulse_p				;
wire 			counter_finish				;
wire			[WIDTH-1:0] MagnifyUpperLimit_EX;

//MagnifyUpperLimit_EX
assign MagnifyUpperLimit_EX = MagnifyUpperLimit << 10;

//for ScanChain
wire	Clk_ref_i_muxed = SCAN_MODE_IN ? SCAN_CLK : Clk_ref_i;
wire	rstn_muxed = SCAN_MODE_IN ? SCAN_RSTN : Rst_n_i;	

//Start_i_delay1
always@(posedge Clk_ref_i_muxed or negedge rstn_muxed) begin
	if(~rstn_muxed)
		Start_i_delay1 <= 1'b0;
	else
		Start_i_delay1 <= Start_i;
end

//Start_i_pulse_p
assign Start_i_pulse_p = Start_i&(~Start_i_delay1);


/////////////main state machine/////////////
//cstate
always@(posedge Clk_ref_i_muxed or negedge rstn_muxed) begin
	if(~rstn_muxed)
		cstate <= IDLE;
	else
		cstate <= nstate;
end

//nstate
always@(*)begin
	case(cstate)
		IDLE 	:	nstate = Start_i? PREPARE : IDLE;
		PREPARE	:	nstate = COUNTER;
	  	COUNTER :	nstate = counter_finish? DETECT : COUNTER;
	  	DETECT  :   nstate = ((FreqCounterResult == UpperBound || FreqCounterResult == LowerBound) && Magnify < MagnifyUpperLimit_EX)?  PREPARE : IDLE;
		default	:   nstate = IDLE;
	endcase
end

//counter_start
always@(posedge Clk_ref_i_muxed or negedge rstn_muxed) begin
	if(~rstn_muxed)
		counter_start <= 1'b0;
	else if(cstate == PREPARE)
		counter_start <= 1'b1;
	else
		counter_start <= 1'b0;
end

//UpperBound
always@(posedge Clk_ref_i_muxed or negedge rstn_muxed) begin
	if(~rstn_muxed)
		UpperBound <= 15;
	else if(cstate == PREPARE)
		UpperBound <= Magnify * UpperBoundInitial;
	else;
end

//LowerBound
always@(posedge Clk_ref_i_muxed or negedge rstn_muxed) begin
	if(~rstn_muxed)
		LowerBound <= 5;
	else if(cstate == PREPARE)
		LowerBound <= Magnify * LowerBoundInitial;
	else;
end

//FullScale
always@(posedge Clk_ref_i_muxed or negedge rstn_muxed) begin
	if(~rstn_muxed)
		FullScale <= 16;
	else if(cstate == PREPARE)
		FullScale <= Magnify * FullScaleInitial;
	else;
end

//Magnify
always@(posedge Clk_ref_i_muxed or negedge rstn_muxed) begin
	if(~rstn_muxed)
		Magnify <= 1;
	else if(Start_i_pulse_p)
		Magnify <= MagnifyInitial;
	else if(cstate == DETECT)
		if((FreqCounterResult == UpperBound || FreqCounterResult == LowerBound) && Magnify < MagnifyUpperLimit_EX)
			Magnify <= Magnify << 1;
		else;
	else;
end


//Finish_o
always@(posedge Clk_ref_i_muxed or negedge rstn_muxed) begin
	if(~rstn_muxed)
		Finish_o <= 1'b0;
	else if(cstate == DETECT)
		if(FreqCounterResult < UpperBound && FreqCounterResult > LowerBound)
			Finish_o <= 1'b1;
		else if(FreqCounterResult > UpperBound || FreqCounterResult < LowerBound)
			Finish_o <= 1'b1;
		else if(Magnify >= MagnifyUpperLimit_EX)
			Finish_o <= 1'b1;
		else
			Finish_o <= 1'b0;
	else
		Finish_o <= 1'b0;	
end


//Warning_o
always@(posedge Clk_ref_i_muxed or negedge rstn_muxed) begin
	if(~rstn_muxed)
		Warning_o <= 1'b0;
	else if(cstate == DETECT)
		if(FreqCounterResult > UpperBound || FreqCounterResult < LowerBound)
			Warning_o <= 1'b1;
		else if(Magnify >= MagnifyUpperLimit_EX)
			Warning_o <= 1'b1;
		else if(FreqCounterResult < UpperBound && FreqCounterResult > LowerBound)
			Warning_o <= 1'b0;
		else;
	else;
end

//Stuck_o
always@(posedge Clk_ref_i_muxed or negedge rstn_muxed)begin
	if(~rstn_muxed)
		Stuck_o <= 1'b0;
	else if(cstate == DETECT)
		if(FreqCounterResult <= (LowerBound>>3 + 1))
			Stuck_o <= 1'b1;
		else
			Stuck_o <= 1'b0;
	else;
end


/////////////////instance//////////////////
//freq_counter
freq_counter x_freq_counter(
	.Rst_n_i			(Rst_n_i),
	.Clk_ref_i		(Clk_ref_i),
	.Clk_test_i   (Clk_test_i),
	.SCAN_MODE_IN (SCAN_MODE_IN),
	.SCAN_CLK	    (SCAN_CLK),
	.SCAN_RSTN	  (SCAN_RSTN),
	.Start_i			(counter_start),
	.C						(FullScale),
	.result		    (FreqCounterResult),
	.Finish_o	    (counter_finish)
);

endmodule

