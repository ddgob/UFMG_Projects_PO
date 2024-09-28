using JuMP, HiGHS

function printFileReadInfo(numberOfPeriods, periodProductionCost, periodDemand, periodStockCost, periodLateFee)
    println("Number of periods $numberOfPeriods")
    for i in 1:numberOfPeriods
        productionCost = periodProductionCost[i]
        demand = periodDemand[i]
        stockCost = periodStockCost[i]
        lateFee = periodLateFee[i]
        println("-------------- Start Period $i --------------")
        println("Production cost = $productionCost")
        println("Demand = $demand")
        println("Stock = $stockCost")
        println("LateFee = $lateFee")
        println("-------------- End Period $i --------------")
    end
end

function processInstance(instancePath)
    
    numberOfPeriods = nothing
    periodProductionCost = Float64[]
    periodDemand = Float64[]
    periodStockCost = Float64[]
    periodLateFee = Float64[]

    try
        open(instancePath, "r") do file

            numberOfPeriods = parse(Int, split(readline(file), '\t')[2])
            periodProductionCost = zeros(Float64, numberOfPeriods)
            periodDemand = zeros(Float64, numberOfPeriods)
            periodStockCost = zeros(Float64, numberOfPeriods)
            periodLateFee = zeros(Float64, numberOfPeriods)
            for line in eachline(file)

                splitLine = split(line, '\t')
                id = splitLine[1]
                num = parse(Int, splitLine[2])
                value = parse(Float64, splitLine[3])

                if id == "c"
                    periodProductionCost[num] = value
                elseif id == "d"
                    periodDemand[num] = value
                elseif id == "s"
                    periodStockCost[num] = value
                elseif id == "p"
                    periodLateFee[num] = value
                else
                    println("Error reading input file")
                    exit(1)
                end
                
            end

        end
    catch err
        println("Error opening or processing file:", err)
        exit(1)
    end

    return numberOfPeriods, periodProductionCost, periodDemand, periodStockCost, periodLateFee

end

# Validates the command line arguments
if length(ARGS) != 1 && length(ARGS) != 2
    println("Usage: julia tp1_2020006450.jl <path_to_instance_of_problem> <optional_true_to_output_production_each_period>")
    exit(1)
end

# Extract the path to the instance file 
# from the command line arguments
instancePath = ARGS[1]
lenArgs = length(ARGS)

numberOfPeriods, periodProductionCost, periodDemand, periodStockCost, periodLateFee = processInstance(instancePath)

# The problem:
# We want to help a producer plan out his production
# Production schedule is divided into periods, and there are numberOfPeriods periods
# Each period i has a demand periodDemand[i] that has to be satisfied
# To produce in a given period i there is an associated cost of periodProductionCost[i]
# In a given period, we can choose to produce more than the required demand and stock the excess production for the next period
# The cost to store excess production from a period i to a period i+1 is given by periodDemand[i]
# Due to production seasonality, backlogs in production may occur
# In the case backlogs occur from one period i to the next period i+1, there is an associated late fee of periodLateFee[i]
# We want to minimize the costs to satisfy all demands, therefore maximizing profits

model = Model(HiGHS.Optimizer)

# x[i] is the variable that indicates the amount (non-negative integer) of products produced in a given period i
@variable(model, x[1:numberOfPeriods] >= 0)

# s[i] is the variable that indicates the amount (non-negative integer) of products that were in excess of the demand of a given period i and went on as stock to period i+1
@variable(model, s[1:numberOfPeriods] >= 0)

# b[i] is the variable that indicates the amount (non-negative integer) of products that were not satisfied from the demand of a given period i and went as a backlog to period i+1
@variable(model, b[1:numberOfPeriods] >= 0)

# Therefore our objective function will be:
# min sum(x[i] * periodProductionCost[i] + s[i] * periodStockCost[i] + b[i] * periodLateFee[i]) with i ranging from 1 to numberOfPeriods
@objective(model, Min, sum(x[i] * periodProductionCost[i] + s[i] * periodStockCost[i] + b[i] * periodLateFee[i] for i in 1:numberOfPeriods))

# There cannot be backlog from a period before period 1, more formally:
# b[1] = 0
@constraint(model, b[1] == 0)

# There cannot be storage after the last period, more formally:
# s[numberOfPeriods] = 0
@constraint(model, s[numberOfPeriods] == 0)

# There cannot be storage coming from before the first period
@constraint(model, s[1] == 0)

# There cannot be backlog after the last period
@constraint(model, b[numberOfPeriods] == 0)

for i in 1:numberOfPeriods
    if i == 1
        @constraint(model, x[i] - periodDemand[i] == s[i] - b[i])
    else
        # Due to flux conservation, all the credits and debits that go into a period must go out of that period
        @constraint(model, x[i] + s[i-1] - periodDemand[i] - b[i-1] == s[i] - b[i])
    end
end


optimize!(model)


# Check if an optimal solution was found
if termination_status(model) == MOI.OPTIMAL
    
    println("TP1 2020006450 = ", objective_value(model))

    if lenArgs > 1 && ARGS[2] == "true"
        for i in 1:numberOfPeriods
            println("In period ", i, " the production amount was = ", value(x[i]))
        end
    end

else
    println("Optimal solution not found. Status: ", termination_status(model))
end