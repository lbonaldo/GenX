ENV["GENX_PRECOMPILE"] = "false"

using Pkg;
Pkg.activate(@__DIR__);
using Revise
using GenX
using PowerSystemsInvestmentsPortfolios
using Gurobi
using TimeSeries
using CSV
using DataFrames
# using JLD2
# using JSON3
# using JSONSchema
# using SQLite
# using HiGHS
using Dates
using InfrastructureSystems
using PowerSystems
const PSIP = PowerSystemsInvestmentsPortfolios
const IS = InfrastructureSystems
const PSY = PowerSystems
read_from_json = true
# const PSIP_RESOURCE_TYPES = [SupplyTechnology{ThermalStandard},
#     SupplyTechnology{RenewableDispatch}, StorageTechnology{Storage}]

# function to build a portfolio based on the three_zones example from GenX
function test_portfolio(case_name::AbstractString)

    ###################
    ### Zones ###
    ###################

    z1 = Node(
        name = "MA",
        id = 1
    )

    z2 = Node(
        name = "CT",
        id = 2
    )

    z3 = Node(
        name = "ME",
        id = 3
    )

    ###################
    ### Finances ###
    ###################

    # Assume the same financial info for each technology
    tech_finance = TechnologyFinancialData(;
        interest_rate = 0.05,
        capital_recovery_period = 30,
        technology_base_year = 2025)

    base_year = 2025
    discount_rate = 0.07
    inflation_rate = 0.05
    interest_rate = 0.05
    port_finance = PortfolioFinancialData(
        base_year, discount_rate, inflation_rate, interest_rate)

    ####################
    ##### Thermals #####
    ####################

    t_ma_gas = SupplyTechnology{ThermalStandard}(;
        base_power = 1.0, # Natural Units
        outage_factor = 1.0,
        prime_mover_type = PrimeMovers.ST,
        capital_costs = LinearCurve(65400),
        time_limits = (up = 6.0, down = 6.0),
        lifetime = 30,
        ramp_limits = (up = 0.64, down = 0.64),
        available = true,
        co2 = Dict(ThermalFuels.NATURAL_GAS => 0.05306),
        name = "MA_natural_gas_combined_cycle",
        id = 1,
        initial_capacity = 0.0,
        cofire_start_limits = Dict{ThermalFuels, MinMax}(),
        financial_data = tech_finance,
        start_fuel_mmbtu_per_mw = 2.0,
        operation_costs = ThermalGenerationCost(
            variable = FuelCurve(
                value_curve = LinearCurve(7.43), fuel_cost = 5.0, vom_cost = LinearCurve(3.55)),
            fixed = 10287, start_up = 91.0, shut_down = 0.0),
        fuel = [ThermalFuels.NATURAL_GAS],
        power_systems_type = "ElectricLoad",
        cofire_level_limits = Dict{ThermalFuels, MinMax}(),
        region = [z1],
        unit_size = 250.0,
        min_generation_fraction = 0.468,
        capacity_limits = (min = 0.0, max = 10000000)
    )

    t_ct_gas = SupplyTechnology{ThermalStandard}(;
        base_power = 1.0, # Natural Units
        outage_factor = 1.0,
        prime_mover_type = PrimeMovers.ST,
        capital_costs = LinearCurve(65400),
        time_limits = (up = 6.0, down = 6.0),
        lifetime = 30,
        ramp_limits = (up = 0.64, down = 0.64),
        available = true,
        co2 = Dict(ThermalFuels.NATURAL_GAS => 0.05306),
        name = "CT_natural_gas_combined_cycle",
        id = 2,
        initial_capacity = 0.0,
        cofire_start_limits = Dict{ThermalFuels, MinMax}(),
        financial_data = tech_finance,
        start_fuel_mmbtu_per_mw = 2.0,
        operation_costs = ThermalGenerationCost(
            variable = FuelCurve(
                value_curve = LinearCurve(7.12), fuel_cost = 5.0, vom_cost = LinearCurve(3.57)),
            fixed = 9698, start_up = 91.0, shut_down = 0.0),
        fuel = [ThermalFuels.NATURAL_GAS],
        power_systems_type = "ElectricLoad",
        cofire_level_limits = Dict{ThermalFuels, MinMax}(),
        region = [z2],
        unit_size = 250.0,
        min_generation_fraction = 0.338,
        capacity_limits = (min = 0.0, max = 10000000))

    t_me_gas = SupplyTechnology{ThermalStandard}(;
        base_power = 1.0, # Natural Units
        outage_factor = 1.0,
        prime_mover_type = PrimeMovers.ST,
        capital_costs = LinearCurve(65400),
        time_limits = (up = 6.0, down = 6.0),
        lifetime = 30,
        ramp_limits = (up = 0.64, down = 0.64),
        available = true,
        co2 = Dict(ThermalFuels.NATURAL_GAS => 0.05306),
        name = "ME_natural_gas_combined_cycle",
        id = 3,
        initial_capacity = 0.0,
        cofire_start_limits = Dict{ThermalFuels, MinMax}(),
        financial_data = tech_finance,
        start_fuel_mmbtu_per_mw = 2.0,
        operation_costs = ThermalGenerationCost(
            variable = FuelCurve(
                value_curve = LinearCurve(12.62), fuel_cost = 5.0, vom_cost = LinearCurve(4.5)),
            fixed = 16291, start_up = 91.0, shut_down = 0.0),
        fuel = [ThermalFuels.NATURAL_GAS],
        power_systems_type = "ElectricLoad",
        cofire_level_limits = Dict{ThermalFuels, MinMax}(),
        region = [z3],
        unit_size = 250.0,
        min_generation_fraction = 0.474,
        capacity_limits = (min = 0.0, max = 10000000)
    )

    #####################
    ##### Renewable #####
    #####################

    t_ma_solar = SupplyTechnology{RenewableDispatch}(;
        base_power = 1.0, # Natural Units
        outage_factor = 1.0,
        prime_mover_type = PrimeMovers.PVe,
        capital_costs = LinearCurve(85300),
        id = 4,
        available = true,
        power_systems_type = "ElectricLoad",
        name = "MA_solar_pv",
        initial_capacity = 0.0,
        region = [z1],
        operation_costs = ThermalGenerationCost(variable = CostCurve(LinearCurve(0)),
            fixed = 18760, start_up = 0.0, shut_down = 0.0),
        capacity_limits = (min = 0.0, max = 10000000),
        financial_data = tech_finance)

    t_ct_wind = SupplyTechnology{RenewableDispatch}(;
        base_power = 1.0, # Natural Units
        outage_factor = 1.0,
        prime_mover_type = PrimeMovers.WT,
        capital_costs = LinearCurve(97200),
        id = 5,
        available = true,
        power_systems_type = "ElectricLoad",
        name = "CT_onshore_wind",
        initial_capacity = 0.0,
        region = [z2],
        operation_costs = ThermalGenerationCost(variable = CostCurve(LinearCurve(0.1)),
            fixed = 43205, start_up = 0.0, shut_down = 0.0),
        capacity_limits = (min = 0.0, max = 10000000),
        financial_data = tech_finance)

    t_ct_solar = SupplyTechnology{RenewableDispatch}(;
        base_power = 1.0, # Natural Units
        outage_factor = 1.0,
        prime_mover_type = PrimeMovers.PVe,
        capital_costs = LinearCurve(85300),
        id = 6,
        available = true,
        power_systems_type = "ElectricLoad",
        name = "CT_solar_pv",
        initial_capacity = 0.0,
        region = [z2],
        operation_costs = ThermalGenerationCost(variable = CostCurve(LinearCurve(0)),
            fixed = 18760, start_up = 0.0, shut_down = 0.0),
        capacity_limits = (min = 0.0, max = 10000000),
        financial_data = tech_finance)

    t_me_wind = SupplyTechnology{RenewableDispatch}(;
        base_power = 1.0, # Natural Units
        outage_factor = 1.0,
        prime_mover_type = PrimeMovers.WT,
        capital_costs = LinearCurve(97200),
        id = 7,
        available = true,
        name = "ME_onshore_wind",
        power_systems_type = "ElectricLoad",
        initial_capacity = 0.0,
        region = [z3],
        operation_costs = ThermalGenerationCost(variable = CostCurve(LinearCurve(0.1)),
            fixed = 43205, start_up = 0.0, shut_down = 0.0),
        capacity_limits = (min = 0.0, max = 10000000),
        financial_data = tech_finance)

    #####################
    ##### Storage #####
    #####################

    s_ma_battery = StorageTechnology{Storage}(;
        base_power = 1.0, # Natural Units
        prime_mover_type = PrimeMovers.BA,
        capital_costs_discharge = LinearCurve(19584),
        capital_costs_energy = LinearCurve(22494),
        capacity_limits_discharge = (min = 0.0, max = 100000000),
        capacity_limits_energy = (min = 0.0, max = 100000000),
        id = 8,
        available = true,
        name = "MA_battery",
        storage_tech = StorageTech.LIB,
        existing_capacity_discharge = 0.0,
        existing_capacity_energy = 0.0,
        power_systems_type = "Test",
        region = [z1],
        operation_costs = StorageCost(
            charge_variable_cost = CostCurve(value_curve =LinearCurve(0.15),
                vom_cost = LinearCurve(0.15)),
            discharge_variable_cost = CostCurve(value_curve = LinearCurve(0.15),
                vom_cost = LinearCurve(0.15)),
            fixed = 10000, start_up = 0.0, shut_down = 0.0),
        efficiency = (in = 0.92, out = 0.92),
        losses = 0.0,
        duration_limits = (min = 1.0, max = 10.0),
        financial_data = tech_finance)

    s_ct_battery = StorageTechnology{Storage}(;
        base_power = 1.0, # Natural Units
        prime_mover_type = PrimeMovers.BA,
        capital_costs_discharge = LinearCurve(19584),
        capital_costs_energy = LinearCurve(22494),
        capacity_limits_discharge = (min = 0.0, max = 100000000),
        capacity_limits_energy = (min = 0.0, max = 100000000),
        id = 9,
        available = true,
        name = "CT_battery",
        storage_tech = StorageTech.LIB,
        existing_capacity_discharge = 0.0,
        existing_capacity_energy = 0.0,
        power_systems_type = "Test",
        region = [z2],
        operation_costs = StorageCost(
            charge_variable_cost = CostCurve(value_curve = LinearCurve(0.15),
                vom_cost = LinearCurve(0.15)),
            discharge_variable_cost = CostCurve(value_curve = LinearCurve(0.15),
                vom_cost = LinearCurve(0.15)),
            fixed = 4895, start_up = 0.0, shut_down = 0.0),
        efficiency = (in = 0.92, out = 0.92),
        losses = 0.0,
        duration_limits = (min = 1.0, max = 10.0),
        financial_data = tech_finance)

    s_me_battery = StorageTechnology{Storage}(;
        base_power = 1.0, # Natural Units
        prime_mover_type = PrimeMovers.BA,
        capital_costs_discharge = LinearCurve(19584),
        capital_costs_energy = LinearCurve(22494),
        capacity_limits_discharge = (min = 0.0, max = 100000000),
        capacity_limits_energy = (min = 0.0, max = 100000000),
        id = 10,
        available = true,
        name = "ME_battery",
        storage_tech = StorageTech.LIB,
        existing_capacity_discharge = 0.0,
        existing_capacity_energy = 0.0,
        power_systems_type = "Test",
        region = [z3],
        operation_costs = StorageCost(
            charge_variable_cost = CostCurve(value_curve = LinearCurve(0.15),
                vom_cost = LinearCurve(0.15)),
            discharge_variable_cost = CostCurve(value_curve = LinearCurve(0.15),
                vom_cost = LinearCurve(0.15)),
            fixed = 4895, start_up = 0.0, shut_down = 0.0),
        efficiency = (in = 0.92, out = 0.92),
        losses = 0.0,
        duration_limits = (min = 1.0, max = 10.0),
        financial_data = tech_finance)

    ######################
    ######## Lines #######
    ######################

    tx_ma_ct = NodalACTransportTechnology{ACBranch}(;
        base_power = 1.0,
        name = "MA_to_CT",
        available = true,
        start_node = z1,
        end_node = z2,
        power_systems_type = "ElectricLoad",
        id = 1,
        reactance = 0.0,
        resistance = 0.0,
        voltage = 230.0,
        unit_size = 2950.0,
        capacity_limits = (min = 0.0, max = 2950),
        financial_data = tech_finance)

    tx_ma_me = NodalACTransportTechnology{ACBranch}(;
        base_power = 1.0,
        capital_cost = LinearCurve(19261),
        available = true,
        name = "MA_to_ME",
        start_node = z1,
        end_node = z3,
        id = 2,
        power_systems_type = "ElectricLoad",
        reactance = 0.0,
        resistance = 0.0,
        voltage = 230.0,
        unit_size = 2000.0,
        capacity_limits = (min = 0.0, max = 2000),
        financial_data = tech_finance)

    #####################
    ######## Load #######
    #####################

    demand_ma = DemandRequirement{PowerLoad}(
        name = "demand_mw_z1",
        id = 1,
        available = true,
        power_systems_type = "ElectricLoad",
        region = [z1],
        value_of_lost_load = 2000.0,
        peak_demand_mw = 10000.0
    )

    demand_ct = DemandRequirement{PowerLoad}(
        name = "demand_mw_z2",
        id = 2,
        available = true,
        power_systems_type = "ElectricLoad",
        region = [z2],
        value_of_lost_load = 2000.0,
        peak_demand_mw = 10000.0
    )

    demand_me = DemandRequirement{PowerLoad}(
        name = "demand_mw_z3",
        id = 3,
        available = true,
        power_systems_type = "ElectricLoad",
        region = [z3],
        value_of_lost_load = 2000.0,
        peak_demand_mw = 10000.0
    )

    #####################
    ### DemandSegment ###
    #####################   

    # demand_segments = CurtailableDemandSideTechnology{PowerLoad}(
    #     name = "segments",
    #     available = true,
    #     power_systems_type = "ElectricLoad",
    #     voll = 50000.0,
    #     segments = [1, 2, 3, 4],
    #     curtailment_cost = [1.0, 0.9, 0.55, 0.2],
    #     max_demand_curtailment = [1.0, 0.04, 0.024, 0.003],
    #     curtailment_cost_mwh = [2000.0, 1800.0, 1100.0, 400.0])

    #####################
    #### Carbon Caps ####
    ##################### 

    c1 = CarbonCaps(
        name = "CO_2_Cap_Zone_1",
        available = true,
        id = 1,
        eligible_regions = [z1],
        max_tons_mwh = 0.05,
        target_year = 2050,
        max_mtons = 0.018
    )
    c2 = CarbonCaps(
        name = "CO_2_Cap_Zone_2",
        id = 2,
        available = true,
        eligible_regions = [z2],
        max_tons_mwh = 0.05,
        target_year = 2050,
        max_mtons = 0.025
    )
    c3 = CarbonCaps(
        name = "CO_2_Cap_Zone_3",
        id = 3,
        available = true,
        eligible_regions = [z3],
        max_tons_mwh = 0.05,
        target_year = 2050,
        max_mtons = 0.025
    )

    ##########################
    #### Cap Requirements ####
    ########################## 

    cap1 = MinimumCapacityRequirements(
        target_year = 2050,
        id = 1,
        name = "min_cap_1",
        available = true,
        eligible_resources = [t_ma_solar],
        min_capacity_mw = 5000
    )

    cap2 = MinimumCapacityRequirements(
        target_year = 2050,
        id = 2,
        name = "min_cap_2",
        available = true,
        eligible_resources = [t_ct_wind],
        min_capacity_mw = 10000
    )

    cap3 = MinimumCapacityRequirements(
        target_year = 2050,
        id = 3,
        name = "min_cap_3",
        available = true,
        eligible_resources = [s_ma_battery, s_ct_battery, s_me_battery],
        min_capacity_mw = 6000
    )

    #####################
    ##### Portfolio #####
    #####################

    p_3zone = Portfolio(; financial_data = port_finance)

    # PSIP.add_financials!(p_3zone, port_finance)

    PSIP.add_region!(p_3zone, z1)
    PSIP.add_region!(p_3zone, z2)
    PSIP.add_region!(p_3zone, z3)

    PSIP.add_technology!(p_3zone, t_ma_gas)
    PSIP.add_technology!(p_3zone, t_ct_gas)
    PSIP.add_technology!(p_3zone, t_me_gas)

    PSIP.add_technology!(p_3zone, t_ma_solar)
    PSIP.add_technology!(p_3zone, t_ct_wind)
    PSIP.add_technology!(p_3zone, t_me_wind)
    PSIP.add_technology!(p_3zone, t_ct_solar)

    PSIP.add_technology!(p_3zone, s_ct_battery)
    PSIP.add_technology!(p_3zone, s_ma_battery)
    PSIP.add_technology!(p_3zone, s_me_battery)

    PSIP.add_technology!(p_3zone, tx_ma_ct)
    PSIP.add_technology!(p_3zone, tx_ma_me)

    PSIP.add_technology!(p_3zone, demand_ma)
    PSIP.add_technology!(p_3zone, demand_ct)
    PSIP.add_technology!(p_3zone, demand_me)

    # PSIP.add_technology!(p_3zone, demand_segments)

    PSIP.add_requirement!(p_3zone, cap1)
    PSIP.add_requirement!(p_3zone, cap2)
    PSIP.add_requirement!(p_3zone, cap3)

    PSIP.add_requirement!(p_3zone, c1)
    PSIP.add_requirement!(p_3zone, c2)
    PSIP.add_requirement!(p_3zone, c3)

    # Adding demand and timeseries, make artificial days and years since those arent in the inputs
    years = collect(LinRange(2020, 2030, 11))
    years = Int.(years)
    days = [1, 2, 3, 4, 5, 6, 7]
    daystr = ["01-01", "01-02", "01-03", "01-04", "01-05", "01-06", "01-07"]
    demand_data = DataFrame(CSV.File(joinpath(case_name, "TDR_results/Demand_data_ts.csv")))

    fuel_co2 = Dict("None" => 0, "CT_NG" => 0.05306, "ME_NG" => 0.05306, "MA_NG" => 0.05306)
    fuel_data = DataFrame(CSV.File(joinpath(case_name, "TDR_results/Fuels_data_ts.csv")))
    var = DataFrame(CSV.File(joinpath(
        case_name, "TDR_results/Generators_variability_ts.csv")))
    existing_variability = names(var)
    all_resources = vcat(PSIP.get_name.(PSIP.get_technologies(SupplyTechnology, p_3zone)),
        PSIP.get_name.(PSIP.get_technologies(StorageTechnology, p_3zone)))
    for r in all_resources
        if r ∉ existing_variability
            @info "assuming availability of 1.0 for resource $r."
            GenX.ensure_column!(var, r, 1.0)
        end
    end

    resolution = Dates.Hour(1)
    for y in years
        for d in days

            #filter data for investment year
            d_ma = demand_data[
                (isequal.(demand_data[!, "reference_year"], y)) .& (isequal.(
                    demand_data[!, "reference_day"], d)),
                "Demand_MW_z1"]
            d_ct = demand_data[
                (isequal.(demand_data[!, "reference_year"], y)) .& (isequal.(
                    demand_data[!, "reference_day"], d)),
                "Demand_MW_z2"]
            d_me = demand_data[
                (isequal.(demand_data[!, "reference_year"], y)) .& (isequal.(
                    demand_data[!, "reference_day"], d)),
                "Demand_MW_z3"]

            #Make timearrays
            ystr = string(y)
            dstr = daystr[d]
            dates = range(
                DateTime("$(ystr)-$(dstr)T00:00:00"), step = resolution, length = 24)

            data_demand_ma = TimeArray(dates, d_ma)
            data_demand_ct = TimeArray(dates, d_ct)
            data_demand_me = TimeArray(dates, d_me)

            ts1 = SingleTimeSeries("demand_mw_z1", data_demand_ma)
            ts2 = SingleTimeSeries("demand_mw_z2", data_demand_ct)
            ts3 = SingleTimeSeries("demand_mw_z3", data_demand_me)

            IS.add_time_series!(p_3zone.data, demand_ma, ts1; model_year = y, order_day = d)
            IS.add_time_series!(p_3zone.data, demand_ct, ts2; model_year = y, order_day = d)
            IS.add_time_series!(p_3zone.data, demand_me, ts3; model_year = y, order_day = d)

            f_ma = fuel_data[
                (isequal.(fuel_data[!, "reference_year"], y)) .& (isequal.(
                    fuel_data[!, "reference_day"], d)),
                "MA_NG"]
            f_ct = fuel_data[
                (isequal.(fuel_data[!, "reference_year"], y)) .& (isequal.(
                    fuel_data[!, "reference_day"], d)),
                "CT_NG"]
            f_me = fuel_data[
                (isequal.(fuel_data[!, "reference_year"], y)) .& (isequal.(
                    fuel_data[!, "reference_day"], d)),
                "ME_NG"]
            f_no = fuel_data[
                (isequal.(fuel_data[!, "reference_year"], y)) .& (isequal.(
                    fuel_data[!, "reference_day"], d)),
                "None"]

            ts1f = SingleTimeSeries("MA_NG", TimeArray(dates, f_ma))
            ts2f = SingleTimeSeries("CT_NG", TimeArray(dates, f_ct))
            ts3f = SingleTimeSeries("ME_NG", TimeArray(dates, f_me))
            tsnf = SingleTimeSeries("None", TimeArray(dates, f_no))

            IS.add_time_series!(
                p_3zone.data, t_ma_gas, ts1f; model_year = y, order_day = d, type = "MA_NG")
            IS.add_time_series!(
                p_3zone.data, t_ct_gas, ts2f; model_year = y, order_day = d, type = "CT_NG")
            IS.add_time_series!(
                p_3zone.data, t_me_gas, ts3f; model_year = y, order_day = d, type = "ME_NG")
            IS.add_time_series!(p_3zone.data, t_ma_solar, tsnf;
                model_year = y, order_day = d, type = "None")
            IS.add_time_series!(
                p_3zone.data, t_ct_wind, tsnf; model_year = y, order_day = d, type = "None")
            IS.add_time_series!(
                p_3zone.data, t_me_wind, tsnf; model_year = y, order_day = d, type = "None")
            IS.add_time_series!(p_3zone.data, t_ct_solar, tsnf;
                model_year = y, order_day = d, type = "None")

            vmag = var[
                (isequal.(var[!, "reference_year"], y)) .& (isequal.(
                    var[!, "reference_day"], d)),
                "MA_natural_gas_combined_cycle"]
            vmas = var[
                (isequal.(var[!, "reference_year"], y)) .& (isequal.(
                    var[!, "reference_day"], d)),
                "MA_solar_pv"]
            vctg = var[
                (isequal.(var[!, "reference_year"], y)) .& (isequal.(
                    var[!, "reference_day"], d)),
                "CT_natural_gas_combined_cycle"]
            vctw = var[
                (isequal.(var[!, "reference_year"], y)) .& (isequal.(
                    var[!, "reference_day"], d)),
                "CT_onshore_wind"]
            vcts = var[
                (isequal.(var[!, "reference_year"], y)) .& (isequal.(
                    var[!, "reference_day"], d)),
                "CT_solar_pv"]
            vmeg = var[
                (isequal.(var[!, "reference_year"], y)) .& (isequal.(
                    var[!, "reference_day"], d)),
                "ME_natural_gas_combined_cycle"]
            vmew = var[
                (isequal.(var[!, "reference_year"], y)) .& (isequal.(
                    var[!, "reference_day"], d)),
                "ME_onshore_wind"]
            vmab = var[
                (isequal.(var[!, "reference_year"], y)) .& (isequal.(
                    var[!, "reference_day"], d)),
                "MA_battery"]
            vctb = var[
                (isequal.(var[!, "reference_year"], y)) .& (isequal.(
                    var[!, "reference_day"], d)),
                "CT_battery"]
            vmeb = var[
                (isequal.(var[!, "reference_year"], y)) .& (isequal.(
                    var[!, "reference_day"], d)),
                "ME_battery"]

            ts_var_ma_gas = SingleTimeSeries(
                "MA_natural_gas_combined_cycle", TimeArray(dates, vmag))
            ts_var_ma_solar = SingleTimeSeries("MA_solar_pv", TimeArray(dates, vmas))
            ts_var_ct_gas = SingleTimeSeries(
                "CT_natural_gas_combined_cycle", TimeArray(dates, vctg))
            ts_var_ct_wind = SingleTimeSeries("CT_onshore_wind", TimeArray(dates, vctw))
            ts_var_ct_solar = SingleTimeSeries("CT_solar_pv", TimeArray(dates, vcts))
            ts_var_me_gas = SingleTimeSeries(
                "ME_natural_gas_combined_cycle", TimeArray(dates, vmeg))
            ts_var_me_wind = SingleTimeSeries("ME_onshore_wind", TimeArray(dates, vmew))
            ts_var_ma_battery = SingleTimeSeries("MA_battery", TimeArray(dates, vmab))
            ts_var_ct_battery = SingleTimeSeries("CT_battery", TimeArray(dates, vctb))
            ts_var_me_battery = SingleTimeSeries("ME_battery", TimeArray(dates, vmeb))

            IS.add_time_series!(
                p_3zone.data, t_ma_gas, ts_var_ma_gas; model_year = y, order_day = d)
            IS.add_time_series!(
                p_3zone.data, t_ct_gas, ts_var_ct_gas; model_year = y, order_day = d)
            IS.add_time_series!(
                p_3zone.data, t_me_gas, ts_var_me_gas; model_year = y, order_day = d)
            IS.add_time_series!(p_3zone.data, s_ma_battery, ts_var_ma_battery;
                model_year = y, order_day = d)
            IS.add_time_series!(p_3zone.data, s_ct_battery, ts_var_ct_battery;
                model_year = y, order_day = d)
            IS.add_time_series!(p_3zone.data, s_me_battery, ts_var_me_battery;
                model_year = y, order_day = d)
            IS.add_time_series!(
                p_3zone.data, t_me_wind, ts_var_me_wind; model_year = y, order_day = d)
            IS.add_time_series!(
                p_3zone.data, t_ct_wind, ts_var_ct_wind; model_year = y, order_day = d)
            IS.add_time_series!(
                p_3zone.data, t_ma_solar, ts_var_ma_solar; model_year = y, order_day = d)
            IS.add_time_series!(
                p_3zone.data, t_ct_solar, ts_var_ct_solar; model_year = y, order_day = d)
        end
    end

    # Using the portfolio's extension to add additional data without corresponding structs for the time being.
    # This is mostly information related to policies and timesteps that have not yet been implemented
    e = Dict()

    e["Regions"] = ["MA", "CT", "ME"]

    # Need portfolio settings, this could go in there
    # 
    # Add different timeseries for each representative period, use attributes to make ordering easier

    e["Rep_Periods"] = 11
    e["Timesteps_per_Rep_Period"] = 168
    e["Sub_Weights"] = [842.3076923,
        673.8461538,
        673.8461538,
        673.8461538,
        2526.923077,
        168.4615385,
        1853.076923,
        505.3846154,
        168.4615385,
        505.3846154,
        168.4615385
    ]
    e["total_timesteps"] = 1848
    e["years"] = Int.(collect(LinRange(2020, 2030, 11)))
    e["order_days"] = [1, 2, 3, 4, 5, 6, 7]

    e["Minimum_capacity_requirement"] = Dict(1 => 5000, 2 => 10000, 3 => 6000)
    e["resource_capacity_requirement"] = Dict(
        "Min_Cap_1" => ["MA_solar_pv"],
        "Min_Cap_2" => ["CT_onshore_wind"],
        "Min_Cap_3" => ["MA_battery", "ME_battery", "CT_battery"]
    )

    p_3zone.internal.ext = e

    return p_3zone
end

if read_from_json == false
    # Build portfolio from the function above and then run GenX
    case = joinpath(@__DIR__, "example_systems/1_three_zones")
    p = test_portfolio(case)
else
    # Load portfolio from file
    case = joinpath(@__DIR__, "/Users/sc87/code/GenX_PowerGenome/PSIP_GenX/GenX/example_systems/portfolio_julia_20250512")
    case_json = joinpath(case, "portfolio_julia.json")
    p = PSIP.Portfolio(case_json)
end
# Run GenX case
# run_genx_case!(case; optimizer = Gurobi.Optimizer, portfolio = p)
run_genx_case!(case; optimizer = Gurobi.Optimizer, portfolio = p)

# Testing individual build and solve functions
if read_from_json == false
    # Build portfolio from the function above and then run GenX
    path = joinpath(@__DIR__, "example_systems/1_three_zones")
else
    # Load portfolio from file
    path = joinpath(@__DIR__, "/Users/sc87/code/GenX_PowerGenome/PSIP_GenX/GenX/example_systems/portfolio_julia_20250512")
end

settings_path = GenX.get_settings_path(path)
genx_settings = GenX.get_settings_path(path, "genx_settings.yml") # Settings YAML file path, make sure InputType field is correct!
writeoutput_settings = GenX.get_settings_path(path, "output_settings.yml") # Write-output settings YAML file path
mysetup = GenX.configure_settings(genx_settings, writeoutput_settings) # mysetup dictionary stores settings and GenX-specific parameters

optimizer = Gurobi.Optimizer
OPTIMIZER = GenX.configure_solver(settings_path, optimizer)

# Build model with normal CSV inputs
inputs_csv = GenX.load_inputs_csv(mysetup, path)
EP_csv = GenX.generate_model(mysetup, inputs_csv, OPTIMIZER, settings_path)
CSV.write("csv_model.csv", EP_csv.obj_dict)

# Build model with with a PSIP portfolio
inputs_p = GenX.load_inputs_portfolio(mysetup, p, path)
#inputs_p["RESOURCES"] = inputs_csv["RESOURCES"]
EP_p = GenX.generate_model(mysetup, inputs_p, OPTIMIZER, settings_path)
CSV.write("portfolio_model.csv", EP_p.obj_dict)

# Solve model with either set of inputs
EP, solve_time = GenX.solve_model(EP_p, mysetup)
EP, solve_time = GenX.solve_model(EP_csv, mysetup)

# Comparing individual load functions

# Initialize dictionaries
inputs_p = Dict()
inputs_csv = Dict()

#run_genx_case!(dirname(@__FILE__))

# Network Data
GenX.load_network_data_p!(mysetup, p, inputs_p)
GenX.load_network_data!(mysetup, joinpath(path, "system"), inputs_csv)

GenX.load_demand_data!(mysetup, path, inputs_csv)
GenX.load_demand_data!(mysetup, p, inputs_p)

GenX.load_fuels_data!(mysetup, path, inputs_csv)
GenX.load_fuels_data_p!(mysetup, p, inputs_p)

GenX.load_resources_data!(inputs_csv, mysetup, path, joinpath(path, "resources"))
GenX.load_resources_data_p!(inputs_p, mysetup, p, path, joinpath(path, "resources"))

GenX.load_generators_variability!(mysetup, path, inputs_csv)
GenX.load_generators_variability!(mysetup, p, inputs_p)

# Test entire load inputs process
inputs_csv = GenX.load_inputs_csv(mysetup, path)
inputs_p = GenX.load_inputs_portfolio(mysetup, p, path)

#Comparing individual values in the inputs dictionary. Note that resource data will not match even if they have the same fields, since
#the order of the keys in the dictionary is not the same
keys = [inputs_csv.keys[i]
        for i in 1:length(inputs_csv.keys) if isassigned(inputs_csv.keys, i)]
for k in keys
    #print("\n", k)
    if haskey(inputs_p, k)
        if inputs_csv[k] != inputs_p[k]
            print("\nKey does not match: ", k)
        end
    else
        print("\nKey not in portfolio inputs: ", k)
    end
end
