using GenX
using Test
using Logging

include("utilities.jl")


@testset "Simple operation" begin
    include("simple_op_test.jl")
end

@testset "Resource validation" begin
    include("resource_test.jl")
end

@testset "Expression manipulation" begin
    include("expression_manipulation_test.jl")
end

# Test GenX modules
@testset "Time domain reduction" begin
    include("time_domain_reduction.jl")
end

@testset "PiecewiseFuel CO2" begin
    include("PiecewiseFuel_CO2.jl")
end 

@testset "VRE and storage" begin
    include("VREStor.jl")
end

@testset "Electrolyzer" begin
    include("electrolyzer.jl")
end

@testset "Method of Morris" begin
    include("methodofmorris.jl")
end

@testset "Multi Stage" begin
    include("multistage.jl")
end