using GenX
using JuMP
using Dates
using Logging, LoggingExtras


function solve_genx_model_testing(genx_setup::Dict, test_path::AbstractString)
    # Suppress printing on console
    console_out = stdout
    redirect_stdout(devnull)

    # Run the case
    OPTIMIZER = configure_solver(genx_setup["Solver"], test_path)
    inputs = load_inputs(genx_setup, test_path)
    EP = generate_model(genx_setup, inputs, OPTIMIZER)
    EP, _ = solve_model(EP, genx_setup)
    # Get and return the objective value and tolerance
    obj_test = objective_value(EP)
    optimal_tol = get_attribute(EP, "dual_feasibility_tolerance")

    # Restore printing on console
    redirect_stdout(console_out)

    return obj_test, optimal_tol
end

function write_testlog(test_path::AbstractString, obj_test::Real, optimal_tol::Real, test_result::Test.Result)
    # Save the results to a log file
    # Format: datetime, objective value, tolerance, test result
    
    if !isdir(joinpath("Logs"))
        mkdir(joinpath("Logs"))
    end

    log_file_path = joinpath("Logs", "$(test_path).log")
    logger = FileLogger(log_file_path; append = true)
    with_logger(logger) do
        time = Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
        @info "$time\t$obj_test ± $optimal_tol\t$test_result"
    end
end