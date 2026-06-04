module Register_File(clk,rst,WE3,WD3,A1,A2,A3,RD1,RD2);

    input clk,rst,WE3;
    input [4:0]A1,A2,A3;
    input [31:0]WD3;
    output [31:0]RD1,RD2;

    reg [31:0] Register [31:0];
    integer i;

    // 1. Synchronous Reset to initialize all registers to 0
    // This removes the red 'XXXXXXXX' from the internal memory array
    always @ (posedge clk)
    begin
        if(rst) begin
            for (i = 0; i < 32; i = i + 1)
                Register[i] <= 32'h0;
        end
        else if(WE3 && (A3 != 5'd0)) // 2. Hardcode x0: Prevent writing to Register 0
            Register[A3] <= WD3;
    end

    // 3. Simple combinational read
    // Removed the (~rst) condition that was blocking your data
    // Added a check to ensure reading from address 0 always returns 0
    assign RD1 = (A1 == 5'd0) ? 32'd0 : Register[A1];
    assign RD2 = (A2 == 5'd0) ? 32'd0 : Register[A2];

endmodule