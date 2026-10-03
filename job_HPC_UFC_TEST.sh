#!/bin/bash
#SBATCH --ntasks=1              # numero de tasks / processos MPI
#SBATCH --cpus-per-task=1       # numero de threads OpenMP por processo
#SBATCH -J HPC_TESTE_ENVS       # nome do job, aparece no squeue
#SBATCH --time=00:30:00         # tempo maximo de execucao (hh:mm:ss)
#SBATCH --mem=128000              # memoria total do job, em MB
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

echo -e "\n1. Testando CPLEX: versao do solver"
echo quit | apptainer exec $IMAGE cplex | head -3

echo -e "\n2. Testando Python: mochila com python-mip (HiGHS)"
apptainer exec $IMAGE python3 -c "
import mip
p=[1,2,5,6,7]; v=[1,6,18,22,28]; cap=11
m=mip.Model(sense=mip.MAXIMIZE, solver_name=mip.HIGHS)
x=[m.add_var(var_type=mip.BINARY) for i in p]
m.objective=mip.xsum(v[i]*x[i] for i in range(len(p)))
m += mip.xsum(p[i]*x[i] for i in range(len(p))) <= cap
m.optimize()
print(f'Python-MIP OK: status={m.status}, valor_maximo={m.objective_value}')"

echo -e "\n3. Testando Julia: mochila com JuMP + CPLEX"
apptainer exec $IMAGE julia -e '
using JuMP, CPLEX
p=[1,2,5,6,7]; v=[1,6,18,22,28]; cap=11; n=length(p)
model=Model(CPLEX.Optimizer)
@variable(model, x[1:n], Bin)
@objective(model, Max, sum(v[i]*x[i] for i in 1:n))
@constraint(model, sum(p[i]*x[i] for i in 1:n) <= cap)
optimize!(model)
println("JuMP+CPLEX OK: status=", termination_status(model), ", valor_maximo=", objective_value(model))'

echo -e "\n4. Testando R: modelo linear simples com base R"
apptainer exec $IMAGE Rscript -e '
x <- c(1,2,3,4,5); y <- c(2,4,5,4,5)
modelo <- lm(y ~ x)
cat("R OK: intercepto =", coef(modelo)[1], "| inclinacao =", coef(modelo)[2], "\n")'

echo -e "\n5. Testando IBM CP Optimizer (Docplex CP): agendamento simples"
apptainer exec $IMAGE python3 -c "
from docplex.cp.model import CpoModel
m = CpoModel()
x = m.integer_var(0, 10, 'x')
m.add(x >= 3)
m.minimize(x)
s = m.solve(log_output=True)
print(f'Docplex CP Optimizer OK: x = {s.get_value(x)}')"

echo -e "\n6. Testando VRPSolverEasy (BaPCod + CPLEX): mini CVRP"
apptainer exec $IMAGE python3 -c "
import VRPSolverEasy as vrpse, math
m = vrpse.Model()
m.add_vehicle_type(id=1, start_point_id=0, end_point_id=0, max_number=2, capacity=10, var_cost_dist=1)
m.add_depot(id=0)
m.add_customer(id=1, demand=4)
m.add_customer(id=2, demand=5)
pts = {0: (0, 0), 1: (1, 1), 2: (2, 2)}
for i in pts:
    for j in pts:
        if i != j:
            dist = round(math.hypot(pts[i][0]-pts[j][0], pts[i][1]-pts[j][1]) * 1000)
            m.add_link(start_point_id=i, end_point_id=j, distance=dist)
m.set_parameters(time_limit=30, solver_name='CPLEX')
m.solve()
print(f'VRPSolverEasy OK: status={m.status}, valor={m.solution.value}')"

echo -e "\n7. Testando PyVRP: mini CVRP"
apptainer exec $IMAGE python3 -c "
import pyvrp
from pyvrp.stop import MaxRuntime
m = pyvrp.Model()
depot = m.add_depot(location=m.add_location(x=0, y=0), name='Depot')
m.add_vehicle_type(num_available=2, capacity=10)
coords=[(1,1),(2,2)]; demands=[4,5]
for (x,y), d in zip(coords, demands):
    m.add_client(location=m.add_location(x=x, y=y), delivery=d)
for frm in m.locations:
    for to in m.locations:
        if frm != to:
            dist = round(((frm.x-to.x)**2 + (frm.y-to.y)**2)**0.5 * 1000)
            m.add_edge(frm, to, distance=dist)
res = m.solve(stop=MaxRuntime(5))
print(f'PyVRP OK: custo={res.cost()}')"

echo -e "\n8. Testando PyJobShop (CP Optimizer): mini job shop"
apptainer exec $IMAGE python3 -c "
import pyjobshop
m = pyjobshop.Model()
m1 = m.add_machine(name='M1')
m2 = m.add_machine(name='M2')
j1 = m.add_job(name='Job1')
j2 = m.add_job(name='Job2')
t1 = m.add_task(job=j1, name='J1-T1')
t2 = m.add_task(job=j1, name='J1-T2')
t3 = m.add_task(job=j2, name='J2-T1')
t4 = m.add_task(job=j2, name='J2-T2')
m.add_mode(t1, m1, duration=2)
m.add_mode(t2, m2, duration=3)
m.add_mode(t3, m2, duration=2)
m.add_mode(t4, m1, duration=3)
m.add_end_before_start(t1, t2)
m.add_end_before_start(t3, t4)
res = m.solve(solver='cpoptimizer', display=False)
print(f'PyJobShop OK: status={res.status}, makespan={res.objective}')
data = m.data()
print('Solucao (tarefa: inicio -> fim, recurso):')
for idx, sched in enumerate(res.best.tasks):
    nome_tarefa = data.tasks[idx].name
    nomes_recursos = [data.resources[r].name for r in sched.resources]
    print(f'  {nome_tarefa}: {sched.start} -> {sched.end}, recurso(s)={nomes_recursos}')"

echo -e "\n9. Testando R: pacote irace"
apptainer exec $IMAGE Rscript -e 'library(irace); cat("irace OK! Versao:", as.character(packageVersion("irace")), "\n")'

echo -e "\n10. Testando C++: compilacao e execucao com g++"
apptainer exec $IMAGE bash -c 'echo "#include <iostream>
int main(){int s=0; for(int i=1;i<=10;i++) s+=i; std::cout << \"C++ OK: soma 1..10 = \" << s << std::endl; return 0;}" | g++ -x c++ - -o /tmp/cpp_test && /tmp/cpp_test'

echo -e "\nTestes finalizados com sucesso às:"
date