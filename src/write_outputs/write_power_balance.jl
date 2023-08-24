function write_power_balance(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones
	SEG = inputs["SEG"] # Number of demand curtailment segments
	THERM_ALL = inputs["THERM_ALL"]
	VRE = inputs["VRE"]
	MUST_RUN = inputs["MUST_RUN"]
	HYDRO_RES = inputs["HYDRO_RES"]
	STOR_ALL = inputs["STOR_ALL"]
	FLEX = inputs["FLEX"]
	ELECTROLYZER = inputs["ELECTROLYZER"]
	VRE_STOR = inputs["VRE_STOR"]
	Com_list = ["Generation", "Storage_Discharge", "Storage_Charge",
	    "Flexible_Demand_Defer", "Flexible_Demand_Stasify",
	    "Demand_Response", "Nonserved_Energy",
	    "Transmission_NetExport", "Transmission_Losses",
	    "Demand"]
	if !isempty(ELECTROLYZER)
			push!(Com_list, "Electrolyzer_Consumption")
	end
	L = length(Com_list)
	dfPowerBalance = DataFrame(BalanceComponent = repeat(Com_list, outer = Z), Zone = repeat(1:Z, inner = L), AnnualSum = zeros(L * Z))
	powerbalance = zeros(Z * L, T) # following the same style of power/charge/storage/nse
	for z in 1:Z
		POWER_ZONE = intersect(dfGen[(dfGen[!, :Zone].==z), :R_ID], union(THERM_ALL, VRE, MUST_RUN, HYDRO_RES))
		powerbalance[(z-1)*L+1, :] = sum(value.(EP[:vP][POWER_ZONE, :]), dims = 1)
		if !isempty(intersect(dfGen[dfGen.Zone.==z, :R_ID], STOR_ALL))
		    STOR_ALL_ZONE = intersect(dfGen[dfGen.Zone.==z, :R_ID], STOR_ALL)
		    powerbalance[(z-1)*L+2, :] = sum(value.(EP[:vP][STOR_ALL_ZONE, :]), dims = 1)
		    powerbalance[(z-1)*L+3, :] = (-1) * sum((value.(EP[:vCHARGE][STOR_ALL_ZONE, :]).data), dims = 1)
		end
		if !isempty(intersect(dfGen[dfGen.Zone.==z, :R_ID], VRE_STOR))
			VS_ALL_ZONE = intersect(dfGen[dfGen.Zone.==z, :R_ID], inputs["VS_STOR"])
			powerbalance[(z-1)*L+2, :] = sum(value.(EP[:vP][VS_ALL_ZONE, :]), dims = 1)
			powerbalance[(z-1)*L+3, :] = (-1) * sum(value.(EP[:vCHARGE_VRE_STOR][VS_ALL_ZONE, :]).data, dims=1) 
		end
		if !isempty(intersect(dfGen[dfGen.Zone.==z, :R_ID], FLEX))
		    FLEX_ZONE = intersect(dfGen[dfGen.Zone.==z, :R_ID], FLEX)
		    powerbalance[(z-1)*L+4, :] = sum((value.(EP[:vCHARGE_FLEX][FLEX_ZONE, :]).data), dims = 1)
		    powerbalance[(z-1)*L+5, :] = (-1) * sum(value.(EP[:vP][FLEX_ZONE, :]), dims = 1)
		end
		if SEG > 1
		    powerbalance[(z-1)*L+6, :] = sum(value.(EP[:vNSE][2:SEG, :, z]), dims = 1)
		end
		powerbalance[(z-1)*L+7, :] = value.(EP[:vNSE][1, :, z])
		if Z >= 2
		    powerbalance[(z-1)*L+8, :] = (value.(EP[:ePowerBalanceNetExportFlows][:, z]))' # Transpose
		    powerbalance[(z-1)*L+9, :] = -(value.(EP[:eLosses_By_Zone][z, :]))
		end
		powerbalance[(z-1)*L+10, :] = (((-1) * inputs["pD"][:, z]))' # Transpose
		if (!isempty(ELECTROLYZER))
			powerbalance[(z-1)*L+11, :] = (-1) * sum(value.(EP[:vUSE][ELECTROLYZER, :].data), dims = 1)
		end
	end
	if setup["ParameterScale"] == 1
		powerbalance *= ModelScalingFactor
	end
	dfPowerBalance.AnnualSum .= powerbalance * inputs["omega"]
	dfPowerBalance = hcat(dfPowerBalance, DataFrame(powerbalance, :auto))
	auxNew_Names = [Symbol("BalanceComponent"); Symbol("Zone"); Symbol("AnnualSum"); [Symbol("t$t") for t in 1:T]]
	rename!(dfPowerBalance,auxNew_Names)
	CSV.write(joinpath(path, "power_balance.csv"), dftranspose(dfPowerBalance, false), writeheader=false)
end
