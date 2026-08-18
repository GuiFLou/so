# Mapa de Memória

## ROM — Memória de Instrução (1024 palavras)

Com `inst_mem_rw.v`, a ROM passa a ser gravável pelo kernel (durante
carregamento de programas) e read-only durante execução normal.

```
Endereço    Tamanho     Uso
────────────────────────────────────────────────
0x000-0x1FF   512 palavras   Kernel (BIOS + SO)
0x200-0x2FF   256 palavras   Slot de programa A
0x300-0x3FF   256 palavras   Slot de programa B
                              (Fase 2: multitarefa)
────────────────────────────────────────────────
Total: 1024 palavras (0x000-0x3FF)
```

### Detalhamento do Kernel (0x000–0x1FF)

| Região | Endereço | Conteúdo |
|--------|----------|----------|
| Boot | 0x000–0x01F | Sequência BIOS (selftest, carga catálogo) |
| Serviços | 0x020–0x0FF | Funções do kernel (CRUD, menu, scheduler) |
| Handler | 0x100–0x11F | Handler de interrupção (Fase 2) |
| Reservado | 0x120–0x1FF | Espaço para crescimento |

### Slots de programa

Cada slot comporta um programa de até **256 instruções**.
- Fase 1: apenas slot A é usado (execução única)
- Fase 2: slots A e B para 2 processos concorrentes

Para programas maiores, os slots podem ser redistribuídos
(ex.: 1 slot de 512 palavras).

## RAM — Memória de Dados (1024 palavras)

```
Endereço    Tamanho     Uso
────────────────────────────────────────────────
0x000-0x03F    64 palavras   Dados do kernel (tabelas, catálogo)
0x040-0x07F    64 palavras   Pilha do kernel (cresce ↓)
0x080-0x27F   512 palavras   Área de dados processo A
                              (globais + pilha, $sp inicia em 0x27F)
0x280-0x3F7   376 palavras   Área de dados processo B (Fase 2)
0x3F8-0x3FB     4 palavras   Contexto salvo (PC, $sp do interrompido)
0x3FC-0x3FF     4 palavras   HD I/O mapeado
────────────────────────────────────────────────
Total: 1024 palavras (0x000-0x3FF)
```

### Detalhamento da RAM do Kernel (0x000–0x03F)

| Offset | Variável C- | Tamanho | Uso |
|--------|-------------|---------|-----|
| 0x000–0x003 | `proc_state[4]` | 4 | Estado dos processos |
| 0x004–0x007 | `proc_pc[4]` | 4 | PC salvo por processo |
| 0x008–0x00B | `proc_sp[4]` | 4 | SP salvo por processo |
| 0x00C–0x00F | `proc_rom_base[4]` | 4 | Base ROM por processo |
| 0x010–0x013 | `proc_data_base[4]` | 4 | Base RAM por processo |
| 0x014–0x01D | `cat_id[10]` | 10 | IDs do catálogo |
| 0x01E–0x027 | `cat_sector[10]` | 10 | Setores do catálogo |
| 0x028–0x031 | `cat_size[10]` | 10 | Tamanhos do catálogo |
| 0x032 | `cat_count` | 1 | Qtd programas |
| 0x033 | `current_pid` | 1 | PID em execução |
| 0x034–0x03F | reservado | 12 | Espaço para crescimento |

### HD I/O mapeado (0x3FC–0x3FF)

| Endereço | Nome | Direção | Significado |
|----------|------|---------|-------------|
| 0x3FC (1020) | `HD_CMD` | Escrita | Comando: 1=ler setor, 2=escrever setor |
| 0x3FD (1021) | `HD_SECTOR` | Escrita | Número do setor (0–N) |
| 0x3FE (1022) | `HD_ADDR` | Escrita | Endereço base de destino/origem |
| 0x3FF (1023) | `HD_STATUS` | Leitura | 0=idle, 1=busy, 2=done, 3=erro |

## HD — Armazenamento Simulado

```
Setor     Tamanho          Conteúdo
────────────────────────────────────────────────
0          64 palavras      Catálogo de programas
                            (id, setor, tamanho × 10 entradas)
1-10       256 palavras     Programas (1 setor por programa)
           cada
11+        variável         Reservado (dados persistentes)
────────────────────────────────────────────────
```

### Layout do setor de catálogo (setor 0)

```
Palavra 0:    cat_count (número de programas)
Palavra 1-10: cat_id[0..9]
Palavra 11-20: cat_sector[0..9]
Palavra 21-30: cat_size[0..9]
Palavra 31-63: reservado
```

## Registradores especiais

| Registrador | Inicialização | Uso no SO |
|-------------|---------------|-----------|
| `$sp` (29) | 1023 → ajustado por processo | Topo da pilha do processo |
| `$gp` (28) | 0 | Base da memória de dados |
| `$ra` (31) | — | Retorno de funções (JAL/JR) |
| `$fp` (30) | — | Frame pointer (se suportado) |

No contexto do SO, cada processo tem seu próprio `$sp` salvo no PCB.
O kernel usa a região 0x040–0x07F como sua pilha dedicada.
