- SO deverá:
  - Ser feito em C-
  - Ser compilado pelo compilador 
  - Armazenado na memória do compilador
  - Conter um diagrama num relatório técnico
  - Reservar processadores para si mesmo
- Escolher 10 agoritmos para rodar. Ele compila no nosso compilador e executa no nosso processador
- Shell/Prompt é a interface final (menu no LCD do FPGA) e deve poder:
  - Executar 1 programa (sem preempção)
  - Executar um conjunto de programas (multitarefa - com preempção) <- !!!
  - Renomear um programa
  - Criar um programa
  - Deletar um programa
- Funções do SO - Fazer um de cada e aprofundar em um deles.
  - Gerenciar Processos
    - Escalonamento de CPU (Troca de contexto) / Round-robin
      - Contexto: valores de registradores.
      - Jogo das cadeiras com contexto e memória de programa do usuário 1, do SO e programa do usuário 2, etc.
  - Gerenciar memória
    - Paginação / Segmentação
  - Gerenciar dispositivos I/O
    - Modularização: syscall
      - O usuário e o programa só escrevem no 7-seg pelo SO.
  - Gerenciar arquivos 
    - CRUD - Update = mover e renomear
- Memória ROM não é fixa/.txt
  - Deve estar carregada no HD.
  - O HD deve ser simulado
    - Construir em Verilog
      - Forma de implementar tem trilha/setor. É diferente que a memória normal.
- Bios inicializa
  - Teste de partida (verifica diagnóstico de componentes do sistema - meio simples)
  - Identificar dispositivo de armazenamento principal
  - Carregar SO para a memória principal
  - Ativar o processador para execução do SO
- Implementar interrupção:
  - Vai ser necessário colocar um registrador contador (quantum) usado para chamar o SO (syscall??) após x instruções -> altera o PC para o endereço do SO.
  - Não deve funcionar para o SO

---

O que sai para ter um Mínimo Projeto Viável

- HD simulado (implementar verilog)
- Bios
- Modularização
- CRUD de programas

