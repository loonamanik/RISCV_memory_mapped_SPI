module Sign_Extend (In, Imm_Ext, ImmSrc);

    input [31:0] In;
    input [1:0] ImmSrc; 
    output [31:0] Imm_Ext;

    assign Imm_Ext = (ImmSrc == 2'b00) ? {{20{In[31]}}, In[31:20]} :                               // I-Type (ADDI, LW)
                     (ImmSrc == 2'b01) ? {{20{In[31]}}, In[31:25], In[11:7]} :                     // S-Type (SW)
                     (ImmSrc == 2'b10) ? {{20{In[31]}},In[7], In[30:25], In[11:8], 1'b0} :        // B-Type (BEQ, BNE)
                     32'b0;                                                                        // Default fallback
                                
endmodule