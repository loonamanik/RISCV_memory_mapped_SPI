`timescale 1ns/1ps
module SPI_Slave #(
  parameter SPI_MODE = 3
)(
  input  wire        i_Rst_L,
  input  wire        i_SPI_Clk,
  input  wire        i_SPI_CS_n,
  input  wire        i_SPI_MOSI,
  output wire        o_SPI_MISO,
  input  wire [7:0]  i_Slave_TX_Byte,
  output reg  [7:0]  o_Slave_RX_Byte,
  output reg         o_Slave_RX_DV
);

  reg [7:0] r_RX_Shift;
  reg [2:0] r_RX_Bit;
  reg [7:0] r_TX_Shift;
  reg [2:0] r_TX_Bit;

  // RX Section
  always @(negedge i_SPI_Clk or posedge i_SPI_CS_n) begin
    if (i_SPI_CS_n) begin
      r_RX_Bit <= 7;
      o_Slave_RX_DV <= 0;
      o_Slave_RX_Byte <=0;
      r_RX_Shift <=0;
    end else begin
      r_RX_Shift[r_RX_Bit] <= i_SPI_MOSI;
      if (r_RX_Bit == 0) begin
        o_Slave_RX_Byte <= {r_RX_Shift[7:1], i_SPI_MOSI};
        o_Slave_RX_DV <= 1;
        r_RX_Bit <= 7;
      end else begin
        r_RX_Bit <= r_RX_Bit - 1;
        o_Slave_RX_DV <= 0;
      end
    end
  end


  // TX Section (Mode 3: Launch on Falling Edge)
  always @(negedge i_SPI_Clk or posedge i_SPI_CS_n) begin
    if (i_SPI_CS_n) begin
      // When CS_n is HIGH (Idle), reset the counter and load the data
      r_TX_Bit   <= 3'd7;
      r_TX_Shift <= i_Slave_TX_Byte; 
    end else begin
      // CS_n is LOW. We are clocking data.
      if (r_TX_Bit == 3'd7) begin
        // FIRST falling edge! Do NOT shift yet, let the Master sample Bit 7.
        // Just decrement the counter so we shift next time.
        r_TX_Bit <= 3'd6;
      end else begin
        // Second falling edge onward: Shift the data normally
        r_TX_Bit   <= r_TX_Bit - 1'b1;
        r_TX_Shift <= {r_TX_Shift[6:0], 1'b0};
      end
    end
  end

  assign o_SPI_MISO = i_SPI_CS_n ? 1'bz : r_TX_Shift[7];

endmodule