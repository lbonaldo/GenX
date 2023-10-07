using GenX
using Logging
using Test

@testset "Simple operation" begin
    include("simple_op_test.jl")
end

@testset "Resource validation" begin
    include("resource_test.jl")
end

@testset "Expression manipulation" begin
    include("expression_manipulation_test.jl")
end

@testset "Time domain reduction" begin
    include("time_domain_reduction.jl")
end
