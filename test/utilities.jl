using GenX
using JuMP
using Dates
using Logging, LoggingExtras



function solve_genx_model_testing(genx_setup::Dict, test_path::AbstractString)
    # Create a ConsoleLogger that prints any log messages with level >= Warn to stderr
    warnerror_logger = ConsoleLogger(stderr, Logging.Warn)

    # Redirect all log messages with level >= Warn to stderr
    return with_logger(warnerror_logger) do
        # Run the case
        OPTIMIZER = configure_solver(genx_setup["Solver"], test_path)
        inputs = load_inputs(genx_setup, test_path)
        EP = generate_model(genx_setup, inputs, OPTIMIZER)
        EP, _ = solve_model(EP, genx_setup)
        return EP, inputs, OPTIMIZER
    end
end

function write_testlog(test_path::AbstractString, message::AbstractString, test_result::Test.Result)
    # Save the results to a log file
    # Format: datetime, objective value, tolerance, test result
    
    if !isdir(joinpath("Logs"))
        mkdir(joinpath("Logs"))
    end

    log_file_path = joinpath("Logs", "$(test_path).log")

    logger = FormatLogger(open(log_file_path, "a")) do io, args
        # Write only the message
        println(io, args.message)
    end
    
    with_logger(logger) do
        time = Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
        @info "$time | $message | $test_result"
    end
end

function write_testlog(test_path::AbstractString, obj_test::Real, optimal_tol::Real, test_result::Test.Result)
    message = "$obj_test ± $optimal_tol"
    write_testlog(test_path, message, test_result)
end