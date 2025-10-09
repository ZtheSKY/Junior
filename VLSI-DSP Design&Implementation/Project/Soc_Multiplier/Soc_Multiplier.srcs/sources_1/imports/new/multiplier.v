//`define Algorithm_1
`define Algorithm_2


module mul
(
    input wire mul_clk,       // 时钟信号
    input wire resetn,        // 复位信号，低电平有效
    input wire run,           // 开始运算信号
    input wire mul_signed,    // 有符号乘法标志
    input wire [31:0] x,
    input wire [31:0] y,
    output reg [63:0] result,
    output reg complete       // 完成信号
);

`ifdef Algorithm_1

//design 2 booth radix-2

reg signed [66:0] x_e;
reg signed [66:0] x_inv;
reg signed [66:0] temp;
reg [5:0] cnt;
always @(posedge mul_clk or negedge resetn) begin
    if (!resetn) begin
        complete <= 0;
        x_e <= 67'd0;
        x_inv <= 67'd0;
        temp <= 67'd0;
        cnt <= 6'd0;
    end else begin
        if (run) begin
            cnt <= cnt + 1;
            if (cnt == 0) begin
                x_e <= {mul_signed & x[31], x, 34'd0};
                temp <= {{mul_signed & y[31]}, y, 1'b0};
                x_inv <= ~{mul_signed & x[31], x, 34'd0} + 1;
            end else if (!complete) begin
                case (temp[1:0])
                    2'b01: begin
                        temp <= (temp + x_e) >>> 1;
                    end
                    2'b10: begin
                        temp <= (temp + x_inv) >>> 1;
                    end
                    default: temp <= temp >>> 1;
                endcase 
            end
            if (cnt == 34) begin
                complete <= 1;
                result <= temp[64:1];
                temp <= 66'd0;
            end
        end else begin
            complete <= 0;
            result <= 64'd0;
            x_e <= 67'd0;
            x_inv <= 67'd0;
            cnt <= 6'd0;
        end
    end
end

`elsif Algorithm_2

//design booth radix-4

reg signed [68:0] x_e;
reg signed [68:0] x_inv;
reg signed [68:0] temp;
reg [4:0] cnt;
always @(posedge mul_clk or negedge resetn) begin
    if (!resetn) begin
        complete <= 0;
        x_e <= 69'd0;
        x_inv <= 69'd0;
        temp <= 69'd0;
        cnt <= 5'd0;
    end else begin
        if (run) begin
            cnt <= cnt + 1;
            if (cnt == 0) begin
                x_e <= {{2{mul_signed & x[31]}}, x, 35'd0};
                temp <= {{2{mul_signed & y[31]}}, y, 1'b0};
                x_inv <= ~{{2{mul_signed & x[31]}}, x, 35'd0} + 1;
            end else if (!complete) begin
                case (temp[2:0])
                    3'b001,3'b010: begin
                        temp <= (temp + x_e) >>> 2;
                    end
                    3'b011: begin
                        temp <= (temp + (x_e <<< 1)) >>> 2;
                    end
                    3'b100: begin
                        temp <= (temp + (x_inv <<< 1)) >>> 2;
                    end
                    3'b101,3'b110: begin
                        temp <= (temp + x_inv) >>> 2;
                    end                    
                    default: temp <= temp >>> 2;
                endcase 
            end
            if (cnt == 18) begin
                complete <= 1;
                result <= temp[64:1];
                temp <= 69'd0;
            end
        end else begin
            complete <= 0;
            result <= 64'd0;
            x_e <= 69'd0;
            x_inv <= 69'd0;
            cnt <= 5'd0;
        end
    end
end

`endif
endmodule