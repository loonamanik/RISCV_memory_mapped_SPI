module ALU_Decoder(ALUOp,funct3,funct7,op,ALUControl);

    input [1:0]ALUOp;
    input [2:0]funct3;
    input [6:0]funct7,op;
    output [2:0]ALUControl;

    assign ALUControl = (ALUOp == 2'b00) ? 3'b000 : // Load/Store (Add)
                        (ALUOp == 2'b01) ? 3'b001 : // Branch (Subtract)
                        (ALUOp == 2'b10) ? (
                            (funct3 == 3'b000) ? (
                                // For ADD (R-type), op[5] is 1. For ADDI (I-type), op[5] is 0.
                                // Subtract only if R-type AND funct7[5] is 1.
                                (op[5] & funct7[5]) ? 3'b001 : 3'b000
                            ) :
                            (funct3 == 3'b111) ? 3'b010 : // AND
                            (funct3 == 3'b110) ? 3'b011 : // OR
                            (funct3 == 3'b010) ? 3'b101 : // SLT
                            3'b000 // Default
                        ) : 3'b000;
endmodule