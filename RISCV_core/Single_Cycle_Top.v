module Single_Cycle_Top(
    input  clk,
    input  rst,
    output SPI_Clk,
    output SPI_MOSI,
    input  SPI_MISO,
    output SPI_CS_n
);

    // --- CPU Signals ---
    wire [31:0] PC_Top, RD_Instr, RD1_Top, Imm_Ext_Top, ALUResult, PCPlus4, RD2_Top, SrcB, Result;
    wire RegWrite, MemWrite, ALUSrc, ResultSrc;
    wire [1:0] ImmSrc;
    wire [2:0] ALUControl_Top;
    
    // --- Memory Signals ---
    wire [31:0] RAM_ReadData;
    
    // --- SPI Signals ---
    wire [31:0] SPI_ReadData;
    wire        spi_sel;
    wire        spi_we;
    wire        data_mem_we;
    reg  [31:0] Final_Read_Data; // Mux output (RAM vs SPI)
    
    // --- Branch Logic Wires ---
    wire Zero, Branch, PCSrc;
    wire [31:0] PCTarget, PCNext;
    // ========================================================================
    // ADDRESS DECODING & DATA MUXING
    // ========================================================================
    
    // 1. SPI Select: Active for the block of addresses from 0x40 to 0x4F
    assign spi_sel = (ALUResult >= 32'h00000040 && ALUResult <= 32'h0000004F);
    
    // 2. Write Enables
    assign data_mem_we = MemWrite & (!spi_sel); // Write to RAM only if NOT SPI
    assign spi_we      = MemWrite & spi_sel;    // Write to SPI only if Selected

    // 3. Read Data Mux (RAM vs SPI)
    always @(*) begin
        if (spi_sel)
            Final_Read_Data = SPI_ReadData;
        else
            Final_Read_Data = RAM_ReadData;
    end
      // ========================================================================
    // BRANCH LOGIC
    // ========================================================================
    wire takeBranch;

    assign takeBranch = 
       (RD_Instr[14:12] == 3'b000 &&  Zero) ||  // BEQ
       (RD_Instr[14:12] == 3'b001 && !Zero);    // BNE

    // 1. Calculate the branch target address
    assign PCTarget = PC_Top + Imm_Ext_Top;
    
    // 2. Branch is taken ONLY if it's a Branch instruction AND the ALU output is zero
    assign PCSrc = Branch & takeBranch;
    
    // 3. PC Multiplexer: Choose between PC+4 and the Branch Target
    assign PCNext = PCSrc ? PCTarget : PCPlus4;
    
    // ========================================================================
    // CPU MODULES
    // ========================================================================
    PC_Module PC(
        .clk(clk),
        .rst(rst),
        .PC(PC_Top),
        .PC_Next(PCNext)
    );

    PC_Adder PC_Adder(
        .a(PC_Top),
        .b(32'd4),
        .c(PCPlus4)
    );
   
    Instruction_Memory Instruction_Memory(
        .rst(rst),
        .A(PC_Top),
        .RD(RD_Instr)
    );

    Register_File Register_File(
        .clk(clk),
        .rst(rst),
        .WE3(RegWrite),
        .WD3(Result),
        .A1(RD_Instr[19:15]),
        .A2(RD_Instr[24:20]),
        .A3(RD_Instr[11:7]),
        .RD1(RD1_Top),
        .RD2(RD2_Top)
    );

    Sign_Extend Sign_Extend(
        .In(RD_Instr),
        .ImmSrc(ImmSrc),
        .Imm_Ext(Imm_Ext_Top)
    );

    Mux Mux_Register_to_ALU(
        .a(RD2_Top),
        .b(Imm_Ext_Top),
        .s(ALUSrc),
        .c(SrcB)
    );

    ALU ALU(
        .A(RD1_Top),
        .B(SrcB),
        .Result(ALUResult), // This is the Address
        .ALUControl(ALUControl_Top),
        .OverFlow(),
        .Carry(),
        .Zero(Zero),
        .Negative()
    );

    Control_Unit_Top Control_Unit_Top(
        .Op(RD_Instr[6:0]),
        .RegWrite(RegWrite),
        .ImmSrc(ImmSrc),
        .ALUSrc(ALUSrc),
        .MemWrite(MemWrite),
        .ResultSrc(ResultSrc),
        .Branch(Branch),
        .funct3(RD_Instr[14:12]),
        .funct7(RD_Instr[31:25]),
        .ALUControl(ALUControl_Top)
    );

    Data_Memory Data_Memory(
        .clk(clk),
        .rst(rst),
        .WE(data_mem_we), 
        .WD(RD2_Top),
        .A(ALUResult),
        .RD(RAM_ReadData) 
    );

    Mux Mux_DataMemory_to_Register(
        .a(ALUResult),
        .b(Final_Read_Data), 
        .s(ResultSrc),
        .c(Result)
    );

    // ========================================================================
    // SPI SUBSYSTEM (Master Only)
    // ========================================================================
    SPI_Master_With_Single_CS #(
        .SPI_MODE(3),
        .CLKS_PER_HALF_BIT(2)
    ) u_spi_master (
        .i_Clk(clk),
        .i_Rst_L(~rst), 
        
        // Bus Interface
        .i_Bus_WE(spi_we),
        .i_Bus_Addr(ALUResult[3:0]), 
        .i_Bus_WData(RD2_Top),       
        .o_Bus_RData(SPI_ReadData),
        
        // Physical Pins routed to Module Ports
        .o_SPI_Clk(SPI_Clk),
        .o_SPI_MOSI(SPI_MOSI),
        .i_SPI_MISO(SPI_MISO),
        .o_SPI_CS_n(SPI_CS_n)
        
    );

endmodule