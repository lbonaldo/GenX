"""
    precompile()

Precompiles the function `run_genx_case!` with specific arguments. 
This function is intended to speed up the first use of `run_genx_case!` 
in a new Julia session by precompiling it. 

The function redirects standard output to `devnull` to suppress any output 
generated during the precompilation process, and sets up a logger to capture 
any warnings or errors.

# Output
Returns `nothing`.

"""
function precompile()
    @info "Running precompile script for GenX. This may take a few minutes."
    redirect_stdout(devnull) do
        warnerror_logger = ConsoleLogger(stderr, Logging.Warn)
        with_logger(warnerror_logger) do
            @compile_workload begin
                run_genx_case!(joinpath(pkgdir(GenX),"precompile/case"), HiGHS.Optimizer)
            end
        end
    end
    isdir("precompile/case/results") && rm("precompile/case/results"; force=true, recursive=true)
    return nothing
end

# Precompile `run_genx_case!` if the environment variable `GENX_PRECOMPILE` is set to `true`
if get(ENV, "GENX_PRECOMPILE", "false") == "true"
    precompile()
end