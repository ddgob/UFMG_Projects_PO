using JuMP, HiGHS

function processInstance(instancePath)
    
    numberOfObjects = nothing
    objectWeights = Float64[]

    try
        open(instancePath, "r") do file

            numberOfObjects = parse(Int, split(readline(file), '\t')[2])
            objectWeights = zeros(Float64, numberOfObjects)
            i = 1
            for line in eachline(file)
                currentWeight = parse(Float64, split(line, '\t')[3])
                objectWeights[i] = currentWeight
                i += 1
            end

        end
    catch err
        println("Error opening or processing file:", err)
        exit(1)
    end

    return numberOfObjects, objectWeights

end

# Validates the command line arguments
if length(ARGS) != 1 && length(ARGS) != 2
    println("Usage: julia tp1_2020006450.jl <path_to_instance_of_problem> <optional_true_to_output_object_box_allocation>")
    exit(1)
end

# Extract the path to the instance file 
# from the command line arguments
instancePath = ARGS[1]
lenArgs = length(ARGS)

numberOfObjects, objectWeights = processInstance(instancePath)

# The problem:
# We have a set of numberOfObjects objects that have corresponding weights
# We have a set of boxes that can contain up to 20 weight units each
# We can fit as many objects in a box as we can, as long as we dont surpass the 20 weight unit limit
# We want to find the smallest number of boxes possible that fit all the objects
# In other words, we want to minimize the number of boxes

# We will suppose that there are no objects that have a weight higher than 20 weight units

model = Model(HiGHS.Optimizer)

# There are at most as many boxes as there are objects, more formally:
# Be the number of boxes numberOfBoxes and the number os objects numberOfObjects, then numberOfBoxes <= numberOfObjects
# To facilitate the resolution of our problem we can suppose that there are numberOfBoxes boxes and numberOfBoxes = numberOfObjects
numberOfBoxes = numberOfObjects

# y[j] is the variable that:
# | is 1, if the box j contains an object
# | is 0, otherwise
@variable(model, y[1:numberOfBoxes], Bin)

# x[i,j] is the variable that:
# | is 1, if the object i is contained in box j
# | is 0, otherwise
@variable(model, x[1:numberOfObjects, 1:numberOfBoxes], Bin)

# Therefore our objective function will be:
# min sum(y[j]) with j ranging from 1 to numberOfBoxes
@objective(model, Min, sum(y[j] for j in 1:numberOfBoxes))

# Each object must be contained in exactly one box, more formally:
# for all objects (all i's) the sum sum(x[i,j]) with j ranging from 1 to numberOfBoxes must be equal to 1
for i in 1:numberOfObjects
    @constraint(model, sum(x[i, j] for j in 1:numberOfBoxes) == 1)
end

# Each box must contain at most a weight of 20, more formally:
# for all boxes (all j's) the sum sum(x[i,j] * objectWeights[i]) with i ranging from 1 to numberOfObjects must be less or equal to 20
# OBS.: we will multiply the weight limit 20 by y[j] (if the box j contains an object) to enforce that the least number of boxes possible are used
for j in 1:numberOfBoxes
    @constraint(model, sum(x[i, j] * objectWeights[i] for i in 1:numberOfObjects) <= 20*y[j])
end

# Ensure objects can only be placed in 'active' boxes to enforce that the least number of boxes possible are used
for i in 1:numberOfObjects, j in 1:numberOfBoxes
    @constraint(model, x[i,j] <= y[j])
end


optimize!(model)

# Check if an optimal solution was found
if termination_status(model) == MOI.OPTIMAL
    
    println("TP1 2020006450 = ", objective_value(model))

    if lenArgs > 1 && ARGS[2] == "true"
        for j in 1:numberOfBoxes
            # if box is used
            if value(y[j]) > 0.5  
                println("Box ", j, " contains objects: ", [i-1 for i in 1:numberOfObjects if value(x[i,j]) > 0.5])
            end
        end
    end

else
    println("Optimal solution not found. Status: ", termination_status(model))
end





