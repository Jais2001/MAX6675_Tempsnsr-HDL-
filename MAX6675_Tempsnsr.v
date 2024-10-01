// 50MHz clock frequency - 20ns 1 clock
module MAX6675_Tempsnsr(
    input wire i_clk,
    input wire i_reset,

    output wire [15:0]o_data, // data o/p of module

    //control signals
    output wire o_CS,
    output wire o_SPI_CLk,
    input wire i_SPI_MISO
);

reg r_CS;

reg [15:0]r_o_data;
reg [15:0]r_op_data;

reg r_TX_Dev;

reg [2:0]r_byte_counter; // a counter for storing 2 bytes

wire w_RX_DV;
wire[7:0] w_op_data; // 1 byte data form SPI master
wire w_Tx_Ready;
   
assign o_CS         = r_CS;
assign o_data       = r_op_data;

reg[4:0]  MAX6675_State;

localparam initial_state = 5'd0;
localparam control_state = 5'd1;
localparam wait_TX_ready = 5'd2;
localparam start_read    = 5'd3;
localparam get_data      = 5'd4;
localparam send_data     = 5'd5;
localparam stop_read     = 5'd6;


SPI_Master #(.SPI_MODE(0),.CLKS_PER_HALF_BIT(7)) spi(
    .i_Rst_L(i_reset),
    .i_Clk (i_clk),
    .i_TX_Byte(),
    .i_TX_DV(r_TX_Dev),
    .o_TX_Ready(w_Tx_Ready),
    .o_RX_DV(w_RX_DV),
    .o_RX_Byte(w_op_data),
    .o_SPI_Clk(o_SPI_CLk),
    .i_SPI_MISO(i_SPI_MISO)
);

reg[2:0] r_power_up_counter;

always @(posedge i_clk or negedge i_reset) begin
    if (~i_reset) begin
        r_CS <= 1;
        r_o_data <= 0;
        r_power_up_counter <= 0;
        r_byte_counter <= 0;
        MAX6675_State <= initial_state;
    end else begin
        r_TX_Dev <= 0;
        case (MAX6675_State) 
            initial_state:begin // waiting for 100ns(5 clock) just to boot up the sensor
                if (r_power_up_counter < 3'd5) begin
                    MAX6675_State <= initial_state;
                    r_power_up_counter <= r_power_up_counter + 1;
                end
                else begin
                    MAX6675_State <= control_state;
                end
            end 
            control_state : begin
                r_CS <= 0;
                r_byte_counter <= 0;
                MAX6675_State <= wait_TX_ready;
            end
            wait_TX_ready : begin
                if (w_Tx_Ready) begin
                    MAX6675_State <= start_read;
                end
                else begin
                    MAX6675_State <= wait_TX_ready;
                end
            end
            start_read : begin
                r_TX_Dev <= 1;
                MAX6675_State <= get_data;
            end
            get_data : begin
                if (w_RX_DV) begin
                    if(r_byte_counter == 0)begin
                        r_o_data[15:8] <= w_op_data; // stored 1st byte
                        r_byte_counter <= r_byte_counter + 1;
                        MAX6675_State <= start_read; // again pulsing i_TX_DV for 2nd byte
                    end
                    else begin
                        r_o_data[7:0] <= w_op_data; // stored 2nd byte
                        MAX6675_State <= send_data;
                    end   
                end
                else begin
                    MAX6675_State <= get_data;
                end
            end
            send_data : begin
                r_op_data <= r_o_data;
                MAX6675_State <= stop_read;
            end
            stop_read : begin
                r_CS <= 1;
                MAX6675_State <= control_state;
            end
            default: begin
                MAX6675_State <= initial_state;
            end
        endcase
    end
end  
endmodule