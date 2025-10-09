`timescale 1ps / 1ps

module mul_tb;

	// Inputs
	reg mul_clk;
	reg resetn;
	reg mul_signed;
	reg [31:0] x;
	reg [31:0] y;

	// Outputs
	wire signed [63:0] result;
    wire complete;
	// Instantiate the Unit Under Test (UUT)
	mul uut (
		.mul_clk    (mul_clk), 
		.resetn     (resetn), 
        .run        (mul),
		.mul_signed (mul_signed), 
		.x          (x), 
		.y          (y), 
		.result     (result),
        .complete   (complete)
	);

	initial begin
		// Initialize Inputs
		mul_clk = 0;
		resetn = 0;
		mul_signed = 0;
		x = 0;
		y = 0;
		#100;
		resetn = 1;
	end
	always #5 mul_clk = ~mul_clk;

//产生乘法命令，正在进行乘法
reg mul_is_run;
integer wait_clk;
initial
begin
    mul_is_run <= 1'b0;
    forever
    begin
	    @(posedge mul_clk);
        if (!resetn || complete)
	    begin
	        mul_is_run <= 1'b0;
		    wait_clk <= {$random}%4;
	    end
	    else
	    begin
	        repeat (wait_clk)@(posedge mul_clk);
	        mul_is_run <= 1'b1;
			wait_clk <= 0;
	    end
    end
end

//随机生成有控制信号与数据
assign mul = mul_is_run;
always @(posedge mul_clk)
begin
    if (!resetn || complete)
	begin
		mul_signed <= {$random}%2; //$random为系统任务，产生一个随机的32位有符号数
		x          <= $random; 
		y          <= $random;  
	end
end

//参考结果
wire signed [65:0] result_ref;
wire signed [32:0] x_e;
wire signed [32:0] y_e;
assign x_e        = {mul_signed & x[31], x};
assign y_e        = {mul_signed & y[31], y};
assign result_ref = x_e * y_e;
wire ok;
assign ok         = (result_ref[63:0] == result[63:0]);

always @(posedge mul_clk)
begin
    if (complete && mul) //计算完成
    begin
	    if (ok)
        begin
		    $display("[time@%t] Right: x = %d, y = %d, signed = %d, result = %d, result_ref = %d, OK = %b", $time, x_e, y_e, mul_signed, $signed({{mul_signed & result[63]}, result}), result_ref, ok);
			$display("End in %d clk!", time_out + 1);
		end
		else
		begin
		    $display("[time@%t] Error: x = %d, y = %d, signed = %d, result = %d, result_ref = %d, OK = %b", $time, x_e, y_e, mul_signed, $signed({{mul_signed & result[63]}, result}), result_ref, ok);
			$display("End in %d clk!", time_out + 1);
		end
    end
end
reg [6:0] time_out;
always @(posedge mul_clk)
begin
    if (!resetn || !mul_is_run || complete)
	begin
	    time_out <= 6'd0;
	end
    else
    begin
	    time_out <= time_out + 1'b1;
    end
end
endmodule