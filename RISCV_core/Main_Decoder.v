module Main_Decoder(Op,RegWrite,ImmSrc,ALUSrc,MemWrite,ResultSrc,Branch,ALUOp);
    input [6:0]Op;
    output RegWrite,ALUSrc,MemWrite,ResultSrc,Branch;
    output [1:0]ImmSrc,ALUOp;

    // Added 7'b0010011 (I-Type) to RegWrite to allow saving results
    assign RegWrite = (Op == 7'b0000011 | Op == 7'b0110011 | Op == 7'b0010011) ? 1'b1 : 1'b0;

    // ImmSrc: 00 for I-type/Load, 01 for S-type (Store), 10 for B-type (Branch)
    assign ImmSrc = (Op == 7'b0100011) ? 2'b01 : 
                    (Op == 7'b1100011) ? 2'b10 :    
                                         2'b00 ;

    // Added 7'b0010011 to ALUSrc to select Immediate instead of Register RD2
    assign ALUSrc = (Op == 7'b0000011 | Op == 7'b0100011 | Op == 7'b0010011) ? 1'b1 : 1'b0;

    assign MemWrite = (Op == 7'b0100011) ? 1'b1 : 1'b0;

    // ResultSrc: 0 selects ALU result, 1 selects Data Memory (for Load instructions)
    assign ResultSrc = (Op == 7'b0000011) ? 1'b1 : 1'b0;

    assign Branch = (Op == 7'b1100011) ? 1'b1 : 1'b0;

    // Added 7'b0010011 to ALUOp so the ALU Decoder handles it like an R-type (using funct3)
    assign ALUOp = (Op == 7'b0110011 | Op == 7'b0010011) ? 2'b10 :
                   (Op == 7'b1100011) ? 2'b01 : 2'b00;

endmodule