module TestThreeZones

using Test

include(joinpath(@__DIR__, "utilities.jl"))

obj_true = 6960.20855
test_path = "ThreeZones"

# Define test inputs
genx_setup = Dict(
    "OverwriteResults" => 0,
    "PrintModel" => 0,
    "NetworkExpansion" => 1,
    "Trans_Loss_Segments" => 1,
    "Reserves" => 0,
    "EnergyShareRequirement" => 0,
    "CapacityReserveMargin" => 0,
    "CO2Cap" => 2,
    "StorageLosses" => 1,
    "MinCapReq" => 1,
    "MaxCapReq" => 0,
    "ParameterScale" => 1,
    "UCommit" => 2,
    "TimeDomainReductionFolder" => "TDR_Results",
    "TimeDomainReduction" => 0,
    "MultiStage" => 0,
    "MethodofMorris" => 0,
    "EnableJuMPStringNames" => false,
    "IncludeLossesInESR" => 0,
)

# Run the case and get the objective value and tolerance
EP, _, _ = redirect_stdout(devnull) do
    run_genx_case_testing(test_path, genx_setup)
end
obj_test = objective_value(EP)
optimal_tol_rel = get_attribute(EP, "ipm_optimality_tolerance")
optimal_tol = optimal_tol_rel * obj_test  # Convert to absolute tolerance

# Test the objective value
test_result = @test obj_test ≈ obj_true atol = optimal_tol

# Round objective value and tolerance. Write to test log.
obj_test = round_from_tol!(obj_test, optimal_tol)
optimal_tol = round_from_tol!(optimal_tol, optimal_tol)
write_testlog(test_path, obj_test, optimal_tol, test_result)

end # module TestThreeZones
