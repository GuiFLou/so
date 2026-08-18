# Decisões de Arquitetura

Registro das decisões tomadas durante o projeto do SO.
Cada entrada é imutável após escrita — novas decisões que revisem
anteriores referenciam o ID original.

---

## ADR-001: Kernel monolítico em arquivo único

**Data:** 2026-08-17
**Status:** Aceita

**Contexto:** C- não possui `#include`, linker, nem compilação multi-arquivo.
O compilador gera um binário por `.cms`.

**Decisão:** Todo o kernel (BIOS, menu, CRUD, processos, escalonador) é um
único arquivo `src/so.cms`, organizado em seções por comentários.

**Consequências:**
- (+) Simples de compilar e depurar — um comando gera o binário completo.
- (-) Arquivo cresce conforme funcionalidades são adicionadas.
- (-) Não há reuso de código entre SO e programas de usuário.

---

## ADR-002: Estruturas de dados como arrays paralelos

**Data:** 2026-08-17
**Status:** Aceita

**Contexto:** C- não tem structs, unions, enums, nem ponteiros
tipados. O único tipo composto é `int[]`.

**Decisão:** Toda estrutura (PCB, catálogo de programas, contexto)
é representada por arrays paralelos de `int`, onde o índice é a chave:

```
int proc_state[4];
int proc_pc[4];       // proc_pc[pid] = PC salvo do processo pid
int proc_sp[4];
```

**Consequências:**
- (+) Funciona dentro das limitações de C-.
- (-) Sem verificação de tipo — um índice errado corrompe dados silenciosamente.
- (-) Máximo de processos e programas fixado em tempo de compilação.

---

## ADR-003: BIOS integrada ao main() do SO

**Data:** 2026-08-17
**Status:** Aceita

**Contexto:** A BIOS precisa rodar primeiro (endereço 0 da ROM).
Uma BIOS separada exigiria um bootloader para encadear dois binários
na mesma ROM, complexidade desnecessária para o escopo do projeto.

**Decisão:** A BIOS é uma sequência de funções chamadas no início
de `main()`: `bios_selftest()` → `bios_load_catalog()` → kernel init.

**Alternativa descartada:** Binário separado `bios.cms` + mecanismo
de salto para o endereço do kernel. Descartado por adicionar
complexidade de link sem benefício.

**Consequências:**
- (+) Um único binário, sem necessidade de bootloader.
- (+) Mais simples de testar — um testbench cobre tudo.
- (-) Não é possível atualizar BIOS e SO independentemente (aceitável).

---

## ADR-004: ROM gravável (inst_mem_rw.v) no lugar de single_port_rom

**Data:** 2026-08-17
**Status:** Aceita

**Contexto:** O processador original usa `single_port_rom.v` com
`$readmemb` — read-only após síntese. Para carregar programas do
HD para a memória de instrução em tempo de execução, a ROM precisa
aceitar escrita.

**Decisão:** Substituir `single_port_rom.v` por `inst_mem_rw.v`:
- Porta A: leitura pelo PC (fetch, combinacional).
- Porta B: escrita pelo kernel (síncrona, controlada por `wr_en_b`).
- Kernel nas primeiras 512 palavras carregado via `$readmemb` na inicialização.
- Slots de programa (512–1023) escritos em runtime pelo HD controller.

**Consequências:**
- (+) Permite carga dinâmica de programas do HD.
- (-) Mudança no top-level do processador (`Processador_GUI_MIPS.v`).
- (-) Cuidado para não sobrescrever código do kernel por bug.

---

## ADR-005: HD com interface memory-mapped na RAM

**Data:** 2026-08-17
**Status:** Aceita

**Contexto:** O processador só tem IN (switches) e OUT (7-seg) como
I/O. Adicionar instruções novas à ISA exigiria mudar compilador +
control unit. Memory-mapped I/O reutiliza `SW` e `LW` existentes.

**Decisão:** Reservar os 4 últimos endereços da RAM (1020–1023) como
portas de comando do HD controller:

| Endereço | Função |
|----------|--------|
| 1020 | HD_CMD (1=ler, 2=escrever) |
| 1021 | HD_SECTOR |
| 1022 | HD_ADDR (destino/origem) |
| 1023 | HD_STATUS (0=idle, 2=done) |

O módulo `data_ram.v` é modificado para interceptar escritas nesses
endereços e rotear para `hd_sim.v`.

**Alternativa descartada:** Nova instrução `SYSCALL` na ISA. Descartada
pois exigiria alterar compilador, encoder e control_unit — escopo
muito maior do que interceptar 4 endereços na RAM.

**Consequências:**
- (+) Zero mudanças na ISA e no compilador.
- (+) Kernel acessa HD com `SW` e `LW` simples.
- (-) Perdem-se 4 palavras de RAM (de 1024 para 1020 úteis).
- (-) `data_ram.v` precisa de lógica de decodificação extra.

---

## ADR-006: Menu por códigos numéricos no 7-seg

**Data:** 2026-08-17
**Status:** Aceita

**Contexto:** C- não tem strings. O FPGA DE2-115 exibe números nos
displays de 7 segmentos. Não há LCD disponível no design atual.

**Decisão:** O menu usa códigos numéricos convencionados:
- `10` = menu pronto, aguardando opção
- `11` = "insira ID do programa"
- `800` = programa executou OK
- `900` = programa não encontrado

O usuário seleciona opções via switches (0–5) e confirma com KEY[1].

**Consequências:**
- (+) Funciona com o hardware existente, sem módulos novos.
- (-) UX é limitada — requer tabela de códigos impressa/documentada.

---

## ADR-007: Faseamento — MVP sem preempção, Fase 2 com round-robin

**Data:** 2026-08-17
**Status:** Aceita

**Contexto:** As notas do projeto listam o MVP como: HD + BIOS +
modularização + CRUD. Multitarefa com preempção requer hardware
(timer de quantum) que ainda não existe.

**Decisão:** Dividir em duas fases:

| Fase | Escopo | Dependência de hardware |
|------|--------|-------------------------|
| 1 (MVP) | Boot, menu, execução única, CRUD | `inst_mem_rw`, `hd_sim` |
| 2 | Round-robin, contexto, preempção | `interrupt_timer`, modo kernel |

Na Fase 1, `run_single()` carrega e executa 1 programa por vez.
Na Fase 2, `run_multitask()` usa o escalonador com quantum.

**Consequências:**
- (+) MVP entregável sem depender de interrupt_timer.
- (+) Cada fase é testável independentemente.
- (-) Fase 1 não demonstra multitarefa (feature principal do projeto).

---

## ADR-008: Mapa de memória — kernel 512 palavras, 2 slots de 256

**Data:** 2026-08-17
**Status:** Aceita

**Contexto:** ROM tem 1024 palavras. O kernel compilado (com menu,
CRUD e processos) deve caber nas primeiras posições. Programas de
exemplo variam de ~18 (soma) a ~158 (sort) instruções.

**Decisão:**

| Região ROM | Tamanho | Uso |
|------------|---------|-----|
| 0–511 | 512 | Kernel (BIOS + SO) |
| 512–767 | 256 | Slot A (programa) |
| 768–1023 | 256 | Slot B (Fase 2) |

RAM: kernel em 0–127 (dados + pilha), processos em 128–1019,
HD I/O em 1020–1023.

**Riscos:**
- Se o kernel ultrapassar 512 instruções, o slot A precisa ser
  redimensionado. Monitorar tamanho a cada compilação.
- Sort (158 instruções) cabe em 256, mas programas futuros
  podem não caber. Nesse caso, unificar slots A+B em Fase 1.

---

## ADR-009: Máximo de 10 programas no catálogo, 4 processos simultâneos

**Data:** 2026-08-17
**Status:** Aceita

**Contexto:** Memória limitada para arrays globais. O projeto pede
10 algoritmos. Com 2 slots de ROM, no máximo 2 programas rodam
ao mesmo tempo (4 processos no PCB por margem).

**Decisão:**
- `cat_*[10]` — até 10 programas no HD.
- `proc_*[4]` — até 4 PCBs (2 slots + reserva).
- `ctx[64]` — 4 × 16 registradores para contexto.

**Consequências:**
- (+) Arrays cabem na região de 64 palavras do kernel na RAM.
- (-) Limites fixos — não há alocação dinâmica em C-.
