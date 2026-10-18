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

A gestão de processos pesa mais na nota, então a execução e o escalonamento vêm antes do CRUD. Os dez programas já estão na imagem do HD; criar, renomear e apagar não desbloqueiam nem a execução individual nem a multitarefa.

### Base (concluída)
- [x] Mapa de memória definido (4096 palavras; kernel, folha da vez e supervisor co-residentes)
- [x] Atualizar a estrutura do processador para esse mapa: IMEM e RAM de 4096 palavras; kernel em 0–3071, folha da vez em 3072–3839, supervisor em 3840–4095; RAM com dados do kernel, janela do programa, mailbox e MMIO em 4088–4095
- [x] HD simulado em Verilog (`hd_sim.v`), integrado no top-level
- [x] Memória de instrução gravável (`inst_mem_rw.v`), integrada no top-level
- [x] LCD com mensagens fixas (`display_ctx` no endereço 4091)
- [x] Sem BIOS: o reset busca `so.txt` na IMEM (hoje NOP até 3070 e `J 3071` na última palavra do kernel)
- [x] Remontar `hd_image.txt` (catálogo no setor 0, kernel em NOP nos setores 1–12, programas nos setores 20–29, janelas dos PIDs zeradas)

### Fase 1 — Execução individual
O usuário seleciona um programa pelo LCD, executa só esse programa e, ao terminar, volta ao menu para escolher outro. Os IDs são os já gravados na imagem.

- [x] Menu no LCD: boas-vindas, três opções, lista dos dez programas, quantidade e a tela de arquivos. A opção de um programa mostra RUN e ainda não carrega o HD
- [ ] Carregar o programa escolhido do HD para a folha da vez e desviar o PC
- [ ] Executar 1 programa (sem preempção) e voltar ao menu após o término

### Fase 2 — Multitarefa com preempção
O usuário escolhe N programas e o SO os executa com interrupção por quantum.

- [ ] Timer de quantum em Verilog (`interrupt_timer.v`)
- [ ] Flag de modo kernel (não interromper o SO)
- [ ] Tabela de processos (PCB em arrays paralelos)
- [ ] Salvar/restaurar contexto (registradores + PC)
- [ ] Escalonador round-robin
- [ ] Executar N programas concorrentemente

### Fase 3 — CRUD de arquivos
- [ ] Criar, listar, renomear e deletar programas no catálogo do HD

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

## LCD

O kernel grava uma palavra em `display_ctx`, no endereço 4091. O Verilog desenha o texto. O programa não envia caracteres.

A escrita leva o modo nos bits 7 a 0, o identificador nos bits 17 a 8 e o PID nos bits 21 a 18. Toda escrita zera o bit 27, que é a confirmação. Se o modo mudar, o índice volta a zero. O mesmo modo conserva o índice. A leitura devolve também o índice, nos bits 26 a 22. Os bits 31 a 28 ficam em zero.

KEY[3] avança e KEY[2] recua, com volta, só quando a tela tem mais de um item e a CPU não está parada em `IN` ou `OUT`. KEY[1] liga a confirmação e não muda o índice. O aperto que solta um `IN` ou um `OUT` não confirma o menu. KEY[0] é o reset da placa, ativo em nível baixo.

| Modo | Itens | Linha 1 | Linha 2 |
|------|-------|---------|---------|
| 1 | 3 | `MENU` | `>1 RUN`, `>2 MLT` ou `>3 ARQ` |
| 2 | 1 | `BEM-VINDO` | `SO` |
| 3 | 1 | `RUN` | identificador em quatro dígitos e PID; PID acima de 9 vira traço |
| 4 | 1 | `OK` | em branco |
| 5 | 1 | `ERR` | em branco |
| 6 | 10 | `PROG` | `>`, quatro dígitos do identificador e o nome do índice |
| 7 | 10 | `QUANTOS` | `>01` a `>10`, iguais ao índice mais um |
| 8 | 1 | `ARQUIVOS` | `FASE 3` |

Os nomes, na ordem do índice, são AREA, BUSCA, FAT, FIB, GCD, MEDIA, PRIMO, POT, DIG e SORT. Os dígitos vêm do identificador escrito pelo kernel: 1 a 10, setores 20 a 29, na mesma ordem.

No `so.cms`, o arranque mostra boas-vindas e espera KEY[1]. A primeira opção lista um programa e, no Enter, mostra RUN com o PID vazio. Não copia o setor nem desvia o PC. A segunda pergunta quantos programas e, depois de escolhê-los, mostra ERR, porque a preempção ainda não existe. A terceira avisa que arquivos ficam para a fase 3. O menu não chama `input()` nem `output()`: as duas instruções também esperam KEY[1].

O sete segmentos continua sendo a saída de `OUT`. Os códigos 10, 11, 41, 42, 51, 111, 800 e 900 eram o menu antigo, feito com switches. O menu do LCD não os mostra.

O compilador expõe `lcdshow(modo, id, pid)`, `lcdack()` e `lcdsel()`. `loadHD`, `storeHD` e `loadROM` ainda usam 1020 a 1023. O hardware do disco está em 4092 a 4095. A troca de endereço espera o teste que copiar um setor.
