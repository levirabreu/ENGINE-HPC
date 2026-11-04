from mip import Model, xsum, HIGHS, MAXIMIZE, BINARY

p = [1, 2, 5, 6, 7]
v = [1, 6, 18, 22, 28]
cap = 11

m = Model(sense=MAXIMIZE, solver_name=HIGHS)

x = [m.add_var(var_type=BINARY) for i in p]

m.objective = xsum( v[i]*x[i] for i in range( len(p) ) )

m += xsum( p[i]*x[i] for i in range( len(p) ) ) <= cap

m.optimize()

print(f'Python-MIP OK: status={m.status}, valor_maximo={m.objective_value}')