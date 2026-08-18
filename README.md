# SO Simples — MIPS-Lite

Sistema operacional simples escrito em C-, compilado pelo compilador C- do projeto e executado no processador MIPS-Lite (FPGA DE2-115).

## Arquitetura

```
┌──────────────────────────────────────────────┐
│                  Shell/Menu                   │
│         (output = 7-seg / input = SW)        │
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
│   └── memory_map.md       # Mapa de memória (ROM/RAM/HD)
├── src/
│   └── so.cms              # Kernel completo em C-
├── hardware/
│   ├── inst_mem_rw.v       # Memória de instrução gravável
│   ├── hd_sim.v            # HD simulado (trilha/setor)
│   └── interrupt_timer.v   # Timer de quantum (Fase 2)
├── programs/               # Os 10 algoritmos em C-
│   ├── fatorial.cms
│   ├── gcd.cms
│   └── ...
└── tests/
    └── tb_so.v             # Testbench de integração
```

## Fases do projeto

### Fase 1 — MVP
- [x] Mapa de memória definido
- [ ] HD simulado em Verilog (`hd_sim.v`)
- [ ] Memória de instrução gravável (`inst_mem_rw.v`)
- [ ] BIOS (boot sequence no `main()`)
- [ ] Menu/Shell com códigos numéricos
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

```bash
# No diretório do compilador:
./cminus src/so.cms          # gera so.s e so.txt

# Copiar binário para o processador:
cp so.txt ../processador/
```

## Dependências

- **Compilador C-**: `../compilador/` (gera binários `.txt`)
- **Processador MIPS-Lite**: `../processador/` (executa no FPGA)
- **Intel Quartus**: Síntese dos módulos Verilog de hardware
- **Icarus Verilog**: Simulação dos testbenches

## Convenções do menu (7-seg)

| Código exibido | Significado                |
|----------------|----------------------------|
| `10`           | Menu pronto — aguarda opção |
| `11`           | Insira ID do programa       |
| `41`           | Insira ID atual (renomear)  |
| `42`           | Insira novo ID (renomear)   |
| `51`           | Insira ID para deletar      |
| `111`          | BIOS: diagnóstico OK        |
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
