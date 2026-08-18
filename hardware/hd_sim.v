// hd_sim.v — HD simulado com organização por setores
//
// Simula um disco rígido com N setores de tamanho fixo.
// Interface memory-mapped: o kernel escreve comando, setor e endereço
// em posições fixas da RAM, e o controlador executa a transferência.
//
// Organização:
//   Setor 0:     Catálogo de programas (metadados)
//   Setor 1-10:  Binários dos programas (1 por setor)
//
// O conteúdo inicial é carregado de um arquivo na simulação/síntese.

module hd_sim #(
    parameter NUM_SECTORS   = 16,
    parameter SECTOR_SIZE   = 256,           // palavras por setor
    parameter DATA_W        = 32,
    parameter HD_FILE       = "hd_init.txt"  // conteúdo inicial
)(
    input  wire                clk,
    input  wire                rst,

    // Interface de comando (vem da RAM mapeada)
    input  wire [DATA_W-1:0]  cmd,           // 0=nop, 1=ler, 2=escrever
    input  wire [DATA_W-1:0]  sector,        // setor alvo
    input  wire [DATA_W-1:0]  mem_addr,      // endereço base na memória
    input  wire               cmd_valid,     // pulso: novo comando
    output reg  [DATA_W-1:0]  status,        // 0=idle, 1=busy, 2=done, 3=erro

    // Interface de transferência com a memória
    output reg                xfer_wr,       // escrita na memória (leitura do HD)
    output reg                xfer_rd,       // leitura da memória (escrita no HD)
    output reg  [9:0]         xfer_addr,     // endereço na memória
    output reg  [DATA_W-1:0]  xfer_wdata,    // dados para a memória
    input  wire [DATA_W-1:0]  xfer_rdata     // dados da memória
);

    reg [DATA_W-1:0] disk [0:NUM_SECTORS*SECTOR_SIZE-1];

    reg [1:0]  state;        // 0=idle, 1=transferindo, 2=done
    reg [1:0]  op;           // 1=ler, 2=escrever
    reg [15:0] sector_reg;
    reg [9:0]  base_addr;
    reg [8:0]  word_idx;     // posição dentro do setor

    localparam S_IDLE = 2'd0, S_XFER = 2'd1, S_DONE = 2'd2;

    initial begin
        $readmemb(HD_FILE, disk);
    end

    always @(posedge clk) begin
        if (rst) begin
            state     <= S_IDLE;
            status    <= 0;
            xfer_wr   <= 0;
            xfer_rd   <= 0;
            word_idx  <= 0;
        end else begin
            xfer_wr <= 0;
            xfer_rd <= 0;

            case (state)
                S_IDLE: begin
                    if (cmd_valid) begin
                        op         <= cmd[1:0];
                        sector_reg <= sector[15:0];
                        base_addr  <= mem_addr[9:0];
                        word_idx   <= 0;
                        status     <= 1;
                        state      <= S_XFER;
                    end
                end

                S_XFER: begin
                    if (word_idx < SECTOR_SIZE) begin
                        if (op == 1) begin
                            // Ler HD → memória
                            xfer_wr    <= 1;
                            xfer_addr  <= base_addr + word_idx[8:0];
                            xfer_wdata <= disk[sector_reg * SECTOR_SIZE + word_idx];
                        end else begin
                            // Escrever memória → HD
                            xfer_rd   <= 1;
                            xfer_addr <= base_addr + word_idx[8:0];
                            // Captura no próximo ciclo:
                            if (xfer_rd)
                                disk[sector_reg * SECTOR_SIZE + word_idx - 1] <= xfer_rdata;
                        end
                        word_idx <= word_idx + 1;
                    end else begin
                        state  <= S_DONE;
                        status <= 2;
                    end
                end

                S_DONE: begin
                    status <= 0;
                    state  <= S_IDLE;
                end
            endcase
        end
    end

endmodule
