# Tutorial: Executando Jobs no HPC da UFC com o Container `ubuntu_engine_hpc.sif`

Este tutorial explica, passo a passo, como professores do curso de Engenharia de Produção podem usar o container Apptainer `ubuntu_engine_hpc.sif` para rodar seus próprios códigos (Python, Julia, R, C++) no cluster HPC da UFC, usando o Slurm (`sbatch`/`squeue`). O uso do contêiner é somente para fins acadêmicos e não comerciais.

---

## 1. O que é o `ubuntu_engine_hpc.sif`

É uma imagem de container Apptainer (equivalente a uma "caixa" com um sistema operacional Ubuntu completo dentro dela) que já vem com um ambiente de pesquisa pronto, incluindo:

- **Python** (com numpy, pandas, scipy, python-mip, docplex, VRPSolverEasy, PyVRP, PyJobShop, entre outros)
- **Julia** (com JuMP, CPLEX.jl, DataFrames, Distributions, StatsBase, BrkgaMpIpr, RuleMiner)
- **R** (com o pacote `irace`)
- **IBM ILOG CPLEX** (solver de otimização, utilizável a partir de Python, Julia ou diretamente)
- **Compiladores C/C++** (g++)

Como tudo já está instalado dentro da imagem, qualquer pessoa do grupo de pesquisa pode rodar seus experimentos sem precisar instalar nada manualmente no cluster — basta usar o arquivo `.sif`.

---

## 2. Como submeter um job com `sbatch`

O cluster usa o gerenciador de filas **Slurm**. Em vez de rodar o código diretamente no terminal, você escreve um script `.sh` (como o `job_HPC_UFC_TEST.sh` usado de exemplo neste tutorial) e o envia para a fila de execução com:

```bash
sbatch job_HPC_UFC_TEST.sh
```

O Slurm vai alocar um nó de computação do cluster, rodar o script quando houver recursos disponíveis, e gravar toda a saída em um arquivo `.out` (o nome é definido dentro do próprio script, veja a seção 5).

---

## 3. Acompanhando a fila com `squeue -u nome.do.usuario`

Depois de enviar o job, use o comando abaixo para ver o status na fila (troque pelo seu usuário do cluster):

```bash
squeue -u nome.do.usuario
```

Esse comando mostra uma tabela com, entre outras, as seguintes colunas:

| Coluna | Significado |
| --- | --- |
| `JOBID` | Número identificador do job |
| `PARTITION` | Fila/partição usada (ex: `cpuq`) |
| `NAME` | Nome do job (definido com `-J` no script) |
| `USER` | Usuário que submeteu o job |
| `ST` | Estado do job |
| `TIME` | Tempo decorrido de execução |
| `NODES` | Número de nós alocados |
| `NODELIST(REASON)` | Nó(s) onde está rodando, ou motivo de estar esperando |

Os estados mais comuns na coluna `ST` são:

- **`PD`** (*Pending*) — o job está na fila, aguardando recursos ou processamento do escalonador
- **`R`** (*Running*) — o job está rodando de fato
- **`CG`** (*Completing*) — o job terminou e o Slurm está liberando os recursos

Quando o job termina (com sucesso ou erro), ele **some** da lista do `squeue` — a única forma de conferir o resultado é abrindo o arquivo `.out` gerado.

Para ver todos os seus jobs, pendentes e em execução, de forma contínua (atualizando a cada 5 segundos):

```bash
watch -n 5 squeue -u nome.do.usuario
```

---

## 4. Entendendo cada comando do script `.sh`

Abaixo, a explicação linha a linha do script de exemplo anexado (`job_HPC_UFC_TEST.sh`).

### 4.1. Diretivas `#SBATCH` (configuração do job)

```bash
#SBATCH --ntasks=1              # numero de tasks / processos MPI
#SBATCH --cpus-per-task=1       # numero de threads OpenMP por processo
#SBATCH -J HPC_TESTE_ENVS       # nome do job, aparece no squeue
#SBATCH --time=00:30:00         # tempo maximo de execucao (hh:mm:ss)
#SBATCH --mem=128000            # memoria total do job, em MB
#SBATCH --nodes=1               # numero de nos alocados
#SBATCH -o %x-%j.out            # arquivo de saida: nome_do_job-JOBID.out
#SBATCH -p cpuq                 # particao (fila) utilizada

#SBATCH --mail-type=END,FAIL    # eventos que disparam e-mail (fim ou falha do job)
#SBATCH --mail-user=seu.email@ufc.br # endereco para envio das notificacoes
```

- **`--ntasks`**: quantas tarefas (processos) o job vai rodar. Para a maioria dos scripts sequenciais (um único programa Python/Julia/R rodando de cada vez), use `1`.
- **`--cpus-per-task`**: quantos núcleos de CPU cada tarefa pode usar. É o parâmetro que controla o paralelismo dentro de um único processo (ver seção 6).
- **`-J`**: nome do job. É o que aparece na coluna `NAME` do `squeue` e também compõe o nome do arquivo de saída.
- **`--time`**: tempo máximo que o job pode rodar, no formato `horas:minutos:segundos`. Se o código ainda estiver rodando quando esse tempo acabar, o Slurm encerra o job à força.
- **`--mem`**: memória RAM total reservada para o job, em megabytes (128000 = 128 GB). Se o código tentar usar mais memória que isso, o job pode ser encerrado pelo sistema.
- **`--nodes`**: quantos nós físicos do cluster serão usados. Para a grande maioria dos casos de uso (um script rodando em uma máquina só), mantenha `1`.
- **`-o`**: nome do arquivo onde toda a saída do terminal (prints, mensagens de erro, etc.) será salva. O padrão `%x-%j.out` gera um nome como `HPC_TESTE_ENVS-123456.out` (nome do job + número do job).
- **`-p`**: partição (fila) do cluster onde o job vai rodar. `cpuq` é a fila padrão de CPU.
- **`--mail-type` / `--mail-user`**: configuram o envio de e-mail automático quando o job terminar (`END`) ou falhar (`FAIL`). Troque o e-mail pelo seu endereço institucional.

### 4.2. Variáveis de ambiente OpenMP

```bash
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export OMP_PLACES=threads
export OMP_PROC_BIND=spread
```

Essas variáveis controlam quantas *threads* internas bibliotecas numéricas (como NumPy, SciPy, MKL) podem abrir. O valor deve sempre **coincidir com o `--cpus-per-task`** definido acima — se você aumentar o número de CPUs reservadas (seção 6), aumente também esses valores, para aproveitar o paralelismo sem sobrecarregar o nó.

### 4.3. Informações do job (opcional, mas útil para depuração)

```bash
echo "ID of job allocation: $SLURM_JOB_ID"
echo "Directory job where was submitted: $SLURM_SUBMIT_DIR"
echo "File containing allocated hostnames: $SLURM_JOB_NODELIST"
echo "Total number of cores for job: $SLURM_NTASKS"
```

Essas linhas imprimem, no arquivo `.out`, informações úteis para saber exatamente onde e como o job rodou (número do job, diretório de submissão, nome do nó alocado, número de núcleos).

### 4.4. Caminho da imagem do container

```bash
IMAGE="/home/$USER/ubuntu_engine_hpc.sif"
```

Define, em uma variável, o caminho absoluto até o arquivo `.sif`. Usar caminho absoluto (começando em `/home/...`) evita erros relacionados ao diretório de onde o job é executado.

### 4.5. Os testes (cada `apptainer exec` roda algo dentro do container)

Cada bloco do script segue o mesmo padrão:

```bash
apptainer exec $IMAGE <comando ou código>
```

O `apptainer exec` abre o container e executa, dentro dele, o comando indicado — como se você tivesse entrado em outra máquina (com Python, Julia, R e CPLEX já instalados) só para rodar aquele comando específico.

No script de exemplo, cada item testa uma ferramenta diferente: a versão do CPLEX, um problema de mochila resolvido com Python-MIP, o mesmo problema resolvido com Julia/JuMP/CPLEX, uma regressão linear em R, um problema de agendamento com o CP Optimizer, dois problemas de roteirização (VRPSolverEasy e PyVRP), um problema de agendamento (PyJobShop), o pacote `irace` e a compilação/execução de um programa simples em C++.

---

## 5. Executando um arquivo em vez de um comando em linha

**Importante:** o script de exemplo roda os códigos em linha, usando `python3 -c "..."` ou `julia -e '...'` — isso foi feito só para fins de teste rápido. **No seu dia a dia, você não precisa escrever o código dentro do `.sh`.** Basta apontar para o seu arquivo `.py`, `.jl` ou `.R` já pronto, como em qualquer uso normal desses interpretadores:

```bash
apptainer exec $IMAGE python3 /home/$USER/minha_pasta/meu_script.py
```

```bash
apptainer exec $IMAGE julia /home/$USER/minha_pasta/meu_script.jl
```

```bash
apptainer exec $IMAGE Rscript /home/$USER/minha_pasta/meu_script.R
```

Isso vale também para passar argumentos ao seu script, normalmente:

```bash
apptainer exec $IMAGE python3 meu_script.py --instancia dados.csv --saida resultado.txt
```

Ou seja: o container simplesmente fornece o ambiente (Python, Julia, R, CPLEX já instalados e configurados) — o que você executa dentro dele é exatamente o seu código de pesquisa, do jeito que você já está acostumado a rodar localmente.

---

## 6. Ajustando memória, threads, tempo de execução e paralelização

Esses quatro ajustes são os mais comuns ao adaptar o script para o seu próprio experimento. Todos ficam nas diretivas `#SBATCH` no topo do arquivo.

### 6.1. Memória RAM

```bash
#SBATCH --mem=128000
```

Aumente esse valor (em MB) se o seu código trabalha com instâncias grandes ou modelos de otimização pesados. Por exemplo, para reservar 256 GB:

```bash
#SBATCH --mem=256000
```

**Atenção:** reserve só o que seu código realmente precisa. Reservar memória demais faz o job esperar mais tempo na fila (menos nós ficam disponíveis com aquela quantidade livre) sem necessidade.

### 6.2. Tempo de execução

```bash
#SBATCH --time=00:30:00
```

Formato `horas:minutos:segundos`. Para um experimento que pode levar até 10 horas, por exemplo:

```bash
#SBATCH --time=10:00:00
```

Se o seu código ultrapassar esse tempo, o job é encerrado à força, mesmo que ainda não tenha terminado — então é melhor superestimar um pouco o tempo necessário.

### 6.3. Threads e paralelização

Aqui entram três ajustes que devem **andar juntos**:

```bash
#SBATCH --cpus-per-task=1
...
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
```

Se o seu código é capaz de paralelizar o trabalho internamente (por exemplo, um algoritmo de otimização que usa múltiplos núcleos, ou bibliotecas como NumPy/CPLEX que também se beneficiam de mais CPUs), aumente o `--cpus-per-task` e ajuste as variáveis OpenMP/MKL para o **mesmo valor**:

```bash
#SBATCH --cpus-per-task=8
...
export OMP_NUM_THREADS=8
export MKL_NUM_THREADS=8
```

Isso reserva 8 núcleos de CPU para o job, e autoriza as bibliotecas internas a usarem até 8 threads. **O número de threads nunca deve ultrapassar o número de CPUs reservadas** — do contrário, o desempenho pode até piorar (as threads competem entre si por recursos que não existem) e outros jobs no mesmo nó são prejudicados.

Se o seu código é sequencial (não paralelizado), mantenha tudo em `1` — aumentar `--cpus-per-task` nesse caso não vai acelerar nada, só vai reservar núcleos ociosos.

**Caso especial — vários experimentos independentes:** se você precisa rodar o mesmo código várias vezes com parâmetros diferentes (por exemplo, testar 50 sementes aleatórias distintas), o ideal **não** é aumentar `--cpus-per-task` — é usar um **job array**, que faz o Slurm distribuir as execuções entre os nós disponíveis automaticamente:

```bash
#SBATCH --array=1-50
#SBATCH -o %x-%A_%a.out
```

e, dentro do código, ler o número da execução pela variável `$SLURM_ARRAY_TASK_ID`.

---

## 7. Instalando novas bibliotecas no container

Se você precisa de uma biblioteca de Python ou de Julia que ainda não está na imagem `ubuntu_engine_hpc.sif`, **não dá para instalar "ao vivo"** durante um job — o arquivo `.sif` é somente leitura. É necessário gerar uma nova versão da imagem. O processo tem três etapas:

### 7.1. Converter o `.sif` em um sandbox editável

A partir do arquivo `.sif` já existente, crie uma pasta editável (sandbox):

```bash
apptainer build --sandbox ubuntu_docker/so/ ubuntu_engine_hpc.sif
```

Isso gera a pasta `ubuntu_docker/so/`, que é uma cópia completa e editável do conteúdo da imagem.

### 7.2. Entrar no sandbox com permissão de escrita

```bash
apptainer shell --writable --fakeroot ubuntu_docker/so/
```

- **`--writable`**: permite gravar alterações dentro do sandbox (sem essa flag, o container continua somente leitura).
- **`--fakeroot`**: simula privilégios de administrador (root) dentro do container, necessário para instalar pacotes de sistema e bibliotecas.

Você vai cair em um prompt do tipo `Apptainer>`, como se estivesse "dentro" do container.

### 7.3. Instalar as bibliotecas necessárias

Dentro do sandbox, use as ferramentas normais de cada linguagem:

**Python:**

```bash
pip install nome-da-biblioteca
```

**Julia:**

```bash
julia -e 'using Pkg; Pkg.add("NomeDoPacote")'
```

**R:**

```bash
Rscript -e 'install.packages("nome-do-pacote")'
```

Depois de instalar, é recomendável testar rapidamente que a biblioteca carrega sem erro, ainda dentro do sandbox, antes de seguir para o próximo passo.

### 7.4. Gerar o novo arquivo `.sif` atualizado

Saia do sandbox e reconstrua a imagem a partir dele:

```bash
exit
apptainer build /home/$USER/ubuntu_engine_hpc.sif ubuntu_docker/so/
```

Isso substitui o `.sif` antigo por uma nova versão, já incluindo as bibliotecas recém-instaladas. A partir daí, qualquer job que use `apptainer exec $IMAGE ...` vai ter acesso normal às bibliotecas novas, sem precisar de nenhuma configuração extra no script `.sh`.

**Dica:** antes de sobrescrever o `.sif` em uso pelo grupo de pesquisa, vale testar a nova imagem com um nome diferente (ex: `ubuntu_engine_hpc_novo.sif`) e confirmar que tudo que já funcionava antes continua funcionando, evitando quebrar jobs de outras pessoas que dependem da imagem original.

---

## 8. Resumo rápido

| O que você quer fazer | Onde ajustar |
| --- | --- |
| Rodar seu próprio script | Trocar `python3 -c "..."` por `python3 seu_arquivo.py` |
| Aumentar a memória disponível | `#SBATCH --mem=...` (em MB) |
| Aumentar o tempo máximo de execução | `#SBATCH --time=hh:mm:ss` |
| Usar mais núcleos / paralelizar | `#SBATCH --cpus-per-task=N` + `OMP_NUM_THREADS=N` + `MKL_NUM_THREADS=N` |
| Rodar várias instâncias/sementes de uma vez | `#SBATCH --array=1-N` |
| Acompanhar o andamento do job | `squeue -u nome.do.usuario` |
| Ver o resultado depois que o job termina | Abrir o arquivo `.out` gerado |
| Instalar uma nova biblioteca | Sandbox editável → instalar → gerar novo `.sif` (seção 7) |
