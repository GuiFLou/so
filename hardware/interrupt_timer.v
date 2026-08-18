// interrupt_timer.v — Timer de quantum para preempção (Fase 2)
//
// Conta instruções executadas. Ao atingir o quantum:
//   1. Salva PC atual em registrador especial (saved_pc)
//   2. Força PC para HANDLER_ADDR (endereço do handler do SO)
//   3. Seta kernel_mode (desativa contagem)
//
// O SO limpa kernel_mode ao devolver controle a um processo.
//
// Interface:
//   - Conectado ao PC e ao clock do processador
//   - kernel_mode: entrada do SO (1=não contar, 0=contar)
//   - interrupt: saída pulsada quando quantum estoura

module interrupt_timer #(
    parameter HANDLER_ADDR = 32'h00000100,   // Endereço do handler na ROM
    parameter DEFAULT_QUANTUM = 32           // Instruções por fatia
)(
    input  wire        clk,
    input  wire        rst,

    // Controle
    input  wire        kernel_mode,          // 1 = SO executando (não interromper)
    input  wire        enable,               // 1 = timer ativo
    input  wire [31:0] quantum_val,          // valor do quantum (configurável)

    // Interface com o PC
    input  wire [31:0] pc_current,           // PC atual
    output reg  [31:0] saved_pc,             // PC salvo na interrupção
    output reg         interrupt,            // pulso: quantum estourou
    output reg  [31:0] forced_pc             // novo PC (HANDLER_ADDR)
);

    reg [31:0] counter;

    always @(posedge clk) begin
        if (rst) begin
            counter   <= 0;
            interrupt <= 0;
            saved_pc  <= 0;
            forced_pc <= 0;
        end else begin
            interrupt <= 0;

            if (enable && !kernel_mode) begin
                if (counter < quantum_val) begin
                    counter <= counter + 1;
                end else begin
                    // Quantum estourou
                    interrupt <= 1;
                    saved_pc  <= pc_current;
                    forced_pc <= HANDLER_ADDR;
                    counter   <= 0;
                end
            end

            if (kernel_mode) begin
                counter <= 0;
            end
        end
    end

endmodule
