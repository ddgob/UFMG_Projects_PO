using JuMP, HiGHS

function printGraph(graph)

    println(numberOfVertices)

    for i in 1:numberOfVertices

        for j in 1:numberOfVertices
            print(graph[i, j], " ")
        end

        println()

    end
end

function processInstance(instancePath)
    
    numberOfVertices = nothing
    graph = nothing

    try
        open(instancePath, "r") do file

            numberOfVertices = parse(Int, split(readline(file), '\t')[2])
            graph = zeros(Int, numberOfVertices, numberOfVertices)

            for line in eachline(file)
                origin = parse(Int, split(line, '\t')[2])
                destination = parse(Int, split(line, '\t')[3])
                graph[origin, destination] = 1
            end

        end
    catch err
        println("Error opening or processing file:", err)
        exit(1)
    end

    return numberOfVertices, graph

end

# Validate command line arguments
if length(ARGS) != 1 && length(ARGS) != 2
    println("Usage: julia tp1_2020006450.jl <path_to_instance_of_problem> <optional_true_to_output_vertice_solution_set>")
    exit(1)
end

# Extract the path to the instance file 
# from the command line arguments
instancePath = ARGS[1]
lenArgs = length(ARGS)

numberOfVertices, graph = processInstance(instancePath)

# The problem:
# We have an undirected graph where there are numberOfVertices
# We want to find the maximal induced subgraph that form a clique
# OBS.: a clique is a set of vertices where every vertice is connected to all other vertices of the set
# In other words, we want to find the biggest clique of the graph

# Consider that S is the set of vertices that form the maximal clique

model = Model(HiGHS.Optimizer)

# x[i] is the variable that:
# | is 1, if the vertice i belongs to S
# | is 0, otherwise
@variable(model, x[1:numberOfVertices], Bin)

# Therefore the objective function will be to maximize the number of vertices in S:
# max sum(x[i]) with i ranging from 1 to numberOfVertices
@objective(model, Max, sum(x[i] for i in 1:numberOfVertices))

# Each vertice that belongs to S must be adjacent to every other vertice in S, more formally:
# 1) If two vertices i and j (i != j) are both in S (x[i]=x[j]=1) then certainly graph[i,j] = 1
# 2) If two vertices i and j (i != j) are both NOT in S (x[i]=x[j]=0) then certainly: 
#   a) x[i] + x[j] = 0
#   b) x[i] + x[j] <= 1 because a)
#   c) x[i] + x[j] <= graph[i,j], because a) and because graph[i,j] = 0 or 1
#   d) x[i] + x[j] <= graph[i,j] + 1, because a) and b)
# 3) If one vertice i is in S and another vertice j is NOT in S (x[i]=1 and x[j]=0 or vice versa) then certainly graph[i,j] = 0. because all of the neighbors of i are necessarily in S
# This way, we can guarantee that all vertices that are in the clique are adjacent
for i in 1:numberOfVertices
    for j in (i+1):numberOfVertices
        @constraint(model, x[i] + x[j] <= graph[i, j] + 1)
    end
end


optimize!(model)


# Check if optimal solution was found
if termination_status(model) == MOI.OPTIMAL

    println("TP1 2020006450 = ", objective_value(model))

    if lenArgs > 1 && ARGS[2] == "true"
        for i in 1:numberOfVertices

            if value(x[i]) > 0.5
                println(i)
            end

        end
    end
else
    println("An optimal solution was not found.")
end