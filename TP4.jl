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
# We have a graph that contains numberOfVertices vertices
# We want to color each vertice of the graph in a way that all the neighbors of that vertice have a different color
# We want to minimize the number of colors used to color the graph

model = Model(HiGHS.Optimizer)

# Notice that a vertice can have at most numberOfVertices - 1 neighbors
# Therefore, there can be at most numberOfVertices colors

# y[j] is the variable that:
# | is 1, if the color j was used
# | is 0, otherwise
@variable(model, y[1:numberOfVertices], Bin)

# To simplify the problem, we will suppose there are numberOfVertices colors
# x[i, k] is the variable that:
# | is 1, if the vertice i is colored with the color k
# | is 0, otherwise
@variable(model, x[1:numberOfVertices, 1:numberOfVertices], Bin)

# Therefore our objective function will be:
# min sum(y[j]) with j ranging from 1 to numberOfVertices
@objective(model, Min, sum(y[j] for j in 1:numberOfVertices))

# If a graph there is an edge between two vertices, the color of the vertices must be different, more formally
# If graph[i, j] = 1, then x[i, k] != x[j, k] (being k the color of the vertice i)
# We can model that constraint by using: x[i, k] + x[j, k] <= 1 + (1 - graph[i, j]) 
# 1) If both vertices have the same color k (x[i, k]=x[j, k]=1), then certainly graph[i, j] = 0 because
#   a) x[i, k] + x[j, k] = 1 + 1 = 2
#   b) 1 + (1 - graph[i, j]) = 1 + (1 - 0) = 2
#   c) x[i, k] + x[j, k] <= 1 + (1 - graph[i, j]) ---> 2 <= 2 because a) and b)
#   d) notice that if graph[i, j] = 1, then 2 <= 1 which would be an absurd
# 2) If none of the vertices have the color k (x[i, k]=x[j, k]=0), then graph[i, j] = 0 or 1
# OBS.: notice that this satisfies the inequality: x[i, k] + x[j, k] <= 1 + (1 - graph[i, j]) =======> 0 + 0 <= 1 + (1 - 0) || 0 + 0 <= 1 + (1 - 1)
# 3) If one of the vertices have the color k and the other doesnt (x[i, k]=1 and x[j, k]=0), then graph[i, j] = 0 or 1
# OBS.: notice that this satisfies the inequality: x[i, k] + x[j, k] <= 1 + (1 - graph[i, j]) =======> 1 + 0 <= 1 + (1 - 0) || 1 + 0 <= 1 + (1 - 1)
# Therefore the following constraint holds
for i in 1:numberOfVertices
    for j in i+1:numberOfVertices
        for k in 1:numberOfVertices
            @constraint(model, x[i, k] + x[j, k] <= 1 + (1 - graph[i, j]))
        end
    end
end

# Every vertice should have exactly one color
for i in 1:numberOfVertices
    @constraint(model, sum(x[i, k] for k in 1:numberOfVertices) == 1)
end

# If a vertice i is colored with a color k (x[i, k] = 1) than that color is used (y[k] = 1)
for i in 1:numberOfVertices
    for k in 1:numberOfVertices
        @constraint(model, x[i, k] <= y[k])
    end
end


optimize!(model)


# Check if an optimal solution was found
if termination_status(model) == MOI.OPTIMAL
    
    println("TP1 2020006450 = ", objective_value(model))

    if lenArgs > 1 && ARGS[2] == "true"
        for k in 1:numberOfVertices
            
            tempArray = Int[]
            for i in 1:numberOfVertices
                if value(x[i,k]) > 0.5
                    push!(tempArray, i)
                end
            end
            lenArray = length(tempArray)
            if lenArray > 0
                print("The vertices colored with $k were : ")
                for j in 1:lenArray
                    tempValue = tempArray[j]
                    print("$tempValue   ")
                end
                println()
            end
        end
    end

else
    println("Optimal solution not found. Status: ", termination_status(model))
end