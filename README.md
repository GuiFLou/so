# SO Simples — MIPS-Lite

Sistema operacional simples escrito em C-, compilado pelo compilador C- do projeto e executado no processador MIPS-Lite (FPGA DE2-115).

## Arquitetura

```
┌──────────────────────────────────────────────┐
│                  Shell/Menu                   │
│     (LCD = menu / 7-seg = OUT / input = SW)  │
├──────────────────────────────────────────────┤
│  Processos  │  Memória  │  I/O  │  Arquivos  │
│  (PCB, RR)  │ (mapa)    │(IN/OUT)│ (CRUD/HD) │
├──────────────────────────────────────────────┤
│              Kernel (so.cms)                  │
├──────────────────────────────────────────────┤
│         Hardware (Verilog)                    │
│   inst_mem_rw  │  hd_sim  │  interrupt_timer │
├──────────────────────────────────────────────┤
│         Processador MIPS-Lite                 │
└──────────────────────────────────────────────┘
```

## Estrutura do repositório

```
so/
├── docs/
│   ├── notes.md            # Notas originais do projeto
│   ├── architecture.md     # Arquitetura detalhada do SO
│   ├── memory_map.md       # Mapa de memória (ROM/RAM/HD)
│   └── dev_plan.md         # Plano de desenvolvimento
├── src/
│   └── so.cms              # Kernel completo em C-
```

Os testes desta etapa ficam no repositório do processador: `tb_lcd`,
`tb_hd_map` e `tb_hd_stall`.

O hardware permanece no repositório [`../processador`](../processador) e o
compilador, as fontes dos algoritmos e os binários de teste permanecem em
[`../compilador`](../compilador). O repositório do SO contém o kernel e a
documentação.

## Fases do projeto

### Fase 1 — MVP
- [x] Mapa de memória definido (4096 palavras; kernel, folha da vez e supervisor co-residentes)
- [x] Atualizar a estrutura do processador para esse mapa: IMEM e RAM de 4096 palavras; kernel em 0–3071, folha da vez em 3072–3839, supervisor em 3840–4095; RAM com dados do kernel, janela do programa, mailbox e MMIO em 4088–4095
- [x] HD simulado em Verilog (`hd_sim.v`), integrado no top-level
- [x] Memória de instrução gravável (`inst_mem_rw.v`), integrada no top-level
- [x] LCD com mensagens fixas (`display_ctx` no endereço 4091)
- [x] Sem BIOS: o reset busca `so.txt` na IMEM (hoje NOP até 3070 e `J 3071` na última palavra do kernel)
- [x] Remontar `hd_image.txt` (catálogo no setor 0, kernel em NOP nos setores 1–12, programas nos setores 20–29, janelas dos PIDs zeradas)
- [ ] Menu/Shell com códigos numéricos no LCD
- [ ] Executar 1 programa (sem preempção)
- [ ] CRUD de programas (criar, listar, renomear, deletar)

### Fase 2 — Multitarefa com preempção
- [ ] Timer de quantum em Verilog (`interrupt_timer.v`)
- [ ] Flag de modo kernel (não interromper o SO)
- [ ] Tabela de processos (PCB em arrays paralelos)
- [ ] Salvar/restaurar contexto (registradores + PC)
- [ ] Escalonador round-robin
- [ ] Executar N programas concorrentemente

## Como compilar

`processador/so.txt` é a imagem de reset, com 4096 palavras. O topo a carrega
por `ROM_FILE`. Enquanto o kernel não é compilado, as palavras 0–3070 são NOP
e a palavra 3071 é `J 3071`.

Quando existir o binário `os-kernel`, ele substitui as palavras 0–3070 desse
arquivo e dos setores 1–12 de `hd_image.txt`. O salto de guarda permanece em
3071. O compilador ainda não tem o alvo `os-kernel`.

## Dependências

- **Compilador C-**: `../compilador/` (gera binários `.txt`)
- **Processador MIPS-Lite e hardware**: `../processador/`
- **Intel Quartus**: Síntese dos módulos Verilog de hardware
- **Icarus Verilog**: Simulação dos testbenches

## LCD (hardware já integrado)

O kernel escreve o modo em `display_ctx` (endereço 4091). O catálogo fixo é:

| Modo | Linha 1 | Uso |
|------|---------|-----|
| 1 | `MENU` | opções RUN, MLT, LST, REN, DEL (KEY[2]/KEY[3]) |
| 2 | `ID?` | ID numérico na linha 2 |
| 3 | `RUN` | ID e PID em execução |
| 4 | `OK` | operação aceita |
| 5 | `ERR` | operação recusada |

KEY[1] confirma e não muda o índice. O 7-seg continua sendo a saída de `OUT`.

## Convenções numéricas do menu (7-seg, ainda não ligadas ao LCD)

| Código exibido | Significado                |
|----------------|----------------------------|
| `10`           | Menu pronto — aguarda opção |
| `11`           | Insira ID do programa       |
| `41`           | Insira ID atual (renomear)  |
| `42`           | Insira novo ID (renomear)   |
| `51`           | Insira ID para deletar      |
| `111`          | Código antigo de diagnóstico; não há BIOS |
| `800`          | Programa executou com sucesso |
| `900`          | Erro: programa não encontrado |
| `0`            | Sistema desligado            |

### Opções do menu (via switches)

| Switch | Ação                     |
|--------|--------------------------|
| `1`    | Executar 1 programa      |
| `2`    | Executar multitarefa     |
| `3`    | Listar programas         |
| `4`    | Renomear programa        |
| `5`    | Deletar programa         |
| `0`    | Desligar (HALT)          |
