using JuMP, HiGHS

p=[1, 2, 5, 6, 7]
v=[1, 6, 18, 22, 28]
cap=11

n=length(p)

model=Model(HiGHS.Optimizer)

@variable(model, x[1:n], Bin)

@objective(model, Max, sum(v[i]*x[i] for i in 1:n))

@constraint(model, sum(p[i]*x[i] for i in 1:n) <= cap)

optimize!(model)

println("JuMP+CPLEX OK: status=", termination_status(model), ", valor_maximo=", objective_value(model))