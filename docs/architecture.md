# Arquitetura do SO Simples

## 1. Visão geral

O SO é um programa C- monolítico (`so.cms`) que roda no processador MIPS-Lite.
A linguagem C- não tem `#include`, structs, strings nem linker — todo o kernel
é um único arquivo com funções organizadas em seções lógicas.

### Restrições da plataforma

| Aspecto | Limitação |
|---------|-----------|
| Linguagem | C-: apenas `int`, `void`, arrays de `int`, `input()`/`output()` |
| ROM | 1024 palavras × 32 bits (instrução) |
| RAM | 1024 palavras × 32 bits (dados) |
| Registradores | 64 × 32 bits (`$t0`–`$t9`, `$sp`, `$gp`, `$ra`, `$fp`, etc.) |
| I/O | IN (switches 10 bits), OUT (7 segmentos) |
| Clock | Monociclo, ~2–100 Hz configurável |
| Operador `%` | Não existe em C- — usar `a - (a / b) * b` |

## 2. Camadas do sistema

```
┌─────────────────────────────────────┐
│  Camada 3: Shell / Menu             │  ← Interação com o usuário
│  output(código), input() → opção    │
├─────────────────────────────────────┤
│  Camada 2: Serviços do Kernel       │
│  ┌─────────┬────────┬────────────┐  │
│  │Processos│Arquivos│    I/O     │  │
│  │(PCB, RR)│(CRUD)  │(IN/OUT/HD) │  │
│  └─────────┴────────┴────────────┘  │
├─────────────────────────────────────┤
│  Camada 1: Abstração de Hardware    │
│  hd_read/write, load_program,      │
│  save/restore_context               │
├─────────────────────────────────────┤
│  Camada 0: Hardware (Verilog)       │
│  inst_mem_rw, hd_sim, int_timer     │
└─────────────────────────────────────┘
```

## 3. Estruturas de dados em C-

C- não tem structs. Toda estrutura é representada com **arrays paralelos**.

### PCB — Process Control Block

```
int proc_state[4];      estado: 0=livre, 1=pronto, 2=executando
int proc_pc[4];          PC salvo
int proc_sp[4];          SP salvo
int proc_rom_base[4];    endereço base na ROM
int proc_data_base[4];   endereço base na RAM
```

Índice do array = PID (0 a 3). Máximo 4 processos simultâneos
(limitado pela memória disponível).

### Catálogo de programas (no HD)

```
int cat_id[10];          identificador numérico do programa
int cat_sector[10];      setor inicial no HD
int cat_size[10];        tamanho em palavras
int cat_count;           total de programas no catálogo
```

### Contexto de registradores (Fase 2)

```
int ctx[64];             4 processos × 16 registradores
                         ctx[pid * 16 + reg_idx] = valor
```

## 4. Fluxo de boot

```
Power-on / Reset
    │
    ▼
 main()
    │
    ├── bios_selftest()        ← Teste de RAM (escrita/leitura padrão)
    ├── bios_load_catalog()    ← Lê setor 0 do HD → preenche cat_*[]
    ├── init_procs()           ← Zera tabela de processos
    │
    ▼
 menu()  ← Loop principal (while running)
    │
    ├── output(10)             ← Exibe "menu pronto"
    ├── op = input()           ← Lê opção dos switches
    │
    ├── op==1 → run_single()   ← Carrega programa do HD, executa
    ├── op==2 → run_multi()    ← Fase 2: round-robin
    ├── op==3 → list_programs()
    ├── op==4 → rename_program()
    ├── op==5 → delete_program()
    └── op==0 → HALT
```

## 5. Execução de 1 programa (Fase 1)

1. Usuário escolhe opção 1, informa ID do programa
2. Kernel busca no catálogo o setor do HD
3. HD controller copia binário do HD → memória de instrução (slot de execução)
4. Kernel ajusta PC para o endereço base do slot
5. Programa executa até HLT
6. Kernel retoma controle e volta ao menu

**Requisito de hardware:** A memória de instrução (`inst_mem_rw.v`) precisa
aceitar escrita pelo kernel durante a fase de carregamento e ser read-only
durante a execução normal.

## 6. Multitarefa com preempção (Fase 2)

### Round-Robin

1. Cada processo recebe um **quantum** de N instruções
2. Hardware (`interrupt_timer.v`) conta instruções executadas
3. Ao estourar o quantum:
   - Timer salva PC atual em registrador especial
   - Timer força PC = endereço fixo do handler do SO
   - Timer desativa contagem (modo kernel)
4. Handler do SO:
   - Salva contexto completo (registradores) do processo atual
   - Seleciona próximo processo pronto (round-robin circular)
   - Restaura contexto do próximo processo
   - Reativa timer com novo quantum
   - Salta para o PC restaurado

### Modo Kernel

O timer **não deve** interromper o próprio SO. Um flip-flop `kernel_mode`:
- Setado quando o handler é ativado (interrupt)
- Limpo quando o SO devolve controle ao processo (restaura PC)
- Enquanto setado, o contador de quantum não decrementa

## 7. Interface com o HD

O HD é simulado em Verilog (`hd_sim.v`) com organização trilha/setor.

### Interface memory-mapped

O kernel se comunica com o HD controller escrevendo em endereços
fixos da RAM:

| Endereço RAM | Nome      | Uso                              |
|--------------|-----------|----------------------------------|
| 1020         | HD_CMD    | Comando: 1=ler, 2=escrever       |
| 1021         | HD_SECTOR | Setor de origem/destino           |
| 1022         | HD_ADDR   | Endereço base na memória destino  |
| 1023         | HD_STATUS | Status: 0=idle, 1=busy, 2=done   |

O HD controller em Verilog intercepta escritas nesses endereços
e realiza a transferência de dados.

## 8. Alterações necessárias no processador

| Módulo | Alteração | Motivo |
|--------|-----------|--------|
| `single_port_rom.v` | Substituir por `inst_mem_rw.v` | Permitir escrita (carga de programas) |
| `data_ram.v` | Interceptar endereços 1020–1023 | Interface memory-mapped para HD |
| **Novo:** `hd_sim.v` | Módulo completo | Simular armazenamento persistente |
| **Novo:** `interrupt_timer.v` | Módulo completo (Fase 2) | Quantum + interrupção |
| `Processador_GUI_MIPS.v` | Integrar novos módulos | Top-level |
