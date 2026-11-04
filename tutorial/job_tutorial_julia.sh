#!/bin/bash
#SBATCH --ntasks=1              # numero de tasks / processos MPI
#SBATCH --cpus-per-task=1       # numero de threads OpenMP por processo
#SBATCH -J HPC_TESTE_JL         # nome do job, aparece no squeue
#SBATCH --time=00:30:00         # tempo maximo de execucao (hh:mm:ss)
#SBATCH --mem=128000            # memoria total do job, em MB
#SBATCH --nodes=1               # numero de nos alocados
#SBATCH -o %x-%j.out            # arquivo de saida: nome_do_job-JOBID.out
#SBATCH -p cpuq                 # particao (fila) utilizada

#SBATCH --mail-type=END,FAIL    # eventos que disparam e-mail (fim ou falha do job)
#SBATCH --mail-user=levi.abreu@ufc.br # endereco para envio das notificacoes

# OpenMP settings:
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export OMP_PLACES=threads
export OMP_PROC_BIND=spread

echo "ID of job allocation: $SLURM_JOB_ID"
echo "Directory job where was submitted: $SLURM_SUBMIT_DIR"
echo "File containing allocated hostnames: $SLURM_JOB_NODELIST"
echo "Total number of cores for job: $SLURM_NTASKS"

# Caminho absoluto para o arquivo SIF no diretório inicial do usuário
IMAGE="/home/$USER/ubuntu_engine_hpc.sif"

echo -e "\n========================================"
echo "Iniciando testes no Apptainer: $IMAGE"
echo "========================================"

echo -e "\n1. Testando Julia: mochila com JuMP (CPLEX)"

apptainer exec $IMAGE julia julia_jump_test.jl

echo -e "\nTestes finalizados com sucesso às:"
date