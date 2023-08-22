@doc raw"""
	write_vre_stor(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the vre-storage specific files.
"""

function write_vre_stor(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

	### CAPACITY DECISIONS ###
	dfVreStor = write_vre_stor_capacity(path, inputs, setup, EP)

	### CHARGING DECISIONS ###
	write_vre_stor_charge(path, inputs, setup, EP)

	### DISCHARGING DECISIONS ###
	write_vre_stor_discharge(path, inputs, setup, EP)

	return dfVreStor
end

@doc raw"""
	write_vre_stor_capacity(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the vre-storage capacities.
"""
function write_vre_stor_capacity(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	VRE_STOR = inputs["VRE_STOR"]
	SOLAR = inputs["VS_SOLAR"]
	WIND = inputs["VS_WIND"]
	DC = inputs["VS_DC"]
	STOR = inputs["VS_STOR"]
	dfGen = inputs["dfGen"]
	dfVRE_STOR = inputs["dfVRE_STOR"]
	MultiStage = setup["MultiStage"]
	size_vrestor_resources = size(inputs["RESOURCES_VRE_STOR"])

	# Solar capacity
	capsolar = zeros(size_vrestor_resources)
	retcapsolar = zeros(size_vrestor_resources)
	existingcapsolar = zeros(size_vrestor_resources)

	# Wind capacity
	capwind = zeros(size_vrestor_resources)
	retcapwind = zeros(size_vrestor_resources)
	existingcapwind = zeros(size_vrestor_resources)

	# Inverter capacity
	capdc = zeros(size_vrestor_resources)
	retcapdc = zeros(size_vrestor_resources)
	existingcapdc = zeros(size_vrestor_resources)

	# Grid connection capacity
	capgrid = zeros(size_vrestor_resources)
	retcapgrid = zeros(size_vrestor_resources)
	existingcapgrid = zeros(size_vrestor_resources)

	# Energy storage capacity
	capenergy = zeros(size_vrestor_resources)
	retcapenergy = zeros(size_vrestor_resources)
	existingcapenergy = zeros(size_vrestor_resources)

	# Charge storage capacity DC
	capchargedc = zeros(size_vrestor_resources)
	retcapchargedc = zeros(size_vrestor_resources)
	existingcapchargedc = zeros(size_vrestor_resources)

	# Charge storage capacity AC
	capchargeac = zeros(size_vrestor_resources)
	retcapchargeac = zeros(size_vrestor_resources)
	existingcapchargeac = zeros(size_vrestor_resources)

	# Discharge storage capacity DC
	capdischargedc = zeros(size_vrestor_resources)
	retcapdischargedc = zeros(size_vrestor_resources)
	existingcapdischargedc = zeros(size_vrestor_resources)

	# Discharge storage capacity AC
	capdischargeac = zeros(size_vrestor_resources)
	retcapdischargeac = zeros(size_vrestor_resources)
	existingcapdischargeac = zeros(size_vrestor_resources)
	
	j = 1
	for i in VRE_STOR
		existingcapgrid[j] = MultiStage == 1 ? value(EP[:vEXISTINGCAP][i]) : dfGen[i,:Existing_Cap_MW]
		if i in inputs["NEW_CAP"]
			capgrid[j] = value(EP[:vCAP][i])
		end
		if i in inputs["RET_CAP"]
			retcapgrid[j] = value(EP[:vRETCAP][i])
		end

		if i in SOLAR
			existingcapsolar[j] = MultiStage == 1 ? value(EP[:vEXISTINGSOLARCAP][i]) : dfVRE_STOR[j,:Existing_Cap_Solar_MW]
			if i in inputs["NEW_CAP_SOLAR"]
				capsolar[j] = value(EP[:vSOLARCAP][i])
			end
			if i in inputs["RET_CAP_SOLAR"]
				retcapsolar[j] = first(value.(EP[:vRETSOLARCAP][i]))
			end
		end

		if i in WIND
			existingcapwind[j] = MultiStage == 1 ? value(EP[:vEXISTINGWINDCAP][i]) : dfVRE_STOR[j,:Existing_Cap_Wind_MW]
			if i in inputs["NEW_CAP_WIND"]
				capwind[j] = value(EP[:vWINDCAP][i])
			end
			if i in inputs["RET_CAP_WIND"]
				retcapwind[j] = first(value.(EP[:vRETWINDCAP][i]))
			end
		end

		if i in DC
			existingcapdc[j] = MultiStage == 1 ? value(EP[:vEXISTINGDCCAP][i]) : dfVRE_STOR[j,:Existing_Cap_Inverter_MW]
			if i in inputs["NEW_CAP_DC"]
				capdc[j] = value(EP[:vDCCAP][i])
			end
			if i in inputs["RET_CAP_DC"]
				retcapdc[j] = first(value.(EP[:vRETDCCAP][i]))
			end
		end

		if i in STOR
			existingcapenergy[j] = MultiStage == 1 ? value(EP[:vEXISTINGCAPENERGY_VS][i]) : dfGen[i,:Existing_Cap_MWh]
			if i in inputs["NEW_CAP_STOR"]
				capenergy[j] = value(EP[:vCAPENERGY_VS][i])
			end
			if i in inputs["RET_CAP_STOR"]
				retcapenergy[j] = first(value.(EP[:vRETCAPENERGY_VS][i]))
			end

			if i in inputs["VS_ASYM_DC_CHARGE"]
				if i in inputs["NEW_CAP_CHARGE_DC"]
					capchargedc[j] = value(EP[:vCAPCHARGE_DC][i])
				end
				if i in inputs["RET_CAP_CHARGE_DC"]
					retcapchargedc[j] = value(EP[:vRETCAPCHARGE_DC][i])
				end
				existingcapchargedc[j] = MultiStage == 1 ? value(EP[:vEXISTINGCAPCHARGEDC][i]) : dfVRE_STOR[j,:Existing_Cap_Charge_DC_MW]
			end
			if i in inputs["VS_ASYM_AC_CHARGE"]
				if i in inputs["NEW_CAP_CHARGE_AC"]
					capchargeac[j] = value(EP[:vCAPCHARGE_AC][i])
				end
				if i in inputs["RET_CAP_CHARGE_AC"]
					retcapchargeac[j] = value(EP[:vRETCAPCHARGE_AC][i])
				end
				existingcapchargeac[j] = MultiStage == 1 ? value(EP[:vEXISTINGCAPCHARGEAC][i]) : dfVRE_STOR[j,:Existing_Cap_Charge_AC_MW]
			end
			if i in inputs["VS_ASYM_DC_DISCHARGE"]
				if i in inputs["NEW_CAP_DISCHARGE_DC"]
					capdischargedc[j] = value(EP[:vCAPDISCHARGE_DC][i])
				end
				if i in inputs["RET_CAP_DISCHARGE_DC"]
					retcapdischargedc[j] = value(EP[:vRETCAPDISCHARGE_DC][i])
				end
				existingcapdischargedc[j] = MultiStage == 1 ? value(EP[:vEXISTINGCAPDISCHARGEDC][i]) : dfVRE_STOR[j,:Existing_Cap_Discharge_DC_MW]
			end
			if i in inputs["VS_ASYM_AC_DISCHARGE"]
				if i in inputs["NEW_CAP_DISCHARGE_AC"]
					capdischargeac[j] = value(EP[:vCAPDISCHARGE_AC][i])
				end
				if i in inputs["RET_CAP_DISCHARGE_AC"]
					retcapdischargeac[j] = value(EP[:vRETCAPDISCHARGE_AC][i])
				end
				existingcapdischargeac[j] = MultiStage == 1 ? value(EP[:vEXISTINGCAPDISCHARGEAC][i]) : dfVRE_STOR[j,:Existing_Cap_Discharge_AC_MW]
			end
		end
		j += 1
	end

	dfCap = DataFrame(
		Resource = inputs["RESOURCES_VRE_STOR"], Zone = dfVRE_STOR[!,:Zone], Resource_Type = dfVRE_STOR[!,:Resource_Type], Cluster=dfVRE_STOR[!,:cluster], 
		StartCapSolar = existingcapsolar[:],
		RetCapSolar = retcapsolar[:],
		NewCapSolar = capsolar[:],
		EndCapSolar = existingcapsolar[:] - retcapsolar[:] + capsolar[:],
		StartCapWind = existingcapwind[:],
		RetCapWind = retcapwind[:],
		NewCapWind = capwind[:],
		EndCapWind = existingcapwind[:] - retcapwind[:] + capwind[:],
		StartCapDC = existingcapdc[:],
		RetCapDC = retcapdc[:],
		NewCapDC = capdc[:],
		EndCapDC = existingcapdc[:] - retcapdc[:] + capdc[:],
		StartCapGrid = existingcapgrid[:],
		RetCapGrid = retcapgrid[:],
		NewCapGrid = capgrid[:],
		EndCapGrid = existingcapgrid[:] - retcapgrid[:] + capgrid[:],
		StartEnergyCap = existingcapenergy[:],
		RetEnergyCap = retcapenergy[:],
		NewEnergyCap = capenergy[:],
		EndEnergyCap = existingcapenergy[:] - retcapenergy[:] + capenergy[:],
		StartChargeDCCap = existingcapchargedc[:],
		RetChargeDCCap = retcapchargedc[:],
		NewChargeDCCap = capchargedc[:],
		EndChargeDCCap = existingcapchargedc[:] - retcapchargedc[:] + capchargedc[:],
		StartChargeACCap = existingcapchargeac[:],
		RetChargeACCap = retcapchargeac[:],
		NewChargeACCap = capchargeac[:],
		EndChargeACCap = existingcapchargeac[:] - retcapchargeac[:] + capchargeac[:],
		StartDischargeDCCap = existingcapdischargedc[:],
		RetDischargeDCCap = retcapdischargedc[:],
		NewDischargeDCCap = capdischargedc[:],
		EndDischargeDCCap = existingcapdischargedc[:] - retcapdischargedc[:] + capdischargedc[:],
		StartDischargeACCap = existingcapdischargeac[:],
		RetDischargeACCap = retcapdischargeac[:],
		NewDischargeACCap = capdischargeac[:],
		EndDischargeACCap = existingcapdischargeac[:] - retcapdischargeac[:] + capdischargeac[:]
	)

	if setup["ParameterScale"] ==1
		columns_to_scale = [
			:StartCapSolar,
			:RetCapSolar,
			:NewCapSolar,
			:EndCapSolar,
			:StartCapWind,
			:RetCapWind,
			:NewCapWind,
			:EndCapWind,
			:StartCapDC,
			:RetCapDC,
			:NewCapDC,
			:EndCapDC,
			:StartCapGrid,
			:RetCapGrid,
			:NewCapGrid,
			:EndCapGrid,
			:StartEnergyCap,
			:RetEnergyCap,
			:NewEnergyCap,
			:EndEnergyCap,
			:StartChargeACCap,
			:RetChargeACCap,
			:NewChargeACCap,
			:EndChargeACCap,
			:StartChargeDCCap,
			:RetChargeDCCap,
			:NewChargeDCCap,
			:EndChargeDCCap,
			:StartDischargeDCCap,
			:RetDischargeDCCap,
			:NewDischargeDCCap,
			:EndDischargeDCCap,
			:StartDischargeACCap,
			:RetDischargeACCap,
			:NewDischargeACCap,
			:EndDischargeACCap,
		]
		dfCap[!, columns_to_scale] .*= ModelScalingFactor
	end

	total = DataFrame(
		Resource = "Total", Zone = "n/a", Resource_Type = "Total", Cluster= "n/a", 
		StartCapSolar = sum(dfCap[!,:StartCapSolar]), RetCapSolar = sum(dfCap[!,:RetCapSolar]),
		NewCapSolar = sum(dfCap[!,:NewCapSolar]), EndCapSolar = sum(dfCap[!,:EndCapSolar]),
		StartCapWind = sum(dfCap[!,:StartCapWind]), RetCapWind = sum(dfCap[!,:RetCapWind]),
		NewCapWind = sum(dfCap[!,:NewCapWind]), EndCapWind = sum(dfCap[!,:EndCapWind]),
		StartCapDC = sum(dfCap[!,:StartCapDC]), RetCapDC = sum(dfCap[!,:RetCapDC]),
		NewCapDC = sum(dfCap[!,:NewCapDC]), EndCapDC = sum(dfCap[!,:EndCapDC]),
		StartCapGrid = sum(dfCap[!,:StartCapGrid]), RetCapGrid = sum(dfCap[!,:RetCapGrid]),
		NewCapGrid = sum(dfCap[!,:NewCapGrid]), EndCapGrid = sum(dfCap[!,:EndCapGrid]),
		StartEnergyCap = sum(dfCap[!,:StartEnergyCap]), RetEnergyCap = sum(dfCap[!,:RetEnergyCap]),
		NewEnergyCap = sum(dfCap[!,:NewEnergyCap]), EndEnergyCap = sum(dfCap[!,:EndEnergyCap]),
		StartChargeACCap = sum(dfCap[!,:StartChargeACCap]), RetChargeACCap = sum(dfCap[!,:RetChargeACCap]),
		NewChargeACCap = sum(dfCap[!,:NewChargeACCap]), EndChargeACCap = sum(dfCap[!,:EndChargeACCap]),
		StartChargeDCCap = sum(dfCap[!,:StartChargeDCCap]), RetChargeDCCap = sum(dfCap[!,:RetChargeDCCap]),
		NewChargeDCCap = sum(dfCap[!,:NewChargeDCCap]), EndChargeDCCap = sum(dfCap[!,:EndChargeDCCap]),
		StartDischargeDCCap = sum(dfCap[!,:StartDischargeDCCap]), RetDischargeDCCap = sum(dfCap[!,:RetDischargeDCCap]),
		NewDischargeDCCap = sum(dfCap[!,:NewDischargeDCCap]), EndDischargeDCCap = sum(dfCap[!,:EndDischargeDCCap]),
		StartDischargeACCap = sum(dfCap[!,:StartDischargeACCap]), RetDischargeACCap = sum(dfCap[!,:RetDischargeACCap]),
		NewDischargeACCap = sum(dfCap[!,:NewDischargeACCap]), EndDischargeACCap = sum(dfCap[!,:EndDischargeACCap])
	)

	dfCap = vcat(dfCap, total)
	CSV.write(joinpath(path, "vre_stor_capacity.csv"), dfCap)
	return dfCap
end

@doc raw"""
	write_vre_stor_charge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the vre-storage charging decision variables/expressions.
"""
function write_vre_stor_charge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfVRE_STOR = inputs["dfVRE_STOR"]
	T = inputs["T"]
    DC_CHARGE = inputs["VS_STOR_DC_CHARGE"]
    AC_CHARGE = inputs["VS_STOR_AC_CHARGE"]

	# DC charging of battery dataframe
	if !isempty(DC_CHARGE)
		dfCharge_DC = DataFrame(Resource = inputs["RESOURCES_DC_CHARGE"], Zone = inputs["ZONES_DC_CHARGE"], AnnualSum = Array{Union{Missing,Float32}}(undef, size(DC_CHARGE)[1]))
		charge_dc = zeros(size(DC_CHARGE)[1], T)
		charge_dc = value.(EP[:vP_DC_CHARGE]).data ./ dfVRE_STOR[(dfVRE_STOR.STOR_DC_DISCHARGE.!=0), :EtaInverter] * (setup["ParameterScale"]==1 ? ModelScalingFactor : 1)
		dfCharge_DC.AnnualSum .= charge_dc * inputs["omega"]
		dfCharge_DC = hcat(dfCharge_DC, DataFrame(charge_dc, :auto))
		auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
		rename!(dfCharge_DC,auxNew_Names)
		total = DataFrame(["Total" 0 sum(dfCharge_DC[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
		total[:, 4:T+3] .= sum(charge_dc, dims = 1)
		rename!(total,auxNew_Names)
		dfCharge_DC = vcat(dfCharge_DC, total)
		CSV.write(joinpath(path,"vre_stor_dc_charge.csv"), dftranspose(dfCharge_DC, false), writeheader=false)
	end

	# AC charging of battery dataframe
	if !isempty(AC_CHARGE)
		dfCharge_AC = DataFrame(Resource = inputs["RESOURCES_AC_CHARGE"], Zone = inputs["ZONES_AC_CHARGE"], AnnualSum = Array{Union{Missing,Float32}}(undef, size(AC_CHARGE)[1]))
		charge_ac = zeros(size(AC_CHARGE)[1], T)
		charge_ac = value.(EP[:vP_AC_CHARGE]).data * (setup["ParameterScale"]==1 ? ModelScalingFactor : 1)
		dfCharge_AC.AnnualSum .= charge_ac * inputs["omega"]
		dfCharge_AC = hcat(dfCharge_AC, DataFrame(charge_ac, :auto))
		auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
		rename!(dfCharge_AC,auxNew_Names)
		total = DataFrame(["Total" 0 sum(dfCharge_AC[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
		total[:, 4:T+3] .= sum(charge_ac, dims = 1)
		rename!(total,auxNew_Names)
		dfCharge_AC = vcat(dfCharge_AC, total)
		CSV.write(joinpath(path,"vre_stor_ac_charge.csv"), dftranspose(dfCharge_AC, false), writeheader=false)
	end
end

@doc raw"""
	write_vre_stor_discharge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the vre-storage discharging decision variables/expressions.
"""
function write_vre_stor_discharge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfVRE_STOR = inputs["dfVRE_STOR"]
	T = inputs["T"] 
	DC_DISCHARGE = inputs["VS_STOR_DC_DISCHARGE"]
    AC_DISCHARGE = inputs["VS_STOR_AC_DISCHARGE"]
	WIND = inputs["VS_WIND"]
	SOLAR = inputs["VS_SOLAR"]

	# DC discharging of battery dataframe
	if !isempty(DC_DISCHARGE)
		dfDischarge_DC = DataFrame(Resource = inputs["RESOURCES_DC_DISCHARGE"], Zone = inputs["ZONES_DC_DISCHARGE"], AnnualSum = Array{Union{Missing,Float32}}(undef, size(DC_DISCHARGE)[1]))
		power_vre_stor = value.(EP[:vP_DC_DISCHARGE]).data .* dfVRE_STOR[(dfVRE_STOR.STOR_DC_DISCHARGE.!=0), :EtaInverter]
		if setup["ParameterScale"] == 1
			power_vre_stor *= ModelScalingFactor
		end
		dfDischarge_DC.AnnualSum .= power_vre_stor * inputs["omega"]
		dfDischarge_DC = hcat(dfDischarge_DC, DataFrame(power_vre_stor, :auto))
		auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
		rename!(dfDischarge_DC,auxNew_Names)
		total = DataFrame(["Total" 0 sum(dfDischarge_DC[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
		total[:, 4:T+3] .= sum(power_vre_stor, dims = 1)
		rename!(total,auxNew_Names)
		dfDischarge_DC = vcat(dfDischarge_DC, total)
		CSV.write(joinpath(path, "vre_stor_dc_discharge.csv"), dftranspose(dfDischarge_DC, false), writeheader=false)
	end

	# AC discharging of battery dataframe
	if !isempty(AC_DISCHARGE)
		dfDischarge_AC = DataFrame(Resource = inputs["RESOURCES_AC_DISCHARGE"], Zone = inputs["ZONES_AC_DISCHARGE"], AnnualSum = Array{Union{Missing,Float32}}(undef, size(AC_DISCHARGE)[1]))
		power_vre_stor = value.(EP[:vP_AC_DISCHARGE]).data
		if setup["ParameterScale"] == 1
			power_vre_stor *= ModelScalingFactor
		end
		dfDischarge_AC.AnnualSum .= power_vre_stor * inputs["omega"]
		dfDischarge_AC = hcat(dfDischarge_AC, DataFrame(power_vre_stor, :auto))
		auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
		rename!(dfDischarge_AC,auxNew_Names)
		total = DataFrame(["Total" 0 sum(dfDischarge_AC[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
		total[:, 4:T+3] .= sum(power_vre_stor, dims = 1)
		rename!(total,auxNew_Names)
		dfDischarge_AC = vcat(dfDischarge_AC, total)
		CSV.write(joinpath(path, "vre_stor_ac_discharge.csv"), dftranspose(dfDischarge_AC, false), writeheader=false)
	end

	# Wind generation of co-located resource dataframe
	if !isempty(WIND)
		dfVP_VRE_STOR = DataFrame(Resource = inputs["RESOURCES_WIND"], Zone = inputs["ZONES_WIND"], AnnualSum = Array{Union{Missing,Float32}}(undef, size(WIND)[1]))
		vre_vre_stor = value.(EP[:vP_WIND]).data 
		if setup["ParameterScale"] == 1
			vre_vre_stor *= ModelScalingFactor
		end
		dfVP_VRE_STOR.AnnualSum .= vre_vre_stor * inputs["omega"]
		dfVP_VRE_STOR = hcat(dfVP_VRE_STOR, DataFrame(vre_vre_stor, :auto))
		auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
		rename!(dfVP_VRE_STOR,auxNew_Names)
		total = DataFrame(["Total" 0 sum(dfVP_VRE_STOR[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
		total[:, 4:T+3] .= sum(vre_vre_stor, dims = 1)
		rename!(total,auxNew_Names)
		dfVP_VRE_STOR = vcat(dfVP_VRE_STOR, total)
		CSV.write(joinpath(path,"vre_stor_wind_power.csv"), dftranspose(dfVP_VRE_STOR, false), writeheader=false)
	end

	# Solar generation of co-located resource dataframe
	if !isempty(SOLAR)
		dfVP_VRE_STOR = DataFrame(Resource = inputs["RESOURCES_SOLAR"], Zone = inputs["ZONES_SOLAR"], AnnualSum = Array{Union{Missing,Float32}}(undef, size(SOLAR)[1]))
		vre_vre_stor = value.(EP[:vP_SOLAR]).data .* dfVRE_STOR[(dfVRE_STOR.SOLAR.!=0), :EtaInverter]
		if setup["ParameterScale"] == 1
			vre_vre_stor *= ModelScalingFactor
		end
		dfVP_VRE_STOR.AnnualSum .= vre_vre_stor * inputs["omega"]
		dfVP_VRE_STOR = hcat(dfVP_VRE_STOR, DataFrame(vre_vre_stor, :auto))
		auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
		rename!(dfVP_VRE_STOR,auxNew_Names)
		total = DataFrame(["Total" 0 sum(dfVP_VRE_STOR[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
		total[:, 4:T+3] .= sum(vre_vre_stor, dims = 1)
		rename!(total,auxNew_Names)
		dfVP_VRE_STOR = vcat(dfVP_VRE_STOR, total)
		CSV.write(joinpath(path,"vre_stor_solar_power.csv"), dftranspose(dfVP_VRE_STOR, false), writeheader=false)
	end
end
