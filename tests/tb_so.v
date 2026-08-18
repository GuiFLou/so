// tb_so.v — Testbench de integração do SO
//
// Simula o processador MIPS-Lite rodando o kernel do SO.
// Para Fase 1: valida boot, menu e execução de 1 programa.
//
// Uso:
//   iverilog -o sim_so tb_so.v \
//     ../processador/Processador_GUI_MIPS.v \
//     ../processador/control_unit.v \
//     ../processador/alu.v \
//     ../processador/regfile64.v \
//     ../processador/data_ram.v \
//     ../processador/sign_extend.v \
//     ../processador/divisor_freq.v \
//     ../processador/debounce.v \
//     ../processador/bin32_to_bcd7.v \
//     ../processador/hex7seg.v \
//     ../processador/inst_mem_rw.v \
//     ../processador/hd_sim.v
//   vvp sim_so

`timescale 1ns / 1ps

module tb_so;

    parameter CLK_PERIOD = 20;   // 50 MHz
    parameter CPU_DIV    = 1;    // clock rápido para simulação
    parameter BTN_STABLE = 2;

    reg         CLOCK_50;
    reg  [17:0] SW;
    reg  [3:0]  KEY;
    wire [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6;
    wire [17:0] LEDR;

    // TODO: instanciar processador com ../processador/inst_mem_rw.v
    // no lugar de single_port_rom e conectar ../processador/hd_sim.v à RAM
    //
    // Por enquanto, instanciar processador original para validar
    // que o kernel compila e o boot sequence roda.

    Processador_GUI_MIPS #(
        .CPU_DIV(CPU_DIV),
        .BTN_STABLE(BTN_STABLE),
        .ROM_FILE("so.txt")
    ) uut (
        .CLOCK_50(CLOCK_50),
        .SW(SW),
        .KEY(KEY),
        .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2),
        .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5),
        .HEX6(HEX6),
        .LEDR(LEDR)
    );

    // Clock
    initial CLOCK_50 = 0;
    always #(CLK_PERIOD/2) CLOCK_50 = ~CLOCK_50;

    initial begin
        $dumpfile("so_trace.vcd");
        $dumpvars(0, tb_so);

        // Reset
        KEY = 4'b1111;
        SW  = 18'd0;
        #100;
        KEY[0] = 0;          // reset ativo (ativo-baixo)
        #200;
        KEY[0] = 1;          // libera reset
        #100;

        // Aguardar BIOS (output 111)
        #5000;

        // Simular: usuário escolhe opção 0 (desligar)
        SW[9:0] = 10'd0;
        KEY[1] = 0;          // enter
        #200;
        KEY[1] = 1;
        #5000;

        // Verificar HALT
        if (LEDR[16]) begin
            $display("OK: processador em HALT");
        end else begin
            $display("AVISO: processador nao entrou em HALT");
        end

        #1000;
        $finish;
    end

endmodule
