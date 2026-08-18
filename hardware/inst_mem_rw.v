// inst_mem_rw.v — Memória de instrução com suporte a escrita
//
// Substitui single_port_rom.v no top-level do processador.
// Durante boot/carregamento de programas, o kernel pode escrever
// instruções via porta de escrita. Durante execução normal, funciona
// como memória read-only para o PC.
//
// Porta A: leitura pelo PC (fetch de instrução)
// Porta B: escrita pelo kernel (carregamento de programa)
//
// Controle: wr_en_b é ativado apenas quando o SO está carregando
// um programa do HD para um slot de execução.

module inst_mem_rw #(
    parameter ADDR_W   = 10,                 // 1024 palavras
    parameter DATA_W   = 32,
    parameter FILENAME = "so.txt"            // Binário inicial (kernel)
)(
    input  wire                 clk,

    // Porta A — Fetch (read-only)
    input  wire [ADDR_W-1:0]   addr_a,
    output reg  [DATA_W-1:0]   data_a,

    // Porta B — Carregamento (write)
    input  wire                 wr_en_b,
    input  wire [ADDR_W-1:0]   addr_b,
    input  wire [DATA_W-1:0]   data_b
);

    reg [DATA_W-1:0] mem [0:(1<<ADDR_W)-1];

    initial begin
        $readmemb(FILENAME, mem, 0, 511);    // Kernel nas primeiras 512 palavras
    end

    // Porta A — leitura combinacional (monociclo)
    always @(*) begin
        data_a = mem[addr_a];
    end

    // Porta B — escrita síncrona
    always @(posedge clk) begin
        if (wr_en_b)
            mem[addr_b] <= data_b;
    end

endmodule
