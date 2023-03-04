@doc raw"""
    load_minimum_capacity_requirement!(path::AbstractString, inputs::Dict, setup::Dict)

Read input parameters related to mimimum capacity requirement constraints (e.g. technology specific deployment mandates)
"""
function load_minimum_capacity_requirement!(path::AbstractString, inputs::Dict, setup::Dict)
    filename = "Minimum_capacity_requirement.csv"
    df = DataFrame(CSV.File(joinpath(path, filename), header=true), copycols=true)
    NumberOfMinCapReqs = length(df[!,:MinCapReqConstraint])
    inputs["NumberOfMinCapReqs"] = NumberOfMinCapReqs
    inputs["MinCapReq"] = df[!,:Min_MW]
    if setup["ParameterScale"] == 1
        inputs["MinCapReq"] /= ModelScalingFactor # Convert to GW
    end
    println(filename * " Successfully Read!")
end
