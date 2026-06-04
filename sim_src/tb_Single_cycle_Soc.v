

module tb_Single_Cycle_Top;

    // 1. Inputs (Regs because we drive them)
    reg clk;
    reg rst;

    // 2. Outputs (Wires because we just watch them)
    //    These are the physical SPI pins coming out of the chip
    wire w_SPI_Clk;
    wire w_SPI_MOSI;
    wire w_SPI_MISO;
    wire w_SPI_CS_n;
    
    // 3. Instantiate the Unit Under Test (UUT)
    Single_Cycle_Top uut (
        .clk(clk),
        .rst(rst),
        .SPI_Clk(w_SPI_Clk),
        .SPI_MOSI(w_SPI_MOSI),
        .SPI_MISO(w_SPI_MISO),
        .SPI_CS_n(w_SPI_CS_n)
    );

    // 4. Instantiate the SPI Slave (External Device Simulation)
    SPI_Slave #(
        .SPI_MODE(3)
    ) external_spi_slave (
        .i_Rst_L(!rst),
        .i_SPI_Clk(w_SPI_Clk),
        .i_SPI_CS_n(w_SPI_CS_n),
        .i_SPI_MOSI(w_SPI_MOSI),
        .o_SPI_MISO(w_SPI_MISO), // Slave drives MISO back to the Master
        .i_Slave_TX_Byte(8'h55), // Hardcoded dummy response
        .o_Slave_RX_Byte(),
        .o_Slave_RX_DV()
    );

    // 5. Clock Generation (100 MHz)
    //    Toggles every 5ns -> Period = 10ns
    always #5 clk = ~clk;

    // 6. Test Stimulus
    initial begin
        // Initialize Inputs
        clk = 0;
        rst = 1; // Assert Reset (Active High)

        // Wait 100ns for global reset to finish
        #100;
      
        // Release Reset
        rst = 0; 

        // Wait long enough for your program to run
        #5000; 
        
        // Stop the simulation
        $finish;
    end
      
endmodule