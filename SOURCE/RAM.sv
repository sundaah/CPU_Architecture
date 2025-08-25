module RAM (
    input  logic        clk,
    input  logic        we,
    input  logic [2:0]  funct3,   
    input  logic [31:0] addr,
    input  logic [31:0] wData,   
    output logic [31:0] rData
);
    logic [31:0] mem[0:2**8-1];
    wire  [31:2] idx = addr[31:2];

    always_ff @(posedge clk) begin
        if (we) begin
            case (funct3)
                3'b000: begin // SB
                    mem[idx][8*addr[1:0] +: 8] <= wData[7:0];
                end
                3'b001: begin // SH
                    mem[idx][16*addr[1] +: 16] <= wData[15:0];
                end
                3'b010: begin // SW
                    mem[idx] <= wData;
                end
                default: mem[idx] <= wData; 
            endcase
        end
    end

    assign rData = mem[idx];
    
endmodule