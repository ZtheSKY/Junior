`default_nettype none

module thinpad_top(
    input wire clk_main,           //主时钟输入
    input wire clk_11M0592,       //11.0592MHz 时钟输入（备用，可不用）

    input wire clock_btn,         //BTN5手动时钟按钮开关，带消抖电路，按下时为1
    input wire reset_btn,         //BTN6手动复位按钮开关，带消抖电路，按下时为1

    input  wire[3:0]  touch_btn,  //BTN1~BTN4，按钮开关，按下时为1
    input  wire[31:0] dip_sw,     //32位拨码开关，拨到“ON”时为1
    output wire[15:0] leds,       //16位LED，输出时1点亮
    output wire[7:0]  dpy0,       //数码管低位信号，包括小数点，输出1点亮
    output wire[7:0]  dpy1,       //数码管高位信号，包括小数点，输出1点亮

    //BaseRAM信号
    inout wire[31:0] base_ram_data,  //BaseRAM数据，低8位与CPLD串口控制器共享
    output wire[19:0] base_ram_addr, //BaseRAM地址
    output wire[3:0] base_ram_be_n,  //BaseRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output wire base_ram_ce_n,       //BaseRAM片选，低有效
    output wire base_ram_oe_n,       //BaseRAM读使能，低有效
    output wire base_ram_we_n,       //BaseRAM写使能，低有效

    //ExtRAM信号
    inout wire[31:0] ext_ram_data,  //ExtRAM数据
    output wire[19:0] ext_ram_addr, //ExtRAM地址
    output wire[3:0] ext_ram_be_n,  //ExtRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output wire ext_ram_ce_n,       //ExtRAM片选，低有效
    output wire ext_ram_oe_n,       //ExtRAM读使能，低有效
    output wire ext_ram_we_n,       //ExtRAM写使能，低有效

    //直连串口信号
    output wire txd,  //直连串口发送端
    input  wire rxd,  //直连串口接收端

    //Flash存储器信号，参考 JS28F640 芯片手册
    output wire [22:0]flash_a,      //Flash地址，a0仅在8bit模式有效，16bit模式无意义
    inout  wire [15:0]flash_d,      //Flash数据
    output wire flash_rp_n,         //Flash复位信号，低有效
    output wire flash_vpen,         //Flash写保护信号，低电平时不能擦除、烧写
    output wire flash_ce_n,         //Flash片选信号，低有效
    output wire flash_oe_n,         //Flash读使能信号，低有效
    output wire flash_we_n,         //Flash写使能信号，低有效
    output wire flash_byte_n,       //Flash 8bit模式选择，低有效。在使用flash的16位模式时请设为1

    //图像输出信号
    output wire[2:0] video_red,    //红色像素，3位
    output wire[2:0] video_green,  //绿色像素，3位
    output wire[1:0] video_blue,   //蓝色像素，2位
    output wire video_hsync,       //行同步（水平同步）信号
    output wire video_vsync,       //场同步（垂直同步）信号
    output wire video_clk,         //像素时钟输出
    output wire video_de           //行数据有效信号，用于区分消隐区
);
   
wire        req_base_ram;
wire        wr_base_ram;
wire [31:0] addr_base_ram;
wire        addr_ok_base_ram; 
wire        data_ok_base_ram; 
wire [31:0] rdata_base_ram; 
wire [31:0] wdata_base_ram;

wire        req_ext_ram;
wire [31:0] addr_ext_ram;
wire        addr_ok_ext_ram; 
wire        data_ok_ext_ram; 
wire [31:0] wdata_ext_ram;


wire        run; // calculate begin signal
wire [31:0] x;    // 32-bit x 
wire [31:0] y;     // 32-bit y
wire        calculate_signed;
wire [63:0] result;    //64-bit hign result
wire        complete;    // calculate done signal
wire [15:0] calculate_cnt;
wire [19:0] clk_cnt;
assign leds[15:0] = clk_cnt[19:4];
assign {dpy1[7:0],dpy0[7:0]} = (calculate_cnt !== 5000) ? 16'hffff:16'b00000000_00010010;
    


sram_ctrl33 base_ram_ctrl(
   .clk             (clk_main        ),
   .req             (req_base_ram   ),
   .wr              (wr_base_ram    ),
   .size            (2'b10          ),
   .wstrb           (4'b0000        ),

   .address_input   (addr_base_ram  ),
   .data_fsm_to_sram(wdata_base_ram),
   .addr_ok         (addr_ok_base_ram),
   .data_ok         (data_ok_base_ram),
   .data_sram_to_fsm(rdata_base_ram ),

   .address_to_sram_output(base_ram_addr),
   .we_to_sram_output(base_ram_we_n),
   .oe_to_sram_output(base_ram_oe_n),
   .ce_to_sram_output(base_ram_ce_n),
   .be_to_sram_output(base_ram_be_n),
   .data_from_to_sram_input_output(base_ram_data),

   .busy_signal_output()
);

sram_ctrl33 ext_ram_ctrl(
   .clk             (clk_main        ),
   .req             (req_ext_ram    ),
   .wr              (1'b1           ),
   .size            (2'b10          ),
   .wstrb           (4'b0000        ),

   .address_input   (addr_ext_ram   ),
   .data_fsm_to_sram(wdata_ext_ram  ),
   .addr_ok         (addr_ok_ext_ram),
   .data_ok         (data_ok_ext_ram),
   .data_sram_to_fsm(               ),

   .address_to_sram_output(ext_ram_addr),
   .we_to_sram_output(ext_ram_we_n),
   .oe_to_sram_output(ext_ram_oe_n),
   .ce_to_sram_output(ext_ram_ce_n),
   .be_to_sram_output(ext_ram_be_n),
   .data_from_to_sram_input_output(ext_ram_data),
//   .data_from_to_sram_input_output(),
   .busy_signal_output()
);
//    assign ext_ram_data =32'h12345678;
ALU_ctrl multiplier_ctrl(
    .calculate_clk      (clk_main),
    .resetn             (!reset_btn),
    .req_base_ram       (req_base_ram),
    .wr_base_ram        (wr_base_ram),
    .addr_base_ram      (addr_base_ram),
    .base_ram_addr_ok   (addr_ok_base_ram),
    .base_ram_data_ok   (data_ok_base_ram),
    .rdata_base_ram     (rdata_base_ram),
    .wdata_base_ram     (wdata_base_ram),
    .req_ext_ram        (req_ext_ram),
    .addr_ext_ram       (addr_ext_ram),
    .ext_ram_addr_ok    (addr_ok_ext_ram),
    .ext_ram_data_ok    (data_ok_ext_ram),
    .wdata_ext_ram      (wdata_ext_ram),
    .run                (run),
    .x                  (x),
    .y                  (y),
    .sign               (calculate_signed),
    .a                  (result[63:32]),
    .b                  (result[31:0]),
    .complete           (complete),
    .calculate_cnt      (calculate_cnt),
    .clk_cnt            (clk_cnt)
);
mul multiplier(
    .mul_clk            (clk_main),
    .resetn             (!reset_btn),
    .run                (run),
    .x                  (x),
    .y                  (y),
    .mul_signed         (calculate_signed),
    .result             (result),
    .complete           (complete)
);

endmodule
