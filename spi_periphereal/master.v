`timescale 1ns/1ps

module SPI_Master #(
  parameter SPI_MODE = 3,
  parameter CLKS_PER_HALF_BIT = 2
)(
  input  wire        i_Clk,
  input  wire        i_Rst_L,

  input  wire [7:0]  i_TX_Byte,
  input  wire        i_TX_DV,
  input  wire [7:0]  i_Burst_Count,

  output reg         o_TX_Ready,
  output reg         o_TX_Byte_Req, // Request next byte

  output reg  [7:0]  o_RX_Byte,
  output reg         o_RX_DV,

  output reg         o_SPI_Clk,
  output reg         o_SPI_MOSI,
  input  wire        i_SPI_MISO,
  output reg         o_SPI_CS_n
);

  // SPI Mode-3 (CPOL=1, CPHA=1)
  wire w_CPOL = 1'b1;
  wire w_CPHA = 1'b1;

  reg [$clog2(CLKS_PER_HALF_BIT*2)-1:0] r_ClkCnt;
  reg [11:0] r_EdgeCnt;
  reg        r_ClkInt;
  reg        r_Active;
  reg        r_Leading_Edge, r_Trailing_Edge;

  // ------------------------------------------------------------
  // 1. CLOCK GENERATION & CS CONTROL
  // ------------------------------------------------------------
  always @(posedge i_Clk or negedge i_Rst_L) begin
    if (!i_Rst_L) begin
      r_ClkCnt        <= 0;
      r_EdgeCnt       <= 0;
      r_ClkInt        <= w_CPOL;
      r_Active        <= 1'b0;
      o_SPI_CS_n      <= 1'b1;
      o_TX_Ready      <= 1'b1;
      r_Leading_Edge  <= 1'b0;
      r_Trailing_Edge <= 1'b0;
    end else begin
      r_Leading_Edge  <= 1'b0;
      r_Trailing_Edge <= 1'b0;

      // START TRANSFER
      if (i_TX_DV && o_TX_Ready) begin
        r_Active   <= 1'b1;
        // Total Edges = Burst_Count * 16 (8 bits * 2 edges)
        r_EdgeCnt  <= (i_Burst_Count == 0) ? 12'd16 : (i_Burst_Count * 16);
        r_ClkCnt   <= 0;
        r_ClkInt   <= w_CPOL;
        o_SPI_CS_n <= 1'b0;
        o_TX_Ready <= 1'b0;
      end
      // ACTIVE TRANSFER
      else if (r_Active) begin
        if (r_ClkCnt == CLKS_PER_HALF_BIT-1) begin // Edge 1
          r_ClkInt       <= ~r_ClkInt;
          r_Leading_Edge <= 1'b1;
          r_ClkCnt       <= r_ClkCnt + 1;
          r_EdgeCnt      <= r_EdgeCnt - 1;
        end
        else if (r_ClkCnt == CLKS_PER_HALF_BIT*2-1) begin // Edge 2
          r_ClkInt        <= ~r_ClkInt;
          r_Trailing_Edge <= 1'b1;
          r_ClkCnt        <= 0;
          r_EdgeCnt       <= r_EdgeCnt - 1;
        end
        else begin
          r_ClkCnt <= r_ClkCnt + 1;
        end

        // TERMINATION
        if (r_EdgeCnt == 0) begin
          r_Active   <= 1'b0;
          o_SPI_CS_n <= 1'b1;
          o_TX_Ready <= 1'b1;
        end
      end
    end
  end

  // ------------------------------------------------------------
  // 2. SPI CLOCK OUTPUT
  // ------------------------------------------------------------
  always @(posedge i_Clk) begin
    if (r_Active) o_SPI_Clk <= r_ClkInt;
    else          o_SPI_Clk <= w_CPOL;
  end

  // ------------------------------------------------------------
  // 3. MOSI (TX) DATA PATH - WITH PRE-FETCH FIX
  // ------------------------------------------------------------
  reg [7:0] r_TX_Shift;
  reg [2:0] r_TX_Bit;

  always @(posedge i_Clk or negedge i_Rst_L) begin
    if (!i_Rst_L) begin
      o_SPI_MOSI    <= 1'b0;
      r_TX_Shift    <= 8'h00;
      r_TX_Bit      <= 3'd7;
      o_TX_Byte_Req <= 1'b0;
    end else begin
      o_TX_Byte_Req <= 1'b0; // Default Low

      // CASE A: START OF TRANSACTION
      if (i_TX_DV && o_TX_Ready) begin
        r_TX_Shift    <= i_TX_Byte; // Load Byte 0
        r_TX_Bit      <= 3'd7;
        o_TX_Byte_Req <= 1'b1;      // FIX: Pre-fetch Byte 1 immediately!
      end
      
      // CASE B: DURING TRANSACTION
      else if (r_Active && 
              ((r_Leading_Edge & w_CPHA) || (r_Trailing_Edge & ~w_CPHA))) begin
        
        o_SPI_MOSI <= r_TX_Shift[r_TX_Bit];

        if (r_TX_Bit == 0) begin
          r_TX_Bit      <= 3'd7;
          r_TX_Shift    <= i_TX_Byte; // Load the PRE-FETCHED byte
          o_TX_Byte_Req <= 1'b1;      // Fetch the next one
        end else begin
          r_TX_Bit <= r_TX_Bit - 1;
        end
      end
    end
  end

  // ------------------------------------------------------------
  // 4. MISO (RX) DATA PATH
  // ------------------------------------------------------------
  reg [2:0] r_RX_Bit;

  always @(posedge i_Clk or negedge i_Rst_L) begin
    if (!i_Rst_L) begin
      o_RX_Byte <= 8'h00;
      o_RX_DV   <= 1'b0;
      r_RX_Bit  <= 3'd7;
    end else begin
      o_RX_DV <= 1'b0;

      if (r_Active && 
         ((r_Leading_Edge & ~w_CPHA) || (r_Trailing_Edge & w_CPHA))) begin
        
        o_RX_Byte[r_RX_Bit] <= i_SPI_MISO;

        if (r_RX_Bit == 0) begin
          r_RX_Bit <= 3'd7;
          o_RX_DV  <= 1'b1;
        end else begin
          r_RX_Bit <= r_RX_Bit - 1;
        end
      end
    end
  end

endmodule