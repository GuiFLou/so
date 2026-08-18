# Programas do SO

10 algoritmos em C- que serão armazenados no HD simulado e
executados pelo SO.

## Programas já existentes (no compilador)

Estes já estão validados no compilador e podem ser copiados:

| # | Programa | Fonte | Instruções | Descrição |
|---|----------|-------|------------|-----------|
| 1 | Fatorial iterativo | `fatorial.cms` | ~30 | Calcula 5! = 120 |
| 2 | GCD (Euclides) | `gcd.cms` | ~70 | MDC de dois números |
| 3 | Selection Sort | `sort.cms` | ~158 | Ordena vetor de 10 elementos |
| 4 | Fatorial recursivo | `fact_rec.cms` | ~58 | 5! com recursão |
| 5 | Soma simples | `teste.cms` | ~18 | Soma dois inputs |

## Programas a implementar

| # | Programa | Descrição |
|---|----------|-----------|
| 6 | Fibonacci | N-ésimo termo de Fibonacci |
| 7 | Busca linear | Busca valor em vetor |
| 8 | Máximo de vetor | Encontra maior elemento |
| 9 | Potência | Calcula base^exp iterativo |
| 10 | Contagem regressiva | Conta de N até 0 com output |

## Como adicionar um programa

1. Escrever o código em C- (arquivo `.cms`)
2. Compilar: `./cminus programa.cms`
3. O binário `.txt` gerado deve ser carregado no HD simulado
   (no arquivo `hd_init.txt` para simulação, ou via interface CRUD do SO)

## Restrições

- Cada programa pode ter no máximo **256 instruções** (tamanho do slot na ROM)
- Programas usam `input()` e `output()` para I/O
- Programas devem terminar com `HLT` (implícito no final de `main`)
- Na multitarefa, I/O é mediado pelo SO (syscall — Fase 2)
