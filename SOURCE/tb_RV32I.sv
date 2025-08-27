`timescale 1ns / 1ps

`include "opcode.vh"
`include "mem_path.vh"

module tb_RV32I();

    logic clk;
    logic reset;

    logic all_passed = 1'b0;

    MCU U_MCU (
      .clk  (clk),
      .reset(reset)
    );

    always#5 clk = ~clk;

    task init;
        int i;
        for (int i = 0; i < 62; i++) begin
            `INSTR_PATH.rom[i] = 32'h00000000;
        end
        for (int i = 0; i < 32; i++) begin
            `RF_PATH.mem[i] = 32'h00000000;
        end
    endtask

    task reset_cpu; 
        repeat(3) begin
            @(posedge clk);
            reset = 1;
        end
        @(posedge clk);
        reset = 0;
    endtask

    logic [31:0] cycle;
    logic done;
    logic [31:0]  current_test_id = 0;
    logic [255:0] current_test_type;
    logic [31:0]  current_output;
    logic [31:0]  current_result;
    logic all_tests_passed = 0;

    wire [31:0] timeout_cycle = 25;

    initial begin
        while (all_tests_passed === 0) begin
        @(posedge clk);
            if (cycle === timeout_cycle) begin
                $display("[Failed] Timeout at [%d] test %s, expected_result = %h, got = %h", current_test_id, current_test_type, current_result, current_output);
                $finish();
            end
        end
    end

    always_ff @(posedge clk) begin
        if (done === 0)
            cycle <= cycle + 1;
        else
            cycle <= 0;
    end

    task check_result_RF (input logic [4:0] addr, input [31:0] expect_value, input [255:0] test_type);
        done = 0;
        current_test_id   = current_test_id + 1;
        current_test_type = test_type;
        current_result    = expect_value;
        while (`RF_PATH.mem[addr] !== expect_value) begin
            current_output = `RF_PATH.mem[addr];
            @(posedge clk);
        end
        cycle = 0;
        done = 1;
        $display("[%d] Test %s passed!", current_test_id, test_type);
    endtask

    task check_result_DMEM (input logic [14:0] addr, input [31:0] expect_value, input [255:0] test_type);
        done = 0;
        current_test_id   = current_test_id + 1;
        current_test_type = test_type;
        current_result    = expect_value;
        while (`RAM_PATH.mem[addr] !== expect_value) begin
            current_output = `RAM_PATH.mem[addr];
            @(posedge clk);
        end
        cycle = 0;
        done = 1;
        $display("[%d] Test %s passed!", current_test_id, test_type);
    endtask

    logic [ 4:0] RS0, RS1, RS2, RS3, RS4, RS5;
    logic [ 4:0] SHAMT;
    logic [31:0] IMM, IMM0, IMM1, IMM2, IMM3;
    logic [11:0] IMM12_0;
    logic [31:0] RD0, RD1, RD2, RD3, RD4, RD5;
    logic [14:0] DATA_ADDR, DATA_ADDR0, DATA_ADDR1, DATA_ADDR2, DATA_ADDR3;
    logic [14:0] DATA_ADDR4, DATA_ADDR5, DATA_ADDR6, DATA_ADDR7, DATA_ADDR8, DATA_ADDR9;

    logic [31:0] JUMP_ADDR;

    logic [31:0]  BR_TAKEN_OP1  [6:0];
    logic [31:0]  BR_TAKEN_OP2  [6:0];
    logic [31:0]  BR_NTAKEN_OP1 [6:0];
    logic [31:0]  BR_NTAKEN_OP2 [6:0];
    logic [2:0]   BR_TYPE       [6:0];
    logic [255:0] BR_NAME_TK1   [6:0];
    logic [255:0] BR_NAME_TK2   [6:0];
    logic [255:0] BR_NAME_NTK   [6:0];

    initial begin
        clk = 0;
        reset = 1;
        #10;
        reset = 0;
        #10;

        // R-Type
        if(0) begin
            init();
            RS0 = 0; RD0 = 32'h0000_0000;
            RS1 = 1; RD1 = 32'h0000_0001;
            RS2 = 2; RD2 = 32'h7FFF_FFFF;
            RS3 = 3; RD3 = 32'hFFFF_FFFF;
            RS4 = 4; RD4 = 32'h8000_0000;
            RS5 = 5; RD5 = 32'h0000_001F;

            `RF_PATH.mem[RS1] = RD1; //x1 data
            `RF_PATH.mem[RS2] = RD2; //x2 data
            `RF_PATH.mem[RS3] = RD3; //x3 data
            `RF_PATH.mem[RS4] = RD4; //x4 data
            `RF_PATH.mem[RS5] = RD5; //x5 data

            // format: {funct7, rs2, rs1, funct3, rd, opcode}
            `INSTR_PATH.rom[0] = {`FNC7_0, RS1, RS2, `FNC_ADD_SUB, 5'd8, `OPC_ARI_RTYPE};  // add  x8, x2, x1
            `INSTR_PATH.rom[1] = {`FNC7_1, RS2, RS1, `FNC_ADD_SUB, 5'd9, `OPC_ARI_RTYPE};  // sub  x9, x1, x2
            `INSTR_PATH.rom[2] = {`FNC7_0, RS4, RS3, `FNC_AND,     5'd10, `OPC_ARI_RTYPE}; // and  x10, x3, x4
            `INSTR_PATH.rom[3] = {`FNC7_0, RS3, RS4, `FNC_OR,      5'd11, `OPC_ARI_RTYPE}; // or   x11, x4, x3
            `INSTR_PATH.rom[4] = {`FNC7_0, RS5, RS1, `FNC_SLL,     5'd12, `OPC_ARI_RTYPE}; // sll  x12, x1, x5
            `INSTR_PATH.rom[5] = {`FNC7_0, RS5, RS4, `FNC_SRL_SRA, 5'd13, `OPC_ARI_RTYPE}; // srl  x13, x4, x5
            `INSTR_PATH.rom[6] = {`FNC7_1, RS5, RS4, `FNC_SRL_SRA, 5'd14, `OPC_ARI_RTYPE}; // sra  x14, x4, x5
            `INSTR_PATH.rom[7] = {`FNC7_0, RS2, RS4, `FNC_SLT,     5'd15, `OPC_ARI_RTYPE}; // slt  x15, x4, x2
            `INSTR_PATH.rom[8] = {`FNC7_0, RS0, RS3, `FNC_SLTU,    5'd16, `OPC_ARI_RTYPE}; // sltu x16, x3, x0
            `INSTR_PATH.rom[9] = {`FNC7_0, RS4, RS3, `FNC_XOR,     5'd17, `OPC_ARI_RTYPE}; // xor  x17, x3, x4

            reset_cpu();

            check_result_RF(8,  32'h8000_0000, "R-Type ADD");
            check_result_RF(9,  32'h8000_0002, "R-Type SUB");
            check_result_RF(10, 32'h8000_0000, "R-Type AND");
            check_result_RF(11, 32'hFFFF_FFFF, "R-Type OR");
            check_result_RF(12, 32'h8000_0000, "R-Type SLL");
            check_result_RF(13, 32'h0000_0001, "R-Type SRL");
            check_result_RF(14, 32'hFFFF_FFFF, "R-Type SRA");
            check_result_RF(15, 32'h0000_0001, "R-Type SLT");
            check_result_RF(16, 32'h0000_0000, "R-Type SLTU");
            check_result_RF(17, 32'h7FFF_FFFF, "R-Type XOR");
        end

        // S-Type
        if (0) begin
            init();
            
            IMM0 = 32'h0000_0000;
            IMM1 = 32'h0000_0001;
            IMM2 = 32'h0000_0002;
            IMM3 = 32'h0000_0003;

            `RF_PATH.mem[ 1] = 32'h1234_5678;
            `RF_PATH.mem[ 2] = 32'h0000_0000;
            `RF_PATH.mem[ 3] = 32'h0000_0004;
            `RF_PATH.mem[ 4] = 32'h0000_0008;
            `RF_PATH.mem[ 5] = 32'h0000_000C;
            `RF_PATH.mem[ 6] = 32'h0000_0010;
            `RF_PATH.mem[ 7] = 32'h0000_0014;
            `RF_PATH.mem[ 8] = 32'h0000_0018;
            `RF_PATH.mem[ 9] = 32'h0000_001C;
            `RF_PATH.mem[10] = 32'h0000_0020;

            DATA_ADDR0 = (`RF_PATH.mem[ 2] + IMM0[11:0]) >> 2;

            DATA_ADDR1 = (`RF_PATH.mem[ 3] + IMM0[11:0]) >> 2;
            DATA_ADDR2 = (`RF_PATH.mem[ 4] + IMM1[11:0]) >> 2;
            DATA_ADDR3 = (`RF_PATH.mem[ 5] + IMM2[11:0]) >> 2;
            DATA_ADDR4 = (`RF_PATH.mem[ 6] + IMM3[11:0]) >> 2;

            DATA_ADDR5 = (`RF_PATH.mem[ 7] + IMM0[11:0]) >> 2;
            DATA_ADDR6 = (`RF_PATH.mem[ 8] + IMM1[11:0]) >> 2;
            DATA_ADDR7 = (`RF_PATH.mem[ 9] + IMM2[11:0]) >> 2;
            DATA_ADDR8 = (`RF_PATH.mem[10] + IMM3[11:0]) >> 2;

            

            `INSTR_PATH.rom[0] = {IMM0[11:5], 5'd1, 5'd2,  `FNC_SW, IMM0[4:0], `OPC_STORE};

            `INSTR_PATH.rom[1] = {IMM0[11:5], 5'd1, 5'd3,  `FNC_SH, IMM0[4:0], `OPC_STORE};
            //`INSTR_PATH.rom[2] = {IMM1[11:5], 5'd1, 5'd4,  `FNC_SH, IMM1[4:0], `OPC_STORE}; 
            `INSTR_PATH.rom[3] = {IMM2[11:5], 5'd1, 5'd5,  `FNC_SH, IMM2[4:0], `OPC_STORE};
            //`INSTR_PATH.rom[4] = {IMM3[11:5], 5'd1, 5'd6,  `FNC_SH, IMM3[4:0], `OPC_STORE}; 

            `INSTR_PATH.rom[5] = {IMM0[11:5], 5'd1, 5'd7,  `FNC_SB, IMM0[4:0], `OPC_STORE};
            `INSTR_PATH.rom[6] = {IMM1[11:5], 5'd1, 5'd8,  `FNC_SB, IMM1[4:0], `OPC_STORE};
            `INSTR_PATH.rom[7] = {IMM2[11:5], 5'd1, 5'd9,  `FNC_SB, IMM2[4:0], `OPC_STORE};
            `INSTR_PATH.rom[8] = {IMM3[11:5], 5'd1, 5'd10, `FNC_SB, IMM3[4:0], `OPC_STORE};

            `RAM_PATH.mem[DATA_ADDR0] = 0;
            `RAM_PATH.mem[DATA_ADDR1] = 0;
            `RAM_PATH.mem[DATA_ADDR3] = 0;
            `RAM_PATH.mem[DATA_ADDR4] = 0;
            `RAM_PATH.mem[DATA_ADDR5] = 0;
            `RAM_PATH.mem[DATA_ADDR6] = 0;
            `RAM_PATH.mem[DATA_ADDR7] = 0;
            `RAM_PATH.mem[DATA_ADDR8] = 0;
            
            reset_cpu();

            check_result_DMEM(DATA_ADDR0, 32'h12345678, "S-Type SW");
            check_result_DMEM(DATA_ADDR1, 32'h00005678, "S-Type SH 1");
            //check_result_DMEM(DATA_ADDR2, 32'h00005678, "S-Type SH 2");
            check_result_DMEM(DATA_ADDR3, 32'h56780000, "S-Type SH 3");
            //check_result_DMEM(DATA_ADDR4, 32'h56780000, "S-Type SH 4");

            check_result_DMEM(DATA_ADDR5, 32'h00000078, "S-Type SB 1");
            check_result_DMEM(DATA_ADDR6, 32'h00007800, "S-Type SB 2");
            check_result_DMEM(DATA_ADDR7, 32'h00780000, "S-Type SB 3");
            check_result_DMEM(DATA_ADDR8, 32'h78000000, "S-Type SB 4");
        end

        // L-Type
        if (0) begin
            init();

            `RF_PATH.mem[1] = 32'h0000_0000;
            IMM0            = 32'h0000_0000;
            IMM1            = 32'h0000_0001;
            IMM2            = 32'h0000_0002;
            IMM3            = 32'h0000_0003;
            DATA_ADDR       = (`RF_PATH.mem[1] + IMM0[11:0]) >> 2;

            `INSTR_PATH.rom[ 0] = {IMM0[11:0], 5'd1, `FNC_LW,  5'd2,  `OPC_LOAD};
            `INSTR_PATH.rom[ 1] = {IMM0[11:0], 5'd1, `FNC_LH,  5'd3,  `OPC_LOAD};
            //`INSTR_PATH.rom[ 3] = {IMM1[11:0], 5'd1, `FNC_LH,  5'd4,  `OPC_LOAD};
            `INSTR_PATH.rom[ 4] = {IMM2[11:0], 5'd1, `FNC_LH,  5'd5,  `OPC_LOAD};
            //`INSTR_PATH.rom[ 5] = {IMM3[11:0], 5'd1, `FNC_LH,  5'd6,  `OPC_LOAD};
            `INSTR_PATH.rom[ 6] = {IMM0[11:0], 5'd1, `FNC_LB,  5'd7,  `OPC_LOAD};
            `INSTR_PATH.rom[ 7] = {IMM1[11:0], 5'd1, `FNC_LB,  5'd8,  `OPC_LOAD};
            `INSTR_PATH.rom[ 8] = {IMM2[11:0], 5'd1, `FNC_LB,  5'd9,  `OPC_LOAD};
            `INSTR_PATH.rom[ 9] = {IMM3[11:0], 5'd1, `FNC_LB,  5'd10, `OPC_LOAD};
            `INSTR_PATH.rom[10] = {IMM0[11:0], 5'd1, `FNC_LHU, 5'd11, `OPC_LOAD};
            //`INSTR_PATH.rom[11] = {IMM1[11:0], 5'd1, `FNC_LHU, 5'd12, `OPC_LOAD};
            `INSTR_PATH.rom[12] = {IMM2[11:0], 5'd1, `FNC_LHU, 5'd13, `OPC_LOAD};
            //`INSTR_PATH.rom[13] = {IMM3[11:0], 5'd1, `FNC_LHU, 5'd14, `OPC_LOAD};
            `INSTR_PATH.rom[14] = {IMM0[11:0], 5'd1, `FNC_LBU, 5'd15, `OPC_LOAD};
            `INSTR_PATH.rom[15] = {IMM1[11:0], 5'd1, `FNC_LBU, 5'd16, `OPC_LOAD};
            `INSTR_PATH.rom[16] = {IMM2[11:0], 5'd1, `FNC_LBU, 5'd17, `OPC_LOAD};
            `INSTR_PATH.rom[17] = {IMM3[11:0], 5'd1, `FNC_LBU, 5'd18, `OPC_LOAD};

            `RAM_PATH.mem[DATA_ADDR] = 32'hdeadbeef;

            reset_cpu();

            check_result_RF(5'd2,  32'hdeadbeef, "L-Type LW");

            check_result_RF(5'd3,  32'hffffbeef, "L-Type LH 0");
            // check_result_RF(5'd4,  32'hffffbeef, "I-Type LH 1");
            check_result_RF(5'd5,  32'hffffdead, "L-Type LH 2");
            // check_result_RF(5'd6,  32'hffffdead, "I-Type LH 3");

            check_result_RF(5'd7,  32'hffffffef, "L-Type LB 0");
            check_result_RF(5'd8,  32'hffffffbe, "L-Type LB 1");
            check_result_RF(5'd9,  32'hffffffad, "L-Type LB 2");
            check_result_RF(5'd10, 32'hffffffde, "L-Type LB 3");

            check_result_RF(5'd11, 32'h0000beef, "L-Type LHU 0");
            // check_result_RF(5'd12, 32'h0000beef, "I-Type LHU 1");
            check_result_RF(5'd13, 32'h0000dead, "L-Type LHU 2");
            // check_result_RF(5'd14, 32'h0000dead, "I-Type LHU 3");

            check_result_RF(5'd15, 32'h000000ef, "L-Type LBU 0");
            check_result_RF(5'd16, 32'h000000be, "L-Type LBU 1");
            check_result_RF(5'd17, 32'h000000ad, "L-Type LBU 2");
            check_result_RF(5'd18, 32'h000000de, "L-Type LBU 3");
        end
        
        // I-Type 
        if (1) begin
            init();
            
            IMM12_0 = 12'b0000000001;
            RS1 = 1; RD1 = 32'h0000_1010;
            SHAMT = 5'b00001;
            `RF_PATH.mem[RS1] = RD1;

            // 32'b  imm12 _ rs1 _f3 _ rd _ op // I-Type
            `INSTR_PATH.rom[0] = {IMM12_0, RS1, `FNC_ADD_SUB, 5'd3, `OPC_ARI_ITYPE}; // addi  x3, x1, 1
            `INSTR_PATH.rom[1] = {IMM12_0, RS1, `FNC_AND,     5'd4, `OPC_ARI_ITYPE}; // andi  x4, x1, 1
            `INSTR_PATH.rom[2] = {IMM12_0, RS1, `FNC_OR,      5'd5, `OPC_ARI_ITYPE}; // ori   x5, x1, 1
            `INSTR_PATH.rom[3] = {IMM12_0, RS1, `FNC_SLT,     5'd6, `OPC_ARI_ITYPE}; // slti  x6, x1, 1
            `INSTR_PATH.rom[4] = {IMM12_0, RS1, `FNC_SLTU,    5'd7, `OPC_ARI_ITYPE}; // sltiu x7, x1, 1
            `INSTR_PATH.rom[5] = {IMM12_0, RS1, `FNC_XOR,     5'd8, `OPC_ARI_ITYPE}; // xori  x8, x1, 1
            // 32'b  f7_ shamt _ rs1 _f3 _ rd _ op // I-Type
            `INSTR_PATH.rom[6] = {`FNC7_0, SHAMT, RS1, `FNC_SLL,     5'd9,  `OPC_ARI_ITYPE}; // slli x9  x1 << 1
            `INSTR_PATH.rom[7] = {`FNC7_0, SHAMT, RS1, `FNC_SRL_SRA, 5'd10, `OPC_ARI_ITYPE}; // srli x10 x1 >> 1
            `INSTR_PATH.rom[8] = {`FNC7_1, SHAMT, RS1, `FNC_SRL_SRA, 5'd11, `OPC_ARI_ITYPE}; // srai x11 x1 >>> 1

            reset_cpu();

            #10; check_result_RF(3,  32'h0000_1011, "I-Type ADDI");
            #10; check_result_RF(4,  32'h0000_0000, "I-Type ANDI");
            #10; check_result_RF(5,  32'h0000_1011, "I-Type ORI");
            #10; check_result_RF(6,  32'h0000_0000, "I-Type SLTI");
            #10; check_result_RF(7,  32'h0000_0000, "I-Type SLTIU");
            #10; check_result_RF(8,  32'h0000_1011, "I-Type XORI");
            #10; check_result_RF(9,  32'h0000_2020, "I-Type SLLI");
            #10; check_result_RF(10, 32'h0000_0808, "I-Type SRLI");
            #10; check_result_RF(11, 32'h0000_0808, "I-Type SRAI");
            
        end

        if (0) begin
        // Test B-Type Insts --------------------------------------------------
        // - BEQ, BNE, BLT, BGE, BLTU, BGEU

        IMM       = 32'h0000_0008;
        JUMP_ADDR = IMM >> 2;

        BR_TYPE[0]     = `FNC_BEQ;
        BR_NAME_TK1[0] = "B-Type BEQ Taken 1";
        BR_NAME_TK2[0] = "B-Type BEQ Taken 2";
        BR_NAME_NTK[0] = "B-Type BEQ Not Taken";

        BR_TAKEN_OP1[0]  = 100; BR_TAKEN_OP2[0]  = 100;
        BR_NTAKEN_OP1[0] = 100; BR_NTAKEN_OP2[0] = 200;

        BR_TYPE[1]       = `FNC_BNE;
        BR_NAME_TK1[1]   = "B-Type BNE Taken 1";
        BR_NAME_TK2[1]   = "B-Type BNE Taken 2";
        BR_NAME_NTK[1]   = "B-Type BNE Not Taken";
        BR_TAKEN_OP1[1]  = 100; BR_TAKEN_OP2[1]  = 200;
        BR_NTAKEN_OP1[1] = 100; BR_NTAKEN_OP2[1] = 100;

        BR_TYPE[2]       = `FNC_BLT;
        BR_NAME_TK1[2]   = "B-Type BLT Taken 1";
        BR_NAME_TK2[2]   = "B-Type BLT Taken 2";
        BR_NAME_NTK[2]   = "B-Type BLT Not Taken";
        BR_TAKEN_OP1[2]  = 100; BR_TAKEN_OP2[2]  = 200;
        BR_NTAKEN_OP1[2] = 200; BR_NTAKEN_OP2[2] = 100;

        BR_TYPE[3]       = `FNC_BGE;
        BR_NAME_TK1[3]   = "B-Type BGE Taken 1";
        BR_NAME_TK2[3]   = "B-Type BGE Taken 2";
        BR_NAME_NTK[3]   = "B-Type BGE Not Taken";
        BR_TAKEN_OP1[3]  = 300; BR_TAKEN_OP2[3]  = 200;
        BR_NTAKEN_OP1[3] = 100; BR_NTAKEN_OP2[3] = 200;

        BR_TYPE[4]       = `FNC_BLTU;
        BR_NAME_TK1[4]   = "B-Type BLTU Taken 1";
        BR_NAME_TK2[4]   = "B-Type BLTU Taken 2";
        BR_NAME_NTK[4]   = "B-Type BLTU Not Taken";
        BR_TAKEN_OP1[4]  = 32'h0000_0001; BR_TAKEN_OP2[4]  = 32'hFFFF_0000;
        BR_NTAKEN_OP1[4] = 32'hFFFF_0000; BR_NTAKEN_OP2[4] = 32'h0000_0001;

        BR_TYPE[5]       = `FNC_BGEU;
        BR_NAME_TK1[5]   = "B-Type BGEU Taken 1";
        BR_NAME_TK2[5]   = "B-Type BGEU Taken 2";
        BR_NAME_NTK[5]   = "B-Type BGEU Not Taken";
        BR_TAKEN_OP1[5]  = 32'hFFFF_0000; BR_TAKEN_OP2[5]  = 32'h0000_0001;
        BR_NTAKEN_OP1[5] = 32'h0000_0001; BR_NTAKEN_OP2[5] = 32'hFFFF_0000;

        for (int i = 0; i < 6; i = i + 1) begin
            init();
  
            `RF_PATH.mem[1] = BR_TAKEN_OP1[i];
            `RF_PATH.mem[2] = BR_TAKEN_OP2[i];
            `RF_PATH.mem[3] = 300;
            `RF_PATH.mem[4] = 400;
  
            `INSTR_PATH.rom[0]   = {IMM[12], IMM[10:5], 5'd2, 5'd1, BR_TYPE[i], IMM[4:1], IMM[11], `OPC_BRANCH};
            `INSTR_PATH.rom[1]   = {`FNC7_0, 5'd4, 5'd3, `FNC_ADD_SUB, 5'd5, `OPC_ARI_RTYPE};
            `INSTR_PATH.rom[JUMP_ADDR[13:0]] = {`FNC7_0, 5'd4, 5'd3, `FNC_ADD_SUB, 5'd6, `OPC_ARI_RTYPE};
  
            reset_cpu();
  
            check_result_RF(5'd5, 0,   BR_NAME_TK1[i]);
            check_result_RF(5'd6, 700, BR_NAME_TK2[i]);
  
            init();
  
            `RF_PATH.mem[1] = BR_NTAKEN_OP1[i];
            `RF_PATH.mem[2] = BR_NTAKEN_OP2[i];
            `RF_PATH.mem[3] = 300;
            `RF_PATH.mem[4] = 400;
  
            `INSTR_PATH.rom[0] = {IMM[12], IMM[10:5], 5'd2, 5'd1, BR_TYPE[i], IMM[4:1], IMM[11], `OPC_BRANCH};
            `INSTR_PATH.rom[1] = {`FNC7_0, 5'd4, 5'd3, `FNC_ADD_SUB, 5'd5, `OPC_ARI_RTYPE};
 
            reset_cpu();
            check_result_RF(5'd5, 700, BR_NAME_NTK[i]);
        end
    end

    if (0) begin
    // Test U-Type Insts --------------------------------------------------
    // - LUI, AUIPC
        init();

        IMM = 32'h7FFF_0123;

        `INSTR_PATH.rom[0] = {IMM[31:12], 5'd3, `OPC_LUI};
        `INSTR_PATH.rom[1] = {IMM[31:12], 5'd4, `OPC_AUIPC};

        reset_cpu();

        check_result_RF(3, 32'h7fff0000, "U-Type LUI");
        check_result_RF(4, 32'h7fff0004, "U-Type AUIPC");
    end

    if (0) begin
    // Test J-Type Insts --------------------------------------------------
    // - JAL
    
        init();

        `RF_PATH.mem[1] = 100;
        `RF_PATH.mem[2] = 200;
        `RF_PATH.mem[3] = 300;
        `RF_PATH.mem[4] = 400;

        IMM       = 32'h0000_0010;
        JUMP_ADDR = {IMM[20:1], 1'b0} >> 2;

        `INSTR_PATH.rom[0]   = {IMM[20], IMM[10:1], IMM[11], IMM[19:12], 5'd5, `OPC_JAL};
        `INSTR_PATH.rom[1]   = {`FNC7_0, 5'd2, 5'd1, `FNC_ADD_SUB, 5'd6, `OPC_ARI_RTYPE};
        `INSTR_PATH.rom[JUMP_ADDR[13:0]] = {`FNC7_0, 5'd4, 5'd3, `FNC_ADD_SUB, 5'd7, `OPC_ARI_RTYPE};

        reset_cpu();

        check_result_RF(5'd5, 32'h0000_0004, "J-Type JAL");
        check_result_RF(5'd7, 700,          "J-Type JAL");
        check_result_RF(5'd6, 0,            "J-Type JAL");
    end

    if (0) begin
    // Test J-Type Insts --------------------------------------------------
    // - JALR
        init();

        `RF_PATH.mem[1] = 32'h0000_0008;
        `RF_PATH.mem[2] = 200;
        `RF_PATH.mem[3] = 300;
        `RF_PATH.mem[4] = 400;
        `RF_PATH.mem[6] = 32'h0000_0000; // RD6 ì´ê¸°ê°? 0

        IMM       = 32'h0000_0010;
        JUMP_ADDR = (`RF_PATH.mem[1] + IMM) >> 2;

        `INSTR_PATH.rom[0]   = {IMM[11:0], 5'd1, 3'b000, 5'd5, `OPC_JALR};
        `INSTR_PATH.rom[1]   = {`FNC7_0,   5'd2, 5'd1, `FNC_ADD_SUB, 5'd6, `OPC_ARI_RTYPE};
        `INSTR_PATH.rom[JUMP_ADDR[13:0]] = {`FNC7_0,   5'd4, 5'd3, `FNC_ADD_SUB, 5'd7, `OPC_ARI_RTYPE};

        reset_cpu();

        check_result_RF(5'd5, 32'h0000_0004, "J-Type JALR");
        check_result_RF(5'd7, 700,          "J-Type JALR");
        check_result_RF(5'd6, 0,            "J-Type JALR");
    end

    all_passed = 1'b1;

    repeat(10) @(posedge clk);
    $display("All tests passed!");
    $finish();

    end

endmodule
