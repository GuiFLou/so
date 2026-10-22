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
│   └── CONTEXT.md          # Contexto local (fora do git)
├── relatorio/
│   └── relatorio_so.tex
└── src/
    └── so.cms              # Kernel em C-
```

Os testes desta etapa ficam no repositório do processador: `tb_lcd`,
`tb_hd_map`, `tb_hd_stall` e `tb_menu`.

O hardware permanece no repositório [`../processador`](../processador). O
compilador e as fontes ficam em [`../compilador`](../compilador).
`compilador/exemplos/` é a ROM solta: `reset_tests.sh` sem flag a regenera.
Os binários que o SO executa estão no processador, nos setores 20–29 de
`hd_image.txt`. Com `--target=os-user` o script grava só esses setores e não
mexe em `exemplos/`. O repositório do SO contém o kernel e a documentação.

## Fases do projeto

A gestão de processos pesa mais na nota, então a execução e o escalonamento vêm antes do CRUD. Os dez programas já estão na imagem do HD; criar, renomear e apagar não desbloqueiam nem a execução individual nem a multitarefa.

### Base (concluída)
- [x] Mapa de memória definido (4096 palavras; kernel, folha da vez e supervisor co-residentes)
- [x] Atualizar a estrutura do processador para esse mapa: IMEM e RAM de 4096 palavras; kernel em 0–3071, folha da vez em 3072–3839, supervisor em 3840–4095; RAM com dados do kernel, janela do programa, mailbox e MMIO em 4088–4095
- [x] HD simulado em Verilog (`hd_sim.v`), integrado no top-level
- [x] Memória de instrução gravável (`inst_mem_rw.v`), integrada no top-level
- [x] LCD com mensagens fixas (`display_ctx` no endereço 4091)
- [x] Sem BIOS: o reset busca `so.txt` na IMEM (kernel nas palavras 0–1334, NOP em 1335–3070 e `J 3071` na palavra 3071; 3072–4095 em zero)
- [x] Remontar `hd_image.txt` (catálogo no setor 0, kernel em NOP nos setores 1–12, programas nos setores 20–29, janelas dos PIDs zeradas)

### Fase 1 — Execução individual
O usuário seleciona um programa pelo LCD, executa só esse programa e, ao terminar, volta ao menu para escolher outro. Os IDs são os já gravados na imagem.

- [x] Menu no LCD: boas-vindas, três opções, lista dos dez programas, quantidade e a tela de arquivos. A opção 1 carrega o setor escolhido e mostra RUN
- [x] Carregar o programa escolhido do HD para a folha da vez e desviar o PC
- [x] Executar 1 programa (sem preempção) e voltar ao menu após o término

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

`processador/so.txt` é a imagem de reset, com 4096 palavras. O Quartus a lê,
junto com `hd_image.txt`, do diretório do processador (`MISC_FILE` no
`.qsf`). O kernel compilado ocupa as palavras 0–1334. As palavras 1335–3070
são NOP, a palavra 3071 é `J 3071` e 3072–4095 continuam zero. O supervisor
ainda não existe. Os padrões de síntese são `CPU_DIV` 5000, `BTN_STABLE`
1000000 e os tempos reais do LCD. O `tb_menu` encurta isso só na simulação.

O alvo `os-kernel` ainda não existe na linha de comando. O kernel de
`so.txt` saiu do alvo padrão. Os setores 1–12 de `hd_image.txt` seguem em
NOP; os programas canônicos estão nos setores 20–29.

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

No `so.cms`, o arranque mostra boas-vindas e espera KEY[1]. A primeira opção lista um programa e, no Enter, chama `find_program`. Se a busca falha, ou se `loadHD(36, 1536)` ou `loadROM(cat_sector[idx], 3072)` não devolvem 0, a tela é ERR. No sucesso, mostra RUN com o identificador e PID 0 e chama `runat(3072)`. Não há espera de KEY[1] antes do programa. O `HLT` armado devolve o menu. A segunda pergunta quantos programas e, depois de escolhê-los, mostra ERR, porque a preempção ainda não existe. A terceira avisa que arquivos ficam para a fase 3. O menu não chama `input()` nem `output()`: as duas instruções também esperam KEY[1], e o aperto que solta um `IN` não confirma o menu.

O sete segmentos continua sendo a saída de `OUT`. O `tb_menu` executa a área, com dois `IN` e o `OUT` de base×altura/2, volta ao menu com `$gp` 0 e carrega um segundo setor na folha. Os códigos 10, 11, 41, 42, 51, 111, 800 e 900 eram o menu antigo, feito com switches. O menu do LCD não os mostra.

O compilador expõe `lcdshow(modo, id, pid)`, `lcdack()` e `lcdsel()`. `loadHD`, `storeHD` e `loadROM` usam 4092 a 4095 e devolvem 0 quando `hd_status` é done e 1 quando é erro. 1020 a 1023 não é o disco. `void runat(int)` não é `jal`: grava `$v0`, `$t0`–`$t9`, `$gp`, `$sp`, `$fp` e `$ra` em 1043–1057, escreve o endereço em 4088 e restaura esses registradores a partir de `lw $v0,1043`. `$hi` e `$lo` ficam de fora. O alvo `os-user` recusa HD, LCD e `runat`. A troca de contexto de 18 palavras, o supervisor, o timer, o round-robin, o CRUD, a leitura do setor 0 e `IN`/`OUT` como trap continuam pendentes.
