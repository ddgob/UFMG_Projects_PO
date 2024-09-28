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

# printGraph(graph)

# The problem:
# We have a graph that contains numberOfVertices vertices
# We want to color each vertice of the graph in a way that all the neighbors of that vertice have a different color
# We also want to guarantee that, for all of the neighbors of all of the vertices colored with a color k, there will be at least one neighbor with each one of the other colors
# In other words:
#   a) Given the set Ck of vertices that are colored with the color k
#   b) Given the set notCk of vertices that are not colored with the color k
#   c) Given the set Cq of vertices that are colored with the color q
#   d) Given that q != k
#   e) It holds true that the intersection between notCk and Cq is not empty
# We want to maximize the number of colors used to color the graph

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

# We will also create a variable z[u, v, i, j] that:
# | is 1, if the edge uv, with the vertices u and v, have colors i and j respectively
# | is 0, otherwise
z = Dict()
for u in 1:numberOfVertices
    for v in u+1:numberOfVertices
        for i in 1:numberOfVertices
            for j in i+1:numberOfVertices
                if graph[u, v] == 1
                    z[u, v, i, j] = @variable(model, binary=true)
                end
            end
        end
    end
end

# Therefore our objective function will be:
# max sum(y[j]) with j ranging from 1 to numberOfVertices
@objective(model, Max, sum(y[j] for j in 1:numberOfVertices))

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

# Given that a color ci is used (y[ci]):
# 1) If every set Ci of vertices of color ci has to have edges to vertices of all other colors
# 2) If another color j is used (y[j])
# Then there must be an edge uv that has the colors i and j in the vertices of its extremities
# That can be modeled by sum(z[u, v, i, j] for all edges uv) >= y[i] + y[j] - 1 for all colors 
# i and j with i != j, because:
# 1) If the color i and j are used (y[i] + y[j] - 1 = 1 + 1 - 1 = 1), there has to necessarily  
#    be an edge uv with the colors i and j, or in other words sum(z[u, v ,i ,j] for all edges) = 1
# 2) If the one color is used and the other isn't (y[i] + y[j] - 1 = 1 + 0 - 1 = 0), there will be no
#    edge with the colors with the colors i and j, or in other words sum(z[u, v ,i ,j] for all edges) = 0
# 3) The case 2) applies to the case where neither colors i or j are used
for i in 1:numberOfVertices
    for j in i+1:numberOfVertices
        @constraint(model, sum(z[u, v, i, j] for u in 1:numberOfVertices for v in u+1:numberOfVertices if graph[u, v] == 1) >= y[i] + y[j] - 1)
    end
end

# To maintain the truth that there must be an edge uv that has the colors i and j in the vertices of its extremities
# We must guarantee that, given an edge uv, z[u, v, i, j] <= x[u, i] and z[u, v, i, j] <= x[v, j]
# So that, if there is a vertice with a given color, the z[] for all of the edges that that vertice of that color has
# must be at most 1
for u in 1:numberOfVertices
    for v in u+1:numberOfVertices
        if graph[u, v] == 1
            for i in 1:numberOfVertices
                for j in i+1:numberOfVertices
                    @constraint(model, z[u, v, i, j] <= x[u, i])
                    @constraint(model, z[u, v, i, j] <= x[v, j])
                end
            end
        end
    end
end

# Guarantees ordering to colors
for i in 1:(numberOfVertices - 1)
    @constraint(model, y[i] >= y[i+1])
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