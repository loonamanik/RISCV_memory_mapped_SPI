`timescale 1ns/1ps
module SPI_Master_With_Single_CS #(
  parameter SPI_MODE = 3,
  parameter CLKS_PER_HALF_BIT = 2
)(
  input  wire        i_Clk,
  input  wire        i_Rst_L,
  
  // Bus Interface (RISC-V Side)
  input  wire        i_Bus_WE,
  input  wire [3:0]  i_Bus_Addr,
  input  wire [31:0] i_Bus_WData,
  output reg  [31:0] o_Bus_RData,

  // SPI Interface (Physical Side)
  output wire        o_SPI_Clk,
  output wire        o_SPI_MOSI,
  input  wire        i_SPI_MISO,
  output wire        o_SPI_CS_n
);

  wire       w_TX_Ready;
  wire       w_TX_Req;
  wire       w_RX_DV;
  wire [7:0] w_RX_Byte;
  
  reg [7:0] r_Burst_Len;
  reg       r_Start;

  // FIFO buffers
  reg [7:0] tx_fifo [0:7];
  reg [7:0] rx_fifo [0:7];
  reg [2:0] tx_wr_ptr, tx_rd_ptr;
  reg [2:0] rx_wr_ptr, rx_rd_ptr;

  // Bus Write Logic
  always @(posedge i_Clk or negedge i_Rst_L) begin
    if (!i_Rst_L) begin
      r_Start <= 0;
      r_Burst_Len <= 0;
      tx_wr_ptr <= 0;
    end else begin
      r_Start <= 0; 
      if (i_Bus_WE) begin
        case (i_Bus_Addr[3:0])
          4'h0: r_Start <= i_Bus_WData[0];       // Addr 0x00: Control (Start)
          4'h4: r_Burst_Len <= i_Bus_WData[7:0]; // Addr 0x04: Burst Length
          4'h8: begin                            // Addr 0x08: TX Data
             tx_fifo[tx_wr_ptr] <= i_Bus_WData[7:0];
             tx_wr_ptr <= tx_wr_ptr + 1;
          end
        endcase
      end
      // Reset TX pointer when idle to ensure fresh start
      if (w_TX_Ready && !r_Start) tx_wr_ptr <= 0;
    end
  end

  // Bus Read Logic
  always @(*) begin
      // Default assignment to prevent latches and X states
      o_Bus_RData = 32'h00000000; 
      
      if (!i_Bus_WE) begin
          case (i_Bus_Addr[3:0])
              // Address 0x0: Read Status (e.g., TX Ready flag)
              4'h0: o_Bus_RData = {31'b0, w_TX_Ready}; 
              
              // Address 0xC: Read the received SPI data
              4'h8: o_Bus_RData = {24'b0, w_RX_Byte}; 
              
              default: o_Bus_RData = 32'h00000000;
          endcase
      end
  end

  SPI_Master #(
    .SPI_MODE(SPI_MODE),
    .CLKS_PER_HALF_BIT(CLKS_PER_HALF_BIT)
  ) u_master (
    .i_Clk(i_Clk),
    .i_Rst_L(i_Rst_L),
    .i_TX_Byte(tx_fifo[tx_rd_ptr]), // Feed data from FIFO
    .i_TX_DV(r_Start),
    .i_Burst_Count(r_Burst_Len),
    .o_TX_Ready(w_TX_Ready),
    .o_TX_Byte_Req(w_TX_Req),       // Connected to FIFO logic
    .o_RX_Byte(w_RX_Byte),
    .o_RX_DV(w_RX_DV),
    .o_SPI_Clk(o_SPI_Clk),
    .o_SPI_MOSI(o_SPI_MOSI),
    .i_SPI_MISO(i_SPI_MISO),
    .o_SPI_CS_n(o_SPI_CS_n)
  );

endmodule