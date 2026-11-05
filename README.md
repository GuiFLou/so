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
│ inst_mem_rw │ hd_sim │ lcd │ timer (fase 2)  │
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
    ├── so.cms              # Kernel em C-
    └── so.txt              # Kernel compilado (gerado, fora do git)
```

Os testes desta etapa ficam no repositório do processador: `tb_lcd`,
`tb_hd_map`, `tb_hd_stall`, `tb_menu` e `tb_retorno`. Todos passam no
Icarus. O `tb_menu` carrega `processador/so.txt`, a imagem de reset, então
`src/so.txt` e essa imagem precisam ser regenerados depois de qualquer
mudança em `so.cms`.

O hardware permanece no repositório [`../processador`](../processador). O
compilador e as fontes ficam em [`../compilador`](../compilador).
`compilador/exemplos/` é a ROM solta: `reset_tests.sh` sem flag a regenera.
Os binários que o SO executa estão no processador, em trios de setores a
partir de `1 + 3×posição` em `hd_image.txt`. Com `--target=os-user` o script
grava esses trios, zera as janelas `31 + 3×PID` e não mexe em `exemplos/`.
O repositório do SO contém o kernel e a documentação.

## Fases do projeto

A gestão de processos pesa mais na nota, então a execução e o escalonamento vêm antes do CRUD. Os dez programas já estão na imagem do HD; criar, renomear e apagar não desbloqueiam nem a execução individual nem a multitarefa.

### Base (concluída)
- [x] Mapa de memória definido (4096 palavras; kernel, folha da vez e supervisor co-residentes)
- [x] Atualizar a estrutura do processador para esse mapa: IMEM e RAM de 4096 palavras; kernel em 0–3071, folha da vez em 3072–3839, supervisor em 3840–4095; RAM com dados do kernel, janela do programa, mailbox e MMIO em 4088–4095
- [x] HD simulado em Verilog (`hd_sim.v`), integrado no top-level
- [x] Memória de instrução gravável (`inst_mem_rw.v`), integrada no top-level
- [x] LCD com mensagens fixas (`display_ctx` no endereço 4091)
- [x] Sem BIOS: o reset busca `so.txt` na IMEM (kernel nas palavras 0–902, NOP em 903–3070 e `J 3071` na palavra 3071; 3072–4095 em zero)
- [x] Remontar `hd_image.txt` (catálogo no setor 0, executáveis em trios a partir de `1 + 3×posição`, janelas a partir de `31 + 3×PID`)

### Ajustes ainda da fase 1
- [x] Gravar e restaurar `$hi` e `$lo` na volta da opção 1
- [x] Realocar os dez executáveis no HD, 3 setores cada, a partir de `1 + 3×posição`
- [x] Realocar as dez janelas no HD, 3 setores cada, a partir de `31 + 3×PID`
- [x] Crescer a janela de dados do programa para 1536–2303
- [x] Subir o limite do alvo `os-user` para 768 palavras
- [x] Ler o diretório do setor 0 no arranque
- [x] Atualizar testes e imagem para o mapa novo
- [x] Alinhar a documentação com a imagem nova

### Fase 1 — Execução individual
O usuário seleciona um programa pelo LCD, executa só esse programa e, ao terminar, volta ao menu para escolher outro. Os IDs são os já gravados na imagem.

- [x] Menu no LCD: boas-vindas, três opções, lista dos dez programas, quantidade e a tela de arquivos. A opção 1 carrega a janela e o trio do programa e mostra RUN
- [x] Carregar o programa escolhido do HD para a folha da vez e desviar o PC
- [x] Executar 1 programa (sem preempção) e voltar ao menu após o término (validado em simulação pelo `tb_menu`)
- [ ] Sintetizar o mapa de 4096 no Quartus e executar os dez programas na placa

### Fase 2 — Multitarefa com preempção
O usuário escolhe N programas e o SO os executa com interrupção por quantum.

- [ ] Salvar `$t` vivos em volta de `jal` e reservar pilha no `os-user`
- [ ] Timer de quantum
- [ ] Desligar o timer quando só há um processo executável
- [ ] Modo privilegiado
- [ ] Causas simultâneas na ordem KEY[0], HLT, IN/OUT e timer; ctrl em 4090 recebe modo, timer e DISPATCH
- [ ] Tabela de 10 processos com contexto de 18 palavras
- [ ] Copiar o contexto do mailbox para o PCB antes de reutilizar o mailbox
- [ ] Supervisor salva e restaura o contexto
- [ ] Round-robin ligado ao menu
- [ ] HLT libera o PID e despacha o próximo; a volta em 4088 fica na opção 1 ou na fila vazia; quem terminou não volta a pronto
- [ ] Executar N programas com preempção
- [ ] Cada PID grava e recarrega só a própria janela
- [ ] Gravar a janela no setor de quem sai antes de o mailbox apontar o setor de quem entra
- [ ] A troca inteira, janela, folha e janela seguinte, é uma operação só: timer e KEY[0] só no fim
- [ ] Cada PID restaura só o próprio contexto
- [ ] Modo usuário não escreve o MMIO
- [ ] `IN` e `OUT` de usuário entregam o valor no contexto daquele PID
- [ ] Duas instâncias do mesmo executável preservam dados e registradores distintos

### Fase 3 — CRUD de arquivos
- [ ] Criar, renomear, mover e excluir programas no catálogo do HD

## Como compilar

`processador/so.txt` é a imagem de reset, com 4096 palavras. O Quartus a lê,
junto com `hd_image.txt`, do diretório do processador (`MISC_FILE` no
`.qsf`). O kernel compilado ocupa as palavras 0–902. As palavras 903–3070
são NOP, a palavra 3071 é `J 3071` e 3072–4095 continuam zero. O supervisor
ainda não existe. Os padrões de síntese são `CPU_DIV` 5000, `BTN_STABLE`
1000000 e os tempos reais do LCD. O `tb_menu` encurta isso só na simulação.

O alvo `os-kernel` ainda não existe na linha de comando. O kernel de
`so.txt` saiu do alvo padrão, com o NOP de tamanho e o `HLT` que o encoder
põe em todo binário. Nenhum script monta `processador/so.txt`; a receita
que gera o arquivo atual está em `docs/CONTEXT.md`, na construção das
imagens iniciais. Os programas canônicos ocupam trios a partir do LBA `1 + 3×posição`. As janelas dos PIDs 0–9 começam em `31 + 3×PID` e estão zeradas.

## Dependências

- **Compilador C-**: `../compilador/` (gera binários `.txt`)
- **Processador MIPS-Lite e hardware**: `../processador/`
- **Intel Quartus**: Síntese dos módulos Verilog de hardware
- **Icarus Verilog**: Simulação dos testbenches

## LCD

O kernel grava uma palavra em `display_ctx`, no endereço 4091. O Verilog desenha o texto. O programa não envia caracteres.

A escrita leva o modo nos bits 7 a 0, o identificador nos bits 17 a 8 e o PID nos bits 21 a 18. A escrita zera o bit 27, que é a confirmação. Se o modo mudar, o índice e a confirmação voltam a zero. O mesmo modo conserva o índice e só zera a confirmação que uma leitura já viu em 1; um KEY[1] ainda não lido continua valendo para a tela redesenhada. A leitura devolve também o índice, nos bits 26 a 22. Os bits 31 a 28 ficam em zero.

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

Os nomes, na ordem do índice, são AREA, BUSCA, FAT, FIB, GCD, MEDIA, PRIMO, POT, DIG e SORT. Os dígitos vêm do identificador lido no setor 0: 1 a 10, primeiro LBA `1 + 3×posição`, na mesma ordem.

No `so.cms`, o arranque lê o setor 0 para o buffer 1280 e publica a lista. A primeira opção lista um programa e, no Enter, chama `find_program`. Se a busca falha, ou se a janela do PID 0 ou o trio do programa não devolvem 0, a tela é ERR. No sucesso, mostra RUN com o identificador e PID 0 e chama `runat(3072)`. Não há espera de KEY[1] antes do programa. O `HLT` armado devolve o menu. A segunda pergunta quantos programas e, depois de escolhê-los, mostra ERR, porque a preempção ainda não existe. A terceira avisa que arquivos ficam para a fase 3. O menu não chama `input()` nem `output()`: as duas instruções também esperam KEY[1], e o aperto que solta um `IN` não confirma o menu.

O sete segmentos continua sendo a saída de `OUT`. O `tb_menu` executa a área, com dois `IN` e o `OUT` de base×altura/2, volta ao menu com `$gp` 0 e carrega um segundo setor na folha. Os códigos 10, 11, 41, 42, 51, 111, 800 e 900 eram o menu antigo, feito com switches. O menu do LCD não os mostra.

O compilador expõe `lcdshow(modo, id, pid)`, `lcdack()` e `lcdsel()`. `loadHD`, `storeHD` e `loadROM` usam 4092 a 4095 e devolvem 0 quando `hd_status` é done e 1 quando é erro ou idle. 1020 a 1023 não é o disco. `mem_read(addr)` lê uma palavra com o endereço no registrador. `void runat(int)` não é `jal`: grava `$v0`, `$t0`–`$t9`, `$gp`, `$sp`, `$fp`, `$ra`, `$hi` e `$lo` em 1043–1059, escreve o endereço em 4088 e restaura esses registradores a partir de `lw $v0,1043`. O alvo `os-user` recusa HD, LCD, `runat` e `mem_read`. A troca de contexto pelo supervisor, o timer, o round-robin, o CRUD e `IN`/`OUT` como trap continuam pendentes.

## FAQ para apresentação

Este FAQ separa o que pode ser demonstrado hoje do que ainda é projeto:

- **IMPLEMENTADO**: há código integrado e teste correspondente;
- **PARCIAL**: há uma parte funcional ou um esqueleto, mas o gerenciador ainda não cumpre o contrato completo;
- **FASE 2/3**: é a solução projetada, ainda sem implementação. Numa apresentação, deve ser explicada no futuro, não como algo já executável.

### Visão geral e integração

#### 1. Qual é o objetivo do projeto e qual é o fluxo completo de execução? — IMPLEMENTADO

O objetivo é executar programas C- sobre um processador próprio, tendo um
kernel também escrito em C- entre os programas e o hardware. O caminho
completo é:

```text
programa.cms
  -> compilador C-
  -> quádruplas
  -> assembly MIPS-Lite
  -> binário de 32 bits
  -> setor do HD simulado
  -> IMEM 3072–3839
  -> execução pelo processador
  -> HLT
  -> retorno ao kernel e ao menu
```

O kernel inicia na IMEM, mostra o menu no LCD, copia do HD a janela de dados e
o código do programa escolhido e chama `runat(3072)`. O `HLT` final do programa
faz o processador voltar à instrução seguinte do kernel. Esse caminho está em
`src/so.cms`, função `menu`, e é exercitado por
`../processador/tb_menu.v`.

#### 2. O projeto possui BIOS? Como ocorre o boot? — IMPLEMENTADO, sem BIOS

Não há BIOS na arquitetura atual. `docs/notes.md` ainda menciona uma BIOS;
essa ideia foi descartada por priorização. A configuração da FPGA já
inicializa a IMEM com `processador/so.txt`; o PC volta a zero no reset e
começa diretamente no prólogo do kernel.

```text
reset -> PC = 0 -> kernel residente -> main -> load_catalog -> menu
```

KEY[0] reinicia PC, registradores e CSRs, mas não recarrega IMEM, RAM ou HD.
Portanto, o termo correto na banca é **imagem de reset com o SO residente**, e
não BIOS. O `so.cms` não contém funções de BIOS.

#### 3. Por que a arquitetura de memória é Harvard e como o SO divide a memória? — IMPLEMENTADO

Ela é Harvard porque código e dados ficam em memórias diferentes: a IMEM é
endereçada pelo PC e a RAM por `LW`/`SW`. Ambas possuem 4096 palavras de 32
bits e endereçamento por palavra, por isso o PC avança de 1, não de 4.

```text
IMEM 0–3071       kernel residente
IMEM 3072–3839    folha do programa atual
IMEM 3840–4095    supervisor futuro

RAM  0–1023       dados e pilha do kernel
RAM  1024–1279    mailbox/contextos
RAM  1280–1535    buffer de um setor
RAM  1536–2303    dados e pilha do programa atual
RAM  4088–4095    MMIO
```

Kernel e programa coexistem: uma troca de programa substitui somente a folha
e a janela de dados. Isso evita recarregar o SO a cada troca de contexto.

### Mudanças no compilador

#### 4. Que mudanças no compilador foram necessárias para executar programas sob o SO? — IMPLEMENTADO

Foi criado o alvo `--target=os-user`. Ele altera a base dos dados, a pilha e
os saltos absolutos, além de impor limites e impedir acesso de usuário aos
intrínsecos do kernel.

```c
/* compilador/asmgen.c */
if (targetOsUser) {
    fprintf(o, "    addi $gp,$zero,%d\n", USER_GP);
    fprintf(o, "    addi $sp,$zero,%d\n", USER_SP);
}
```

O alvo também limita o binário a 768 palavras, pois cada executável ocupa
três setores do HD. Em `analyze.c`, chamadas a HD, LCD, `runat` e `mem_read`
são recusadas para `os-user`. O alvo padrão continua sendo usado para o
kernel e para execução isolada durante o desenvolvimento.

#### 5. Por que `J` e `JAL` recebem 3072, mas `BEQ` e `BNE` não? — IMPLEMENTADO

`J` e `JAL` usam endereço absoluto. Como o programa é compilado como se
começasse na palavra zero, o encoder soma a base da folha:

```c
/* compilador/encoder.c */
if (targetOsUser)
    *address += 3072;
```

Branches são relativos a `PC + 1`. Se a origem e o destino forem deslocados
pela mesma base, a diferença entre eles não muda:

```text
offset = destino - PC_do_branch - 1
```

Somar 3072 ao branch seria um erro, pois transformaria uma distância pequena
em um salto muito maior.

#### 6. Para que servem o NOP inicial e o HLT final dos binários? — IMPLEMENTADO

O encoder insere na palavra zero um `NOP` cujo campo de 26 bits guarda o
tamanho total do binário. Esse metadado permite ao catálogo conhecer o
tamanho sem executar uma instrução especial. O encoder também garante um
`HLT` no fim.

```c
words[0] = makeF3(OP_NOP, (long)programSize);
```

Num programa isolado, `HLT` congela o PC. Quando o kernel usou `runat`, o
retorno está armado e o mesmo `HLT` devolve o controle ao kernel. Assim, a
instrução possui dois comportamentos conforme o estado de execução.

#### 7. Como o compilador oferece serviços de hardware sem adicionar opcodes à ISA? — IMPLEMENTADO

HD e LCD são acessados por **intrínsecos** que o compilador expande para
`LW`/`SW` em endereços MMIO. Exemplos:

```c
st = loadHD(36, 1536);                 /* HD -> RAM */
st = loadROM(cat_sector[idx], 3072);   /* HD -> IMEM */
lcdshow(3, id, 0);                     /* tela RUN */
runat(3072);                           /* entra na folha */
```

`loadHD`, por exemplo, grava setor em 4093, endereço em 4094 e comando em
4092, depois consulta o status em 4095. A vantagem é reutilizar a ISA
existente. A análise semântica restringe esses intrínsecos ao kernel.

#### 8. Qual convenção de chamadas precisa ser preservada numa troca de contexto? — PARCIAL

O compilador usa `$gp` para globais, `$sp` para a pilha, `$fp` para o frame,
`$ra` para retorno, `$v0` para resultado, `$t0`–`$t9` para temporários e
`$hi/$lo` para multiplicação e divisão. O frame implementado é:

```text
0($fp)   = $fp anterior
1($fp)   = $ra
2($fp)+  = parâmetros
-1($fp)- = variáveis locais
```

Logo, salvar apenas o PC não basta: o processo voltaria à instrução correta
com variáveis e retornos corrompidos. A Fase 2 prevê preservar PC mais 17
registradores. O `runat` da opção 1 já grava e restaura esses 17, inclusive
`$hi` e `$lo`. O mecanismo completo de supervisor continua pendente.

#### 9. Que limitações atuais do compilador bloqueiam ou arriscam a Fase 2? — PARCIAL

Há duas limitações principais:

1. temporários `tN` são mapeados circularmente em `$t0`–`$t9` e não são
   salvos em torno de `jal`; uma chamada pode sobrescrever um temporário vivo;
2. globais e pilha dividem as 768 palavras da janela de usuário, mas a
   verificação `dataUsed > 768` não inclui a profundidade da pilha.

Exemplo problemático:

```c
return n * fat(n - 1);
```

O valor de `n` pode ficar num `$t` sobrescrito pela chamada recursiva. Para a
Fase 2, o compilador deverá salvar temporários vivos ao redor de chamadas e
reservar/verificar espaço de pilha no alvo `os-user`.

### Mudanças no processador e no hardware do SO

#### 10. Quais foram as principais mudanças no processador para contemplar o SO? — IMPLEMENTADO

As mudanças centrais foram:

- IMEM e RAM ampliadas para 4096 palavras;
- substituição da ROM fixa por `inst_mem_rw`, gravável pelo HD;
- HD setorizado em `hd_sim.v`, com DMA;
- LCD controlado por `display_ctx`;
- MMIO em 4088–4095;
- mecanismo `pc_load` + `HLT` armado para executar uma folha e voltar;
- sinais de stall/freeze durante HD, `IN` e `OUT`.

O timer, o modo privilegiado, `ctrl` em 4090 e o supervisor ainda não fazem
parte do núcleo implementado.

#### 11. Como funciona o HD simulado e por que ele não é apenas outra RAM? — IMPLEMENTADO

O HD representa persistência setorizada: 8 trilhas, 8 setores por trilha e
256 palavras por setor. O software enxerga apenas o LBA de 0 a 63. A
geometria equivale a:

```text
trilha          = LBA / 8
setor_na_trilha = LBA % 8
endereço_linear = LBA * 256 + deslocamento
```

O Verilog não precisa guardar trilha e setor separadamente: ele calcula
diretamente `LBA * 256 + deslocamento`. O array `storage` é inicializado por
`hd_image.txt` e marcado para uso de blocos M9K. Diferentemente de uma RAM
comum, cada comando transfere um setor inteiro e possui estados `idle`,
`busy`, `done` e `error`.

#### 12. Como o DMA do HD se comunica com a CPU e por que ela é congelada? — IMPLEMENTADO

O HD usa a porta B da RAM ou da IMEM para mover 256 palavras sem executar 256
pares de `LW`/`SW`. Enquanto a transferência está ativa, `cpu_stall` segura o
PC e `cpu_freeze` impede que uma instrução congelada repita uma escrita.

```verilog
assign cpu_freeze = (state != STATE_IDLE);
assign cpu_stall  = (cpu_freeze && !retire) || accept;
```

No último ciclo a operação é aposentada e o PC avança exatamente uma vez.
Os testbenches `tb_hd_map` e `tb_hd_stall` verificam limites, cópia e esse
comportamento.

#### 13. Como `runat` executa um programa e retorna ao kernel sem preempção? — IMPLEMENTADO

`runat(3072)` salva registradores do kernel no mailbox e faz um `SW` em
`pc_load` (4088). O hardware aceita o destino apenas se estiver entre 3072 e
3839, guarda `PC + 1` em `kret` e arma o retorno.

Quando o programa chega ao `HLT`, o processador:

```text
PC <- kret
epc <- PC do HLT
cause <- 2
armed <- 0
```

O kernel então restaura seus registradores e continua após `runat`. Isso é
uma chamada controlada de uma folha, não uma troca de contexto preemptiva.
`tb_retorno` testa o mecanismo isoladamente e `tb_menu` testa o caminho
integrado.

#### 14. Como o menu usa o LCD sem enviar strings caractere por caractere? — IMPLEMENTADO

O kernel grava em `display_ctx` (4091) apenas modo, ID e PID:

```text
bits  7:0  = modo
bits 17:8  = ID
bits 21:18 = PID
```

O controlador Verilog possui as mensagens fixas (`MENU`, `RUN`, `PROG`,
etc.). Na leitura, o kernel recebe a seleção nos bits 26:22 e o ack de
KEY[1] no bit 27. `lcdshow`, `lcdsel` e `lcdack` encapsulam esse protocolo.
Isso contorna a ausência de strings no C- e reduz o trabalho do processador.

Para não perder nem reaproveitar um Enter, o hardware mantém `disp_ack` até
um `LW` observá-lo e marca essa leitura em `disp_seen`. Um `SW` no mesmo modo
só limpa um ack já observado e preserva a seleção; uma troca de modo limpa
ack e seleção. O Enter que libera um `IN`/`OUT` também não confirma o menu.
Esses casos de corrida são verificados em `tb_lcd` e `tb_menu`.

### Gerenciador de processos

#### 15. O que o gerenciador de processos faz atualmente? — PARCIAL

O que executa hoje é um PID 0 implícito na opção 1: a janela carregada é
sempre a do PID 0 e o `runat(3072)` não consulta uma tabela de processos.
`so.cms` não guarda PCB, contexto nem busca circular. Arrays paralelos
continuam sendo a forma prevista para a fase 2, porque C- não tem `struct`.

#### 16. Como será o escalonamento round-robin? — FASE 2

Round-robin dá a cada processo pronto um quantum fixo e percorre os PIDs
circularmente. O kernel ainda não tem essa busca. A fase 2 percorre dez
entradas e liga a escolha às interrupções.

```c
/* desenho da fase 2, ainda sem código no kernel */
candidate = (current_pid + i) módulo quantidade_de_pcbs;
if (proc_state[candidate] == PRONTO) return candidate;
```

Ao fim de 50 instruções de usuário, o timer deverá causar uma trap. O kernel
salvará o processo atual, escolherá o próximo estado `PRONTO` e pedirá ao
supervisor que o despache. Se houver somente um processo executável, o timer
pode ser desabilitado para evitar trocas inúteis.

#### 17. O que é um PCB e quais dados precisam ser salvos neste projeto? — FASE 2

PCB é o bloco de controle do processo. O desenho final prevê dez posições
com estado, ID do programa, setor do executável e um contexto de 18 palavras:

```text
PC, $v0, $t0–$t9, $gp, $sp, $fp, $ra, $hi, $lo
```

O PID é o próprio índice do PCB, portanto não precisa ser armazenado dentro
dele. `$zero` também não é salvo porque sempre lê zero. Bases de IMEM e RAM
não precisam ficar por processo: todos usam as mesmas janelas 3072 e 1536;
as cópias inativas ficam no HD.

#### 18. Qual é a diferença entre escalonamento, troca de contexto e preempção? — FASE 2

- **Escalonamento** é a política que escolhe o próximo PID; aqui,
  round-robin.
- **Troca de contexto** é o mecanismo que salva o estado do atual e restaura
  o do próximo.
- **Preempção** é retirar a CPU de um processo sem ele terminar,
  normalmente por interrupção de timer.

Na Fase 1 há retorno cooperativo no `HLT`, mas não preempção. Na Fase 2 o
timer contará apenas instruções concluídas em modo usuário. Ele não deve
interromper kernel, supervisor nem uma transferência atômica do HD.

#### 19. Por que haverá um supervisor em Assembly além do kernel em C-? — FASE 2

Uma interrupção pode ocorrer entre quaisquer instruções. Antes de executar
código C-, é preciso preservar registradores sem usar esses mesmos
registradores para montar um prólogo. O supervisor residente em 3840–4095
será um mecanismo mínimo em Assembly capaz de salvar/restaurar contexto,
trocar modo e entregar a causa ao kernel.

Ele não decide políticas. Escolher PID, atualizar PCB, atender E/S e
gerenciar arquivos continuam sendo funções do kernel. Essa separação evita
transformar o supervisor em um segundo SO.

### Gerenciador de memória

#### 20. O projeto usa paginação ou segmentação? Como a memória é gerenciada? — PARCIAL

Ainda não há paginação, MMU ou segmentação dinâmica. A solução é
**particionamento fixo com swapping explícito**:

- uma folha fixa de código em 3072–3839;
- uma janela fixa de dados em 1536–2303;
- três setores de dados no HD para cada PID, a partir de `31 + 3×PID`;
- kernel e mailbox em regiões residentes.

Na troca futura, as 768 palavras do PID atual serão gravadas nesse trio, e
as do próximo serão carregadas na mesma janela. É uma forma simples de
virtualização por sobreposição: todos os programas enxergam os mesmos
endereços, mas recebem conteúdos diferentes.

#### 21. Como duas instâncias do mesmo programa poderão ter dados independentes? — FASE 2

Elas podem compartilhar o mesmo setor de código, porque código é somente
leitura, mas cada instância recebe PID, contexto e setor de dados próprios.
Por exemplo:

```text
PID 2: código a partir do LBA 7, dados a partir do LBA 37
PID 7: código a partir do LBA 7, dados a partir do LBA 52
```

Ambas executam o fatorial carregado em 3072, porém a troca carrega em
1536–2303 a janela correspondente ao PID. Assim, pilha, globais e
registradores não se misturam.

#### 22. Quais são as limitações de proteção de memória atuais? — PARCIAL

Hoje a separação é principalmente uma convenção do compilador. Não existe
modo usuário, MMU nem bloqueio completo para um binário malformado acessar
MMIO ou endereços do kernel. O alvo `os-user` impede isso no nível semântico,
recusando os intrínsecos privilegiados, mas não protege contra código de
máquina escrito manualmente.

A Fase 2 adicionará modo usuário/privilegiado e supervisor protegido. Mesmo
assim, proteção completa contra todo binário malformado não é objetivo da
primeira versão.

### Gerenciador de E/S e drivers

#### 23. `input()` e `output()` já são syscalls? — NÃO; FASE 2

Atualmente o compilador gera diretamente os opcodes `IN` e `OUT`, e o
processador acessa switches e sete segmentos em qualquer contexto. A CPU
espera KEY[1], portanto as operações são bloqueantes, mas ainda não entram no
kernel.

O contrato futuro reutiliza os mesmos opcodes:

```text
modo usuário       -> IN/OUT gera trap e registra causa/operandos
modo privilegiado  -> IN/OUT acessa diretamente o periférico
```

O kernel atenderá a operação e despachará novamente o mesmo PID, preservando
o saldo do quantum. Portanto, dizer que E/S já está modularizada por syscall
seria incorreto; hoje há apenas os opcodes e a interface bloqueante.

Como não há estado de processo `BLOQUEADO` nem outro processo despachável, a
espera por KEY[1] paralisa a máquina inteira. No desenho futuro, `IN` e `OUT`
continuarão bloqueantes para simplificar o projeto: o supervisor congela
timer e execução, o kernel atende a operação e depois retoma o mesmo PID.

#### 24. Qual é a diferença entre interrupção, trap e syscall neste projeto? — FASE 2

Interrupção é um evento externo/assíncrono, como o fim do quantum. Trap é a
transferência controlada para código privilegiado causada por um evento da
execução, como `HLT`, `IN` ou `OUT`. Syscall é uma solicitação intencional de
serviço do SO; aqui, `IN` e `OUT` de usuário funcionarão como syscalls por
meio de traps.

As causas planejadas devem ser registradas para que o kernel saiba se deve
terminar um processo, atender E/S ou apenas reenfileirá-lo após o quantum.
Hoje apenas a causa 2 do `HLT` armado é produzida.

### Gerenciador de arquivos

#### 25. Qual é a estrutura do sistema de arquivos projetado? — PARCIAL

É um catálogo simples e plano no setor 0 do HD:

```text
palavras 0–3    assinatura, versão e capacidades
palavras 4–19   8 diretórios, 2 palavras cada
palavras 20–83  16 arquivos, 4 palavras cada
```

Cada arquivo guarda ativo, diretório, ID e tamanho. Sua posição determina o
primeiro setor do executável: `1 + 3×posição`. Não há subdiretórios. Cada
executável ocupa três setores, no máximo 768 palavras. O kernel só publica
as posições 0–9; uma entrada ativa em 10–15 faz o arranque recusar o
diretório, porque esse trio colidiria com a janela do PID 0.

O setor 0 existe em `hd_image.txt` e o arranque o lê para o buffer 1280.
`load_catalog` confere a assinatura `20261013` e a versão 1 e copia o ID e
o LBA calculado. O tamanho permanece no setor 0. Gravar o diretório de volta
continua sendo Fase 3.

#### 26. Como funcionarão criar, renomear, mover e excluir? — FASE 3

- **Criar/importar**: reservar uma entrada e um setor livre; a forma de
  importar um novo executável pronto ainda está em aberto.
- **Renomear**: alterar apenas o ID/nome nos metadados.
- **Mover**: trocar o slot de diretório da entrada.
- **Excluir**: zerar o campo ativo, sem compactar as entradas.

O kernel não tem rotina de exclusão. Compactar as entradas mudaria o setor
associado a cada posição, então a fase 3 só zera o campo ativo.

Para persistência segura, o kernel montará um catálogo candidato no buffer
1280–1535, gravará o setor inteiro com `storeHD(0, 1280)` e somente então
publicará a mudança em RAM. Isso evita deixar metade dos metadados antigos e
metade novos.

### Decisões de arquitetura

#### 27. Como existe modularização se o kernel está em um único arquivo? — PARCIAL

O C- não possui `#include`, linker, strings, `struct` ou compilação
multi-arquivo. Por isso o kernel é monolítico fisicamente, mas separado
logicamente em shell, processos, memória, E/S, arquivos e abstrações de
hardware.

No projeto completo também há separação por responsabilidade:

```text
compilador/  -> linguagem, ABI e geração dos binários
processador/ -> CPU, memórias e periféricos Verilog
so/          -> kernel e documentação
```

Não se deve duplicar Verilog dentro de `so/`; o kernel usa contratos MMIO
oferecidos pelo processador.

#### 28. Como será feita uma troca de contexto completa? — FASE 2

A troca começa quando um processo de usuário termina, esgota o quantum ou
executa `IN`/`OUT`. O fluxo projetado é:

```text
1. hardware detecta a causa e entra em modo privilegiado
2. supervisor salva PC e os 17 registradores no mailbox
3. supervisor restaura o contexto do kernel
4. kernel copia o contexto salvo para o PCB do PID atual
5. kernel atualiza o estado e escolhe o próximo PID por round-robin
6. kernel coloca no mailbox contexto, setores e quantum do próximo PID
7. kernel envia DISPATCH pelo registrador ctrl
8. supervisor grava a janela de dados atual no HD
9. supervisor carrega código e dados do próximo PID
10. supervisor restaura registradores, muda para usuário e libera o PC
```

O contexto temporário fica no mailbox; a cópia permanente fica no PCB. A
janela de dados do PID começa no setor `31 + 3×PID`, enquanto o código vem
do trio associado ao programa. O kernel decide **quem** executar; o supervisor
executa **como** salvar, carregar e retomar sem destruir registradores.

#### 29. Por que o timer deve contar apenas instruções de usuário? — FASE 2

O quantum mede quanto tempo de CPU cada processo recebeu. Contar instruções
do kernel ou do supervisor cobraria do processo o custo interno do SO e
poderia interromper a própria rotina que está tentando salvar um contexto.

Por isso, o timer será habilitado somente em modo usuário. Ele fica congelado
durante:

- execução do kernel e do supervisor;
- transferência atômica de setor pelo HD;
- atendimento bloqueante de `IN` ou `OUT`;
- troca de contexto.

Ao retornar de uma syscall, o mesmo PID continua com o saldo anterior. Ao
retornar de uma interrupção de quantum, recebe um novo quantum quando voltar
a ser escalonado. Isso separa a política de justiça do round-robin do custo
de manutenção do sistema.

#### 30. Por que o kernel permanece residente e só existe uma folha de programa? — DECISÃO DE PROJETO

Manter o kernel em 0–3071 permite atender uma trap sem buscá-lo novamente no
HD. A folha 3072–3839 e a janela de dados 1536–2303 funcionam como áreas de
trabalho reutilizáveis: a cada despacho, recebem o código e os dados do PID
escolhido.

Essa decisão reduz a complexidade do hardware:

- não exige várias IMEMs nem relocação dinâmica do kernel;
- todos os programas usam as mesmas bases `$gp = 1536` e código em 3072;
- somente uma região precisa ser conectada ao DMA;
- processos inativos ocupam setores do HD, não grandes regiões simultâneas
  da FPGA.

O custo é que cada troca precisa mover setores inteiros. Para este projeto,
memória simples e endereços previsíveis foram priorizados em relação ao
desempenho de uma cache, paginação ou memória virtual completa.
