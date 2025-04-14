@doc raw"""
	load_generators_variability!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to hourly maximum capacity factors for generators, storage, and flexible demand resources
"""
function load_generators_variability!(setup::Dict, path::AbstractString, inputs::Dict)

    # Hourly capacity factors
    TDR_directory = joinpath(path, setup["TimeDomainReductionFolder"])
    # if TDR is used, my_dir = TDR_directory, else my_dir = "system"
    my_dir = get_systemfiles_path(setup, TDR_directory, path)

    filename = "Generators_variability.csv"
    gen_var = load_dataframe(joinpath(my_dir, filename))

    all_resources = inputs["RESOURCE_NAMES"]

    existing_variability = names(gen_var)
    for r in all_resources
        if r ∉ existing_variability
            @info "assuming availability of 1.0 for resource $r."
            ensure_column!(gen_var, r, 1.0)
        end
    end

    # Reorder DataFrame to R_ID order
    select!(gen_var, [:Time_Index; Symbol.(all_resources)])

    # Maximum power output and variability of each energy resource
    inputs["pP_Max"] = transpose(Matrix{Float64}(gen_var[1:inputs["T"],
        2:(inputs["G"] + 1)]))

    println(filename * " Successfully Read!")
end

@doc raw"""
	load_generators_variability_p!(p::Portfolio, inputs::Dict)

Read input parameters from portfolio related to hourly maximum capacity factors for generators, storage, and flexible demand resources
"""
function load_generators_variability!(setup::Dict, p::Portfolio, inputs::Dict)

    # Hourly capacity factors
    # resources = Vector{Any}()
    # gen = collect(get_technologies(SupplyTechnology, p))
    # storage = collect(get_technologies(StorageTechnology, p))
    # append!(resources, gen)
    # append!(resources, storage)
    # sort!(resources, by = resources -> resources.id)
    gen_var = DataFrame(Time_Index = 1:inputs["T"])

    # inputs["pP_Max"] = zeros( inputs["T"], length(resources) )
    # for r in resources
    #     var_data = []
    #     for year in p.internal.ext["years"]
    #         for day in p.internal.ext["order_days"]
    #             ts = get_time_series(SingleTimeSeries, r, r.name, model_year = year, order_day = day)
    #             time_array = values(ts.data)
    #             append!(var_data, time_array)
                
    #         end
    #     end
    #     inputs["pP_Max"][:,r.id] = var_data
    # end
    # inputs["pP_Max"] = transpose(inputs["pP_Max"])
    all_resources = inputs["RESOURCE_NAMES"]

    existing_variability = String[]
    for r in all_resources
       if r ∉ existing_variability
           @info "assuming availability of 1.0 for resource $r."
           ensure_column!(gen_var, r, 1.0)
       end
    end

    # Reorder DataFrame to R_ID order
    select!(gen_var, [:Time_Index; Symbol.(all_resources)])

    # Maximum power output and variability of each energy resource
    inputs["pP_Max"] = transpose(Matrix{Float64}(gen_var[1:inputs["T"],
       2:(inputs["G"] + 1)]))

    println("Variable Generation Data Successfully Read!")
end

