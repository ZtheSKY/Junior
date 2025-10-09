module ALU_ctrl (
    input  wire calculate_clk,                    // Clock signal
    input  wire resetn,                  // Active-high reset signal

    output reg  req_base_ram,               // Request to base ram signal
    output reg  req_ext_ram,              // Request to ext ram signal
    
    output reg  [31:0] addr_base_ram,
    output reg         wr_base_ram,
    input  wire        base_ram_addr_ok,       // Base RAM address OK signal  
    input  wire        base_ram_data_ok,       // Base RAM data OK signal    
    input  wire [31:0] rdata_base_ram,  // Read data from base RAM
    output reg  [31:0] wdata_base_ram,   // Write data to base RAM

    output reg  [31:0] addr_ext_ram,
    input  wire ext_ram_addr_ok,        // Extended RAM address OK signal
    input  wire ext_ram_data_ok,        // Extended RAM data OK signal
    output reg  [31:0] wdata_ext_ram,   // Write data to extended RAM;
    
    output wire        run,    // calculate begin signal
    output wire [31:0] x,        // 32-bit x 
    output wire [31:0] y,         // 32-bit y
    output wire        sign,            // sign
    input  wire [31:0] a,        // hign 32-bit of result
    input  wire [31:0] b,       // low 32-bit of result
    input  wire        complete,      // calculate done signal
    output reg  [15:0] calculate_cnt,
    output reg  [19:0] clk_cnt
);
    wire reset;
    assign reset = ! resetn;

    parameter init_read_addr  = 32'h8000_0000;
    parameter init_write_addr = 32'h8040_0000;
    parameter calculate_total = 16'd5000;
//    reg [19:0] clk_cnt;
    reg [1:0] run_ctrl;
    localparam [3:0]
        IDLE    = 4'b0000,
        READ    = 4'b0001,
        CAL     = 4'b0010,
        WRITE   = 4'b0011,
        STOP    = 4'b0100,
        W_RES   = 4'b1000;


    reg  [ 3:0] state;
    reg  [ 2:0] read_state , write_state;
    reg  [64:0] temp_calculate;            //{sign,y,x}
    reg         read_done, write_done;
    reg  [31:0] h_temp, l_temp;
    initial begin
        clk_cnt <= 20'b0;
        run_ctrl <= 2'd0;
    end

    always @(posedge calculate_clk) begin
        if (reset) begin
            clk_cnt <= 20'b0;
        end else  if ((calculate_cnt !== calculate_total )&& run_ctrl ==2'b1) begin 
            if (clk_cnt < 20'hfffff) begin
                clk_cnt <= clk_cnt + 1 ;
                end
        end
    end

    always @(posedge calculate_clk) begin
        if (reset) begin
            // Reset all states and variables
            state <= IDLE;
            calculate_cnt<=20'b0;;
            run_ctrl<=2'd1;

            req_base_ram <= 1'b0;
            addr_base_ram <= init_read_addr;
            wr_base_ram <= 1'b0;
            wdata_base_ram <= 32'd0;
            temp_calculate <= 65'd0;
            read_state <= 3'd0;
            read_done <= 1'b0;

            req_ext_ram <= 1'b0;
            addr_ext_ram <= init_write_addr;
            wdata_ext_ram <= 32'd0;
            write_state <= 3'd0;
            write_done <= 1'b0;
            h_temp<=32'b0;
            l_temp<=32'b0;

        end else if (run_ctrl == 2'd1 | run_ctrl == 2'd2) begin
            case (state)
                IDLE: begin
                    if (!reset) begin
                        if(calculate_cnt == calculate_total ) begin
                            state <= W_RES ;//WRITE TIME COST
                            run_ctrl <= 2'd2;
                        end
                        else begin
                            state <= READ;
                            read_state <= 3'd0;
                            read_done <= 1'b0;
                        end
                    end
                end

                READ: begin
                    case (read_state)
                        3'd0: begin
                            req_base_ram <= 1'b1;
                            wr_base_ram <= 1'b0;        //read cycle wr = 0
                            if (base_ram_addr_ok) begin
                                req_base_ram <= 1'b0;
                                read_state <= 3'd1;
                            end
                        end

                        3'd1: begin
                            if (base_ram_data_ok) begin
                                temp_calculate[31:0] <= rdata_base_ram[31:0];    // Get 32 x[31:0]
                                addr_base_ram <= addr_base_ram + 4;
                                req_base_ram <= 1'b1;
                                read_state <= 3'd2;
                            end
                        end

                        3'd2: begin
                            if (base_ram_addr_ok) begin
                                req_base_ram <= 1'b0;
                                read_state <= 3'd3;
                            end
                        end

                        3'd3: begin
                            if (base_ram_data_ok) begin
                                temp_calculate[63:32] <= rdata_base_ram[31:0];  // Get 32 y[63:32]
                                addr_base_ram <= addr_base_ram + 4;
                                req_base_ram <= 1'b1;
                                read_state <= 3'd4;
                            end
                        end

                        3'd4: begin
                            if(base_ram_addr_ok) begin
                                req_base_ram <= 1'b0;
                                read_state <= 3'd5;
                            end
                        end 

                        3'd5: begin
                            if (base_ram_data_ok) begin
                                temp_calculate[64] <= rdata_base_ram[0];  // Get sign
                                addr_base_ram <= addr_base_ram + 4;
                                read_done <= 1'b1;
                                read_state <= 3'd6;     //read done
                                state <= CAL;
                            end
                        end

                    endcase
                end

                CAL: begin
                   if (complete) begin
                        h_temp <= a;
                        l_temp <= b;
                        state <= WRITE;
                        write_state <= 3'd0;
                        write_done <= 1'b0;
                    end
                end

                WRITE: begin
                    // Handle the write process to ext RAM
                    case (write_state)
                        3'd0: begin
                            req_ext_ram <= 1'b1;
                            wdata_ext_ram <= l_temp;
                            if (ext_ram_addr_ok) begin
                                req_ext_ram <= 1'b0;
                                write_state <= 3'd1;
                            end
                        end

                        3'd1: begin
                            if (ext_ram_data_ok) begin
                                addr_ext_ram <= addr_ext_ram + 4;
                                req_ext_ram <= 1'b1;
                                wdata_ext_ram <= h_temp;
                                write_state <= 3'd2;
                            end
                        end
  
                        3'd2: begin
                            if (ext_ram_addr_ok) begin
                                req_ext_ram <= 1'b0;
                                write_state <= 3'd3;
                            end
                        end

                        3'd3: begin
                            if (ext_ram_data_ok) begin
                                write_done <= 1'b1;
                                addr_ext_ram <= addr_ext_ram + 4;
                                calculate_cnt <= calculate_cnt +1;
                                state <= IDLE;
                            end
                        end
                    endcase
                end
                
                W_RES: begin     //write clk_cnt to base ram
                    req_base_ram <= 1'b1;
                    wr_base_ram <= 1'b1;
                    addr_base_ram <= init_read_addr;
                    wdata_base_ram[31:0] <= {12'b0,clk_cnt[19:0]};
                    if(base_ram_addr_ok) begin
                        req_base_ram <= 1'b0;
                    end
                    if(base_ram_data_ok) begin
                        state <= STOP;
                    end                
                end
                
                STOP:begin 
                    req_base_ram <= 1'b0;
                    req_ext_ram <= 1'b0;
                    run_ctrl <= 2'd0;
                end
            endcase
        end
    end
    
    assign run          = (state == CAL) ? 1'b1 : 1'b0;
    assign x            = (run) ? temp_calculate[31: 0]: 32'bz;
    assign y            = (run) ? temp_calculate[63:32]: 32'bz;
    assign calculate_signed   = (run) ? temp_calculate[64]   :  1'bz;


endmodule
