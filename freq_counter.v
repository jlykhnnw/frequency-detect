
module freq_counter #(
parameter WIDTH = 16
)(
	input wire					Clk_ref_i	,
	input wire					Clk_test_i	,
	input wire					Start_i		,
	input wire					Rst_n_i		,
    input  wire			    	SCAN_MODE_IN	    ,
    input  wire			    	SCAN_CLK		    ,
    input  wire 		    	SCAN_RSTN		    ,  
	input wire	[WIDTH-1:0] 	C			,
	output wire	[WIDTH-1:0] 	result		,
	output wire					Finish_o					
);
// machine
parameter IDLE = 3'b000;
parameter WORK = 3'b001;

//internal signals
reg [2:0]		c_state;
reg [2:0]		n_state;
reg [WIDTH-1:0] counter_ref;
reg [WIDTH-1:0] counter_test;
reg start;
reg finish;

wire c_state0_delay;
wire c_state0_ddelay;
reg	 c_state0_dddelay;
wire counter_test_finish;
wire [WIDTH-1:0] gray_counter_test;

wire [WIDTH-1:0] gray_counter_test_delay;
wire [WIDTH-1:0]gray_counter_test_ddelay;
reg  [WIDTH-1:0]gray_counter_test_dddelay;
wire counter_test_finish_delay;
wire counter_test_finish_ddelay;
reg  counter_test_finish_dddelay;
wire finish_delay;
reg exception_finish;
reg c_state0_is_sampled;
wire c_state0_is_sampled_delay;


/////////////////////////////////////////
////////////////state machine////////////
//n_state
always@(*)begin
	case(c_state)
		IDLE	: n_state = start ? WORK : IDLE; 
		WORK	: n_state = finish? IDLE : WORK;
		default	: n_state = IDLE;
	endcase
end

//for ScanChain
wire	Clk_ref_i_muxed = SCAN_MODE_IN ? SCAN_CLK : Clk_ref_i;
wire	rstn_muxed = SCAN_MODE_IN ? SCAN_RSTN : Rst_n_i;	
//c_state
always@(posedge Clk_ref_i_muxed or negedge rstn_muxed) begin
	if(~rstn_muxed)
		c_state <= IDLE;
	else
		c_state <= n_state;
end
////////////////state machine////////////
/////////////////////////////////////////

////////////////////////////////////////
///ref clock domain/////////////////////

//start
always@(posedge Clk_ref_i_muxed or negedge rstn_muxed) begin
	if(~rstn_muxed)
		start <= 1'b0;
	else if(Start_i)
		start <= 1'b1;
	else
		start <= 1'b0;
end

//finish
always@(posedge Clk_ref_i_muxed or negedge rstn_muxed) begin
	if(~rstn_muxed)
		finish <= 1'b0;
	else if(counter_ref == 1)
		finish <= 1'b1;
	else
		finish <= 1'b0;
end

//counter_ref
always@(posedge Clk_ref_i_muxed or negedge rstn_muxed) begin
	if(~rstn_muxed)
		counter_ref <= C;
	else if(Start_i)
		counter_ref <= C;
	else if(start || (c_state==WORK))
		counter_ref <= counter_ref - 1;
	else;
end

//wk modify add the finish condition
sync #(.WIDE(1)) x_sync_c_state0_is_sampled(
	.clk			(Clk_ref_i		),
	.rst_n		    (Rst_n_i	    ),
	.SCAN_MODE_IN	(SCAN_MODE_IN   ),
	.SCAN_CLK	    (SCAN_CLK	    ),
	.SCAN_RSTN	    (SCAN_RSTN	    ),
	.in				(c_state0_is_sampled),
	.out			(c_state0_is_sampled_delay)
);

//wk modify add the finish condition
sync #(.WIDE(1)) x_sync_finish(
	.clk			(Clk_ref_i),
	.rst_n		    (Rst_n_i	    ),
	.SCAN_MODE_IN	(SCAN_MODE_IN   ),
	.SCAN_CLK	    (SCAN_CLK	    ),
	.SCAN_RSTN	    (SCAN_RSTN	    ),
	.in				(finish			),
	.out			(finish_delay	)
);

//wk modify add the finish condition
always@(posedge Clk_ref_i_muxed or negedge rstn_muxed)begin
	if(~rstn_muxed)
		exception_finish <= 1'b0;
	else if((finish_delay==1'b1) && (c_state0_is_sampled_delay == 1'b0))
		exception_finish <= 1'b1;
	else
		exception_finish <= 1'b0;
end

///ref clock domain/////////////////////
////////////////////////////////////////


////////////////////////////////////////
///test clock domain////////////////////

sync #(.WIDE(1)) x_sync0(
	.clk			(Clk_test_i		),
	.rst_n		    (Rst_n_i	    ),
	.SCAN_MODE_IN	(SCAN_MODE_IN   ),
	.SCAN_CLK	    (SCAN_CLK	    ),
	.SCAN_RSTN	    (SCAN_RSTN	    ),
	.in				(c_state[0]		),
	.out			(c_state0_delay	)
);

sync #(.WIDE(1)) x_sync1(
	.clk			(Clk_test_i		),
	.rst_n		    (Rst_n_i	    ),
	.SCAN_MODE_IN	(SCAN_MODE_IN   ),
	.SCAN_CLK	    (SCAN_CLK	    ),
	.SCAN_RSTN	    (SCAN_RSTN	    ),
	.in				(c_state0_delay	),
	.out			(c_state0_ddelay)
);

//for ScanChain
wire	Clk_test_i_muxed = SCAN_MODE_IN ? SCAN_CLK : Clk_test_i;

//c_state0_dddelay
always@(posedge Clk_test_i_muxed or negedge rstn_muxed) begin
	if(~rstn_muxed)
		c_state0_dddelay <= 1'b0;
	else
		c_state0_dddelay <= c_state0_ddelay;
end

//counter_test_finish
//wk modify add the finish condition
assign counter_test_finish = ((~c_state0_ddelay)&(c_state0_dddelay)) | exception_finish;

//counter_test
always@(posedge Clk_test_i_muxed or negedge rstn_muxed) begin
	if(~rstn_muxed)
		counter_test <= 0;
	else if(c_state0_ddelay == 1'b0)
		counter_test <= 0;
	else if(c_state0_ddelay == 1'b1)
		counter_test <= counter_test + 1;
	else
		counter_test <= 0;
end

//gray_counter_test
assign gray_counter_test = (counter_test >> 1) ^ counter_test;

//wk modify add the finish condition
always@(posedge Clk_test_i_muxed or negedge rstn_muxed) begin
	if(~rstn_muxed)
		c_state0_is_sampled <= 1'b0;
	else if(c_state[0])
		c_state0_is_sampled <= 1'b1;
	else if(~c_state[0])
		c_state0_is_sampled <= 1'b0;
	else;
end

///test clock domain////////////////////
////////////////////////////////////////


////////////////////////////////////////
///ref clock domain/////////////////////

sync #(.WIDE(WIDTH)) x_sync2(
	.clk			(Clk_ref_i		),
	.rst_n		    (Rst_n_i	    ),
	.SCAN_MODE_IN	(SCAN_MODE_IN   ),
	.SCAN_CLK	    (SCAN_CLK	    ),
	.SCAN_RSTN	    (SCAN_RSTN	    ),
	.in				(gray_counter_test),
	.out			(gray_counter_test_delay)
);

sync #(.WIDE(WIDTH)) x_sync3(
	.clk			(Clk_ref_i		),
	.rst_n		    (Rst_n_i	    ),
	.SCAN_MODE_IN	(SCAN_MODE_IN   ),
	.SCAN_CLK	    (SCAN_CLK	    ),
	.SCAN_RSTN	    (SCAN_RSTN	    ),
	.in				(gray_counter_test_delay),
	.out			(gray_counter_test_ddelay)
);

//gray_counter_test_dddelay
always@(posedge Clk_ref_i_muxed or negedge rstn_muxed) begin
	if(~rstn_muxed)
		gray_counter_test_dddelay <= 0;
	else if(counter_test_finish_ddelay)
		gray_counter_test_dddelay <= gray_counter_test_ddelay;
	else;
end

//result
assign  result[WIDTH-1] = gray_counter_test_dddelay[WIDTH-1];
genvar i;
generate
	for(i = 0; i < WIDTH-1; i = i + 1) begin
        assign result[i] = ^(gray_counter_test_dddelay >> i);
	end
endgenerate


sync #(.WIDE(1)) x_sync4(
	.clk			(Clk_ref_i		),
	.rst_n		    (Rst_n_i	    ),
	.SCAN_MODE_IN	(SCAN_MODE_IN   ),
	.SCAN_CLK	    (SCAN_CLK	    ),
	.SCAN_RSTN	    (SCAN_RSTN	    ),
	.in				(counter_test_finish),
	.out			(counter_test_finish_delay)
);

sync #(.WIDE(1)) x_sync5(
	.clk			(Clk_ref_i		),
	.rst_n		    (Rst_n_i	    ),
	.SCAN_MODE_IN	(SCAN_MODE_IN   ),
	.SCAN_CLK	    (SCAN_CLK	    ),
	.SCAN_RSTN	    (SCAN_RSTN	    ),
	.in				(counter_test_finish_delay),
	.out			(counter_test_finish_ddelay)
);

//counter_test_finish_dddelay
always@(posedge Clk_ref_i_muxed or negedge rstn_muxed) begin
	if(~rstn_muxed)
		counter_test_finish_dddelay <= 1'b0;
	else
		counter_test_finish_dddelay <= counter_test_finish_ddelay;
end

//Finish_o
assign Finish_o = (~counter_test_finish_ddelay)&counter_test_finish_dddelay;

///ref clock domain/////////////////////
////////////////////////////////////////

endmodule

