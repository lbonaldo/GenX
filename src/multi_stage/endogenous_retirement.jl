@doc raw"""
	function get_retirement_stage(cur_stage::Int, stage_len::Int, lifetime::Int, stage_lens::Array{Int, 1})

This function determines the model stage before which all newly built capacity must be retired. Used to enforce endogenous lifetime retirements in multi-stage modeling.

inputs:

  * cur\_stage – An Int representing the current model stage $p$.
  * lifetime – An Int representing the lifetime of a particular resource.
  * stage\_lens – An Int array representing the length $L$ of each model stage.

returns: An Int representing the model stage in before which the resource must retire due to endogenous lifetime retirements.
"""
function get_retirement_stage(cur_stage::Int, lifetime::Int, stage_lens::Array{Int, 1})
	years_from_start = sum(stage_lens[1:cur_stage]) # Years from start from the END of the current stage
	ret_years = years_from_start - lifetime # Difference between end of current stage and technology lifetime
	ret_stage = 0 # Compute the stage before which all newly built capacity must be retired by the end of the current stage
	while (ret_years - stage_lens[ret_stage+1] >= 0) & (ret_stage < cur_stage)
		ret_stage += 1
		ret_years -= stage_lens[ret_stage]
	end
    return Int(ret_stage)
end

function endogenous_retirement!(EP::Model, inputs::Dict, setup::Dict)
	multi_stage_settings = setup["MultiStageSettingsDict"]

	println("Endogenous Retirement Module")

	num_stages = multi_stage_settings["NumStages"]
	cur_stage = multi_stage_settings["CurStage"]
	stage_lens = multi_stage_settings["StageLengths"]

	endogenous_retirement_discharge!(EP, inputs, num_stages, cur_stage, stage_lens)

	if !isempty(inputs["STOR_ALL"])
		endogenous_retirement_energy!(EP, inputs, num_stages, cur_stage, stage_lens)
	end

	if !isempty(inputs["STOR_ASYMMETRIC"])
		endogenous_retirement_charge!(EP, inputs, num_stages, cur_stage, stage_lens)
	end

	if !isempty(inputs["VRE_STOR"])
		if !isempty(inputs["VS_DC"])
			endogenous_retirement_vre_stor_dc!(EP, inputs, num_stages, cur_stage, stage_lens)
		end

		if !isempty(inputs["VS_SOLAR"])
			endogenous_retirement_vre_stor_solar!(EP, inputs, num_stages, cur_stage, stage_lens)
		end

		if !isempty(inputs["VS_WIND"])
			endogenous_retirement_vre_stor_wind!(EP, inputs, num_stages, cur_stage, stage_lens)
		end

		if !isempty(inputs["VS_STOR"])
			endogenous_retirement_vre_stor_stor!(EP, inputs, num_stages, cur_stage, stage_lens)
		end

		if !isempty(inputs["VS_ASYM_DC_DISCHARGE"])
			endogenous_retirement_vre_stor_discharge_dc!(EP, inputs, num_stages, cur_stage, stage_lens)
		end

		if !isempty(inputs["VS_ASYM_DC_CHARGE"])
			endogenous_retirement_vre_stor_charge_dc!(EP, inputs, num_stages, cur_stage, stage_lens)
		end

		if !isempty(inputs["VS_ASYM_AC_DISCHARGE"])
			endogenous_retirement_vre_stor_discharge_ac!(EP, inputs, num_stages, cur_stage, stage_lens)
		end

		if !isempty(inputs["VS_ASYM_AC_CHARGE"])
			endogenous_retirement_vre_stor_charge_ac!(EP, inputs, num_stages, cur_stage, stage_lens)
		end
	end

end

function endogenous_retirement_discharge!(EP::Model, inputs::Dict, num_stages::Int, cur_stage::Int, stage_lens::Array{Int, 1})

	println("Endogenous Retirement (Discharge) Module")
	
	dfGen = inputs["dfGen"]

	G = inputs["G"] # Number of resources (generators, storage, DR, and DERs)

	NEW_CAP = inputs["NEW_CAP"] # Set of all resources eligible for new capacity
	RET_CAP = inputs["RET_CAP"] # Set of all resources eligible for capacity retirements
	COMMIT = inputs["COMMIT"] # Set of all resources eligible for unit commitment

	### Variables ###

	# Keep track of all new and retired capacity from all stages
	@variable(EP, vCAPTRACK[y in RET_CAP,p=1:num_stages] >= 0 )
	@variable(EP, vRETCAPTRACK[y in RET_CAP,p=1:num_stages] >= 0 )

	### Expressions ###

	@expression(EP, eNewCap[y in RET_CAP],
		if y in NEW_CAP
			EP[:vCAP][y]
		else
			EP[:vZERO]
		end
	)

	@expression(EP, eRetCap[y in RET_CAP], EP[:vRETCAP][y])

	# Construct and add the endogenous retirement constraint expressions
	@expression(EP, eRetCapTrack[y in RET_CAP], sum(EP[:vRETCAPTRACK][y,p] for p=1:cur_stage))
	@expression(EP, eNewCapTrack[y in RET_CAP], sum(EP[:vCAPTRACK][y,p] for p=1:get_retirement_stage(cur_stage, dfGen[!,:Lifetime][y], stage_lens)))
	@expression(EP, eMinRetCapTrack[y in RET_CAP],
		if y in COMMIT
			sum((dfGen[!,Symbol("Min_Retired_Cap_MW")][y]/dfGen[!,:Cap_Size][y]) for p=1:cur_stage)
		else
			sum((dfGen[!,Symbol("Min_Retired_Cap_MW")][y]) for p=1:cur_stage)
		end
	)

	### Constraints ###

	# Keep track of newly built capacity from previous stages
	@constraint(EP, cCapTrackNew[y in RET_CAP], eNewCap[y] == vCAPTRACK[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cCapTrack[y in RET_CAP,p=1:(cur_stage-1)], vCAPTRACK[y,p] == 0)

	# Keep track of retired capacity from previous stages
	@constraint(EP, cRetCapTrackNew[y in RET_CAP], eRetCap[y] == vRETCAPTRACK[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cRetCapTrack[y in RET_CAP,p=1:(cur_stage-1)], vRETCAPTRACK[y,p] == 0)

	@constraint(EP, cLifetimeRet[y in RET_CAP], eNewCapTrack[y] + eMinRetCapTrack[y]  <= eRetCapTrack[y])

end

function endogenous_retirement_charge!(EP::Model, inputs::Dict, num_stages::Int, cur_stage::Int, stage_lens::Array{Int, 1})

	println("Endogenous Retirement (Charge) Module")

	dfGen = inputs["dfGen"]

	STOR_ASYMMETRIC = inputs["STOR_ASYMMETRIC"] # Set of storage resources with asymmetric (separte) charge/discharge capacity components

	NEW_CAP_CHARGE = inputs["NEW_CAP_CHARGE"] # Set of asymmetric charge/discharge storage resources eligible for new charge capacity
	RET_CAP_CHARGE = inputs["RET_CAP_CHARGE"] # Set of asymmetric charge/discharge storage resources eligible for charge capacity retirements

	### Variables ###

	# Keep track of all new and retired capacity from all stages
	@variable(EP, vCAPTRACKCHARGE[y in RET_CAP_CHARGE,p=1:num_stages] >= 0)
	@variable(EP, vRETCAPTRACKCHARGE[y in RET_CAP_CHARGE,p=1:num_stages] >= 0)

	### Expressions ###

	@expression(EP, eNewCapCharge[y in RET_CAP_CHARGE],
		if y in NEW_CAP_CHARGE
			EP[:vCAPCHARGE][y]
		else
			EP[:vZERO]
		end
	)

	@expression(EP, eRetCapCharge[y in RET_CAP_CHARGE], EP[:vRETCAPCHARGE][y])

	# Construct and add the endogenous retirement constraint expressions
	@expression(EP, eRetCapTrackCharge[y in RET_CAP_CHARGE], sum(EP[:vRETCAPTRACKCHARGE][y,p] for p=1:cur_stage))
	@expression(EP, eNewCapTrackCharge[y in RET_CAP_CHARGE], sum(EP[:vCAPTRACKCHARGE][y,p] for p=1:get_retirement_stage(cur_stage, dfGen[!,:Lifetime][y], stage_lens)))
	@expression(EP, eMinRetCapTrackCharge[y in RET_CAP_CHARGE], sum((dfGen[!,Symbol("Min_Retired_Charge_Cap_MW")][y]) for p=1:cur_stage))

	### Constratints ###

	# Keep track of newly built capacity from previous stages
	@constraint(EP, cCapTrackChargeNew[y in RET_CAP_CHARGE], eNewCapCharge[y] == vCAPTRACKCHARGE[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cCapTrackCharge[y in RET_CAP_CHARGE,p=1:(cur_stage-1)], vCAPTRACKCHARGE[y,p] == 0)

	# Keep track of retired capacity from previous stages
	@constraint(EP, cRetCapTrackChargeNew[y in RET_CAP_CHARGE], eRetCapCharge[y] == vRETCAPTRACKCHARGE[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cRetCapTrackCharge[y in RET_CAP_CHARGE,p=1:(cur_stage-1)], vRETCAPTRACKCHARGE[y,p] == 0)

	@constraint(EP, cLifetimeRetCharge[y in RET_CAP_CHARGE], eNewCapTrackCharge[y] + eMinRetCapTrackCharge[y]  <= eRetCapTrackCharge[y])

end

function endogenous_retirement_energy!(EP::Model, inputs::Dict, num_stages::Int, cur_stage::Int, stage_lens::Array{Int, 1})

	println("Endogenous Retirement (Energy) Module")

	dfGen = inputs["dfGen"]

	STOR_ALL = inputs["STOR_ALL"] # Set of all storage resources
	NEW_CAP_ENERGY = inputs["NEW_CAP_ENERGY"] # Set of all storage resources eligible for new energy capacity
	RET_CAP_ENERGY = inputs["RET_CAP_ENERGY"] # Set of all storage resources eligible for energy capacity retirements

	### Variables ###

	# Keep track of all new and retired capacity from all stages
	@variable(EP, vCAPTRACKENERGY[y in RET_CAP_ENERGY,p=1:num_stages] >= 0)
	@variable(EP, vRETCAPTRACKENERGY[y in RET_CAP_ENERGY,p=1:num_stages] >= 0)

	### Expressions ###

	@expression(EP, eNewCapEnergy[y in RET_CAP_ENERGY],
		if y in NEW_CAP_ENERGY
			EP[:vCAPENERGY][y]
		else
			EP[:vZERO]
		end
	)

	@expression(EP, eRetCapEnergy[y in RET_CAP_ENERGY], EP[:vRETCAPENERGY][y])

	# Construct and add the endogenous retirement constraint expressions
	@expression(EP, eRetCapTrackEnergy[y in RET_CAP_ENERGY], sum(EP[:vRETCAPTRACKENERGY][y,p] for p=1:cur_stage))
	@expression(EP, eNewCapTrackEnergy[y in RET_CAP_ENERGY], sum(EP[:vCAPTRACKENERGY][y,p] for p=1:get_retirement_stage(cur_stage, dfGen[!,:Lifetime][y], stage_lens)))
	@expression(EP, eMinRetCapTrackEnergy[y in RET_CAP_ENERGY], sum((dfGen[!,Symbol("Min_Retired_Energy_Cap_MW")][y]) for p=1:cur_stage))

	### Constratints ###

	# Keep track of newly built capacity from previous stages
	@constraint(EP, cCapTrackEnergyNew[y in RET_CAP_ENERGY], eNewCapEnergy[y] == vCAPTRACKENERGY[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cCapTrackEnergy[y in RET_CAP_ENERGY,p=1:(cur_stage-1)], vCAPTRACKENERGY[y,p] == 0)

	# Keep track of retired capacity from previous stages
	@constraint(EP, cRetCapTrackEnergyNew[y in RET_CAP_ENERGY], eRetCapEnergy[y] == vRETCAPTRACKENERGY[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cRetCapTrackEnergy[y in RET_CAP_ENERGY,p=1:(cur_stage-1)], vRETCAPTRACKENERGY[y,p] == 0)

	@constraint(EP, cLifetimeRetEnergy[y in RET_CAP_ENERGY], eNewCapTrackEnergy[y] + eMinRetCapTrackEnergy[y]  <= eRetCapTrackEnergy[y])
end

function endogenous_retirement_vre_stor_dc!(EP::Model, inputs::Dict, num_stages::Int, cur_stage::Int, stage_lens::Array{Int, 1})

	println("Endogenous Retirement (VRE-Storage DC) Module")
	
	dfGen = inputs["dfGen"]

	NEW_CAP_DC = inputs["NEW_CAP_DC"] # Set of all resources eligible for new capacity
	RET_CAP_DC = inputs["RET_CAP_DC"] # Set of all resources eligible for capacity retirements

	by_rid(rid, sym) = by_rid_df(rid, sym, inputs["dfVRE_STOR"])

	### Variables ###

	# Keep track of all new and retired capacity from all stages
	@variable(EP, vCAPTRACKDC[y in RET_CAP_DC,p=1:num_stages] >= 0 )
	@variable(EP, vRETCAPTRACKDC[y in RET_CAP_DC,p=1:num_stages] >= 0 )

	### Expressions ###

	@expression(EP, eNewCapDC[y in RET_CAP_DC],
		if y in NEW_CAP_DC
			EP[:vDCCAP][y]
		else
			EP[:vZERO]
		end
	)

	@expression(EP, eRetCapDC[y in RET_CAP_DC], EP[:vRETDCCAP][y])

	# Construct and add the endogenous retirement constraint expressions
	@expression(EP, eRetCapTrackDC[y in RET_CAP_DC], sum(EP[:vRETCAPTRACKDC][y,p] for p=1:cur_stage))
	@expression(EP, eNewCapTrackDC[y in RET_CAP_DC], sum(EP[:vCAPTRACKDC][y,p] for p=1:get_retirement_stage(cur_stage, dfGen[!,:Lifetime][y], stage_lens)))
	@expression(EP, eMinRetCapTrackDC[y in RET_CAP_DC], sum((by_rid(y,Symbol("Min_Retired_Cap_Inverter_MW"))) for p=1:cur_stage))

	### Constraints ###

	# Keep track of newly built capacity from previous stages
	@constraint(EP, cCapTrackNewDC[y in RET_CAP_DC], eNewCapDC[y] == vCAPTRACKDC[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cCapTrackDC[y in RET_CAP_DC,p=1:(cur_stage-1)], vCAPTRACKDC[y,p] == 0)

	# Keep track of retired capacity from previous stages
	@constraint(EP, cRetCapTrackNewDC[y in RET_CAP_DC], eRetCapDC[y] == vRETCAPTRACKDC[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cRetCapTrackDC[y in RET_CAP_DC,p=1:(cur_stage-1)], vRETCAPTRACKDC[y,p] == 0)

	@constraint(EP, cLifetimeRetDC[y in RET_CAP_DC], eNewCapTrackDC[y] + eMinRetCapTrackDC[y]  <= eRetCapTrackDC[y])
end

function endogenous_retirement_vre_stor_solar!(EP::Model, inputs::Dict, num_stages::Int, cur_stage::Int, stage_lens::Array{Int, 1})

	println("Endogenous Retirement (VRE-Storage Solar) Module")
	
	dfGen = inputs["dfGen"]

	NEW_CAP_SOLAR = inputs["NEW_CAP_SOLAR"] # Set of all resources eligible for new capacity
	RET_CAP_SOLAR = inputs["RET_CAP_SOLAR"] # Set of all resources eligible for capacity retirements

	by_rid(rid, sym) = by_rid_df(rid, sym, inputs["dfVRE_STOR"])

	### Variables ###

	# Keep track of all new and retired capacity from all stages
	@variable(EP, vCAPTRACKSOLAR[y in RET_CAP_SOLAR,p=1:num_stages] >= 0 )
	@variable(EP, vRETCAPTRACKSOLAR[y in RET_CAP_SOLAR,p=1:num_stages] >= 0 )

	### Expressions ###

	@expression(EP, eNewCapSolar[y in RET_CAP_SOLAR],
		if y in NEW_CAP_SOLAR
			EP[:vSOLARCAP][y]
		else
			EP[:vZERO]
		end
	)

	@expression(EP, eRetCapSolar[y in RET_CAP_SOLAR], EP[:vRETSOLARCAP][y])

	# Construct and add the endogenous retirement constraint expressions
	@expression(EP, eRetCapTrackSolar[y in RET_CAP_SOLAR], sum(EP[:vRETCAPTRACKSOLAR][y,p] for p=1:cur_stage))
	@expression(EP, eNewCapTrackSolar[y in RET_CAP_SOLAR], sum(EP[:vCAPTRACKSOLAR][y,p] for p=1:get_retirement_stage(cur_stage, dfGen[!,:Lifetime][y], stage_lens)))
	@expression(EP, eMinRetCapTrackSolar[y in RET_CAP_SOLAR], sum((by_rid(y,Symbol("Min_Retired_Cap_Solar_MW"))) for p=1:cur_stage))

	### Constraints ###

	# Keep track of newly built capacity from previous stages
	@constraint(EP, cCapTrackNewSolar[y in RET_CAP_SOLAR], eNewCapSolar[y] == vCAPTRACKSOLAR[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cCapTrackSolar[y in RET_CAP_SOLAR,p=1:(cur_stage-1)], vCAPTRACKSOLAR[y,p] == 0)

	# Keep track of retired capacity from previous stages
	@constraint(EP, cRetCapTrackNewSolar[y in RET_CAP_SOLAR], eRetCapSolar[y] == vRETCAPTRACKSOLAR[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cRetCapTrackSolar[y in RET_CAP_SOLAR,p=1:(cur_stage-1)], vRETCAPTRACKSOLAR[y,p] == 0)

	@constraint(EP, cLifetimeRetSolar[y in RET_CAP_SOLAR], eNewCapTrackSolar[y] + eMinRetCapTrackSolar[y]  <= eRetCapTrackSolar[y])
end

function endogenous_retirement_vre_stor_wind!(EP::Model, inputs::Dict, num_stages::Int, cur_stage::Int, stage_lens::Array{Int, 1})

	println("Endogenous Retirement (VRE-Storage Wind) Module")
	
	dfGen = inputs["dfGen"]

	NEW_CAP_WIND = inputs["NEW_CAP_WIND"] # Set of all resources eligible for new capacity
	RET_CAP_WIND = inputs["RET_CAP_WIND"] # Set of all resources eligible for capacity retirements

	by_rid(rid, sym) = by_rid_df(rid, sym, inputs["dfVRE_STOR"])

	### Variables ###

	# Keep track of all new and retired capacity from all stages
	@variable(EP, vCAPTRACKWIND[y in RET_CAP_WIND,p=1:num_stages] >= 0 )
	@variable(EP, vRETCAPTRACKWIND[y in RET_CAP_WIND,p=1:num_stages] >= 0 )

	### Expressions ###

	@expression(EP, eNewCapWind[y in RET_CAP_WIND],
		if y in NEW_CAP_WIND
			EP[:vWINDCAP][y]
		else
			EP[:vZERO]
		end
	)

	@expression(EP, eRetCapWind[y in RET_CAP_WIND], EP[:vRETWINDCAP][y])

	# Construct and add the endogenous retirement constraint expressions
	@expression(EP, eRetCapTrackWind[y in RET_CAP_WIND], sum(EP[:vRETCAPTRACKWIND][y,p] for p=1:cur_stage))
	@expression(EP, eNewCapTrackWind[y in RET_CAP_WIND], sum(EP[:vCAPTRACKWIND][y,p] for p=1:get_retirement_stage(cur_stage, dfGen[!,:Lifetime][y], stage_lens)))
	@expression(EP, eMinRetCapTrackWind[y in RET_CAP_WIND], sum((by_rid(y,Symbol("Min_Retired_Cap_Wind_MW"))) for p=1:cur_stage))

	### Constraints ###

	# Keep track of newly built capacity from previous stages
	@constraint(EP, cCapTrackNewWind[y in RET_CAP_WIND], eNewCapWind[y] == vCAPTRACKWIND[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cCapTrackWind[y in RET_CAP_WIND,p=1:(cur_stage-1)], vCAPTRACKWIND[y,p] == 0)

	# Keep track of retired capacity from previous stages
	@constraint(EP, cRetCapTrackNewWind[y in RET_CAP_WIND], eRetCapWind[y] == vRETCAPTRACKWIND[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cRetCapTrackWind[y in RET_CAP_WIND,p=1:(cur_stage-1)], vRETCAPTRACKWIND[y,p] == 0)

	@constraint(EP, cLifetimeRetWind[y in RET_CAP_WIND], eNewCapTrackWind[y] + eMinRetCapTrackWind[y] <= eRetCapTrackWind[y])
end

function endogenous_retirement_vre_stor_stor!(EP::Model, inputs::Dict, num_stages::Int, cur_stage::Int, stage_lens::Array{Int, 1})

	println("Endogenous Retirement (VRE-Storage Storage) Module")
	
	dfGen = inputs["dfGen"]

	NEW_CAP_STOR = inputs["NEW_CAP_STOR"] # Set of all resources eligible for new capacity
	RET_CAP_STOR = inputs["RET_CAP_STOR"] # Set of all resources eligible for capacity retirements

	### Variables ###

	# Keep track of all new and retired capacity from all stages
	@variable(EP, vCAPTRACKENERGY_VS[y in RET_CAP_STOR,p=1:num_stages] >= 0)
	@variable(EP, vRETCAPTRACKENERGY_VS[y in RET_CAP_STOR,p=1:num_stages] >= 0)

	### Expressions ###

	@expression(EP, eNewCapEnergy_VS[y in RET_CAP_STOR],
		if y in NEW_CAP_STOR
			EP[:vCAPENERGY_VS][y]
		else
			EP[:vZERO]
		end
	)

	@expression(EP, eRetCapEnergy_VS[y in RET_CAP_STOR], EP[:vRETCAPENERGY_VS][y])

	# Construct and add the endogenous retirement constraint expressions
	@expression(EP, eRetCapTrackEnergy_VS[y in RET_CAP_STOR], sum(EP[:vRETCAPTRACKENERGY_VS][y,p] for p=1:cur_stage))
	@expression(EP, eNewCapTrackEnergy_VS[y in RET_CAP_STOR], sum(EP[:vCAPTRACKENERGY_VS][y,p] for p=1:get_retirement_stage(cur_stage, dfGen[!,:Lifetime][y], stage_lens)))
	@expression(EP, eMinRetCapTrackEnergy_VS[y in RET_CAP_STOR], sum((dfGen[!,Symbol("Min_Retired_Energy_Cap_MW")][y]) for p=1:cur_stage))

	### Constratints ###

	# Keep track of newly built capacity from previous stages
	@constraint(EP, cCapTrackEnergyNew_VS[y in RET_CAP_STOR], eNewCapEnergy_VS[y] == vCAPTRACKENERGY_VS[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cCapTrackEnergy_VS[y in RET_CAP_STOR,p=1:(cur_stage-1)], vCAPTRACKENERGY_VS[y,p] == 0)

	# Keep track of retired capacity from previous stages
	@constraint(EP, cRetCapTrackEnergyNew_VS[y in RET_CAP_STOR], eRetCapEnergy_VS[y] == vRETCAPTRACKENERGY_VS[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cRetCapTrackEnergy_VS[y in RET_CAP_STOR,p=1:(cur_stage-1)], vRETCAPTRACKENERGY_VS[y,p] == 0)

	@constraint(EP, cLifetimeRetEnergy_VS[y in RET_CAP_STOR], eNewCapTrackEnergy_VS[y] + eMinRetCapTrackEnergy_VS[y] <= eRetCapTrackEnergy_VS[y])
end

function endogenous_retirement_vre_stor_discharge_dc!(EP::Model, inputs::Dict, num_stages::Int, cur_stage::Int, stage_lens::Array{Int, 1})

	println("Endogenous Retirement (VRE-Storage Discharge DC) Module")
	
	dfGen = inputs["dfGen"]

	NEW_CAP_DISCHARGE_DC = inputs["NEW_CAP_DISCHARGE_DC"] # Set of all resources eligible for new capacity
	RET_CAP_DISCHARGE_DC = inputs["RET_CAP_DISCHARGE_DC"] # Set of all resources eligible for capacity retirements

	by_rid(rid, sym) = by_rid_df(rid, sym, inputs["dfVRE_STOR"])

	### Variables ###

	# Keep track of all new and retired capacity from all stages
	@variable(EP, vCAPTRACKDISCHARGEDC[y in RET_CAP_DISCHARGE_DC,p=1:num_stages] >= 0 )
	@variable(EP, vRETCAPTRACKDISCHARGEDC[y in RET_CAP_DISCHARGE_DC,p=1:num_stages] >= 0 )

	### Expressions ###

	@expression(EP, eNewCapDischargeDC[y in RET_CAP_DISCHARGE_DC],
		if y in NEW_CAP_DISCHARGE_DC
			EP[:vCAPDISCHARGE_DC][y]
		else
			EP[:vZERO]
		end
	)

	@expression(EP, eRetCapDischargeDC[y in RET_CAP_DISCHARGE_DC], EP[:vRETCAPDISCHARGE_DC][y])

	# Construct and add the endogenous retirement constraint expressions
	@expression(EP, eRetCapTrackDischargeDC[y in RET_CAP_DISCHARGE_DC], sum(EP[:vRETCAPTRACKDISCHARGEDC][y,p] for p=1:cur_stage))
	@expression(EP, eNewCapTrackDischargeDC[y in RET_CAP_DISCHARGE_DC], sum(EP[:vCAPTRACKDISCHARGEDC][y,p] for p=1:get_retirement_stage(cur_stage, dfGen[!,:Lifetime][y], stage_lens)))
	@expression(EP, eMinRetCapTrackDischargeDC[y in RET_CAP_DISCHARGE_DC], sum((by_rid(y,Symbol("Min_Retired_Cap_Discharge_DC_MW"))) for p=1:cur_stage))

	### Constraints ###

	# Keep track of newly built capacity from previous stages
	@constraint(EP, cCapTrackNewDischargeDC[y in RET_CAP_DISCHARGE_DC], eNewCapDischargeDC[y] == vCAPTRACKDISCHARGEDC[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cCapTrackDischargeDC[y in RET_CAP_DISCHARGE_DC,p=1:(cur_stage-1)], vCAPTRACKDISCHARGEDC[y,p] == 0)

	# Keep track of retired capacity from previous stages
	@constraint(EP, cRetCapTrackNewDischargeDC[y in RET_CAP_DISCHARGE_DC], eRetCapTrackDischargeDC[y] == vRETCAPTRACKDISCHARGEDC[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cRetCapTrackDischargeDC[y in RET_CAP_DISCHARGE_DC,p=1:(cur_stage-1)], vRETCAPTRACKDISCHARGEDC[y,p] == 0)

	@constraint(EP, cLifetimeRetDischargeDC[y in RET_CAP_DISCHARGE_DC], eNewCapTrackDischargeDC[y] + eMinRetCapTrackDischargeDC[y] <= eRetCapTrackDischargeDC[y])
end

function endogenous_retirement_vre_stor_charge_dc!(EP::Model, inputs::Dict, num_stages::Int, cur_stage::Int, stage_lens::Array{Int, 1})

	println("Endogenous Retirement (VRE-Storage Charge DC) Module")
	
	dfGen = inputs["dfGen"]

	NEW_CAP_CHARGE_DC = inputs["NEW_CAP_CHARGE_DC"] # Set of all resources eligible for new capacity
	RET_CAP_CHARGE_DC = inputs["RET_CAP_CHARGE_DC"] # Set of all resources eligible for capacity retirements

	by_rid(rid, sym) = by_rid_df(rid, sym, inputs["dfVRE_STOR"])

	### Variables ###

	# Keep track of all new and retired capacity from all stages
	@variable(EP, vCAPTRACKCHARGEDC[y in RET_CAP_CHARGE_DC,p=1:num_stages] >= 0 )
	@variable(EP, vRETCAPTRACKCHARGEDC[y in RET_CAP_CHARGE_DC,p=1:num_stages] >= 0 )

	### Expressions ###

	@expression(EP, eNewCapChargeDC[y in RET_CAP_CHARGE_DC],
		if y in NEW_CAP_CHARGE_DC
			EP[:vCAPCHARGE_DC][y]
		else
			EP[:vZERO]
		end
	)

	@expression(EP, eRetCapChargeDC[y in RET_CAP_CHARGE_DC], EP[:vRETCAPCHARGE_DC][y])

	# Construct and add the endogenous retirement constraint expressions
	@expression(EP, eRetCapTrackChargeDC[y in RET_CAP_CHARGE_DC], sum(EP[:vRETCAPTRACKCHARGEDC][y,p] for p=1:cur_stage))
	@expression(EP, eNewCapTrackChargeDC[y in RET_CAP_CHARGE_DC], sum(EP[:vCAPTRACKCHARGEDC][y,p] for p=1:get_retirement_stage(cur_stage, dfGen[!,:Lifetime][y], stage_lens)))
	@expression(EP, eMinRetCapTrackChargeDC[y in RET_CAP_CHARGE_DC], sum((by_rid(y,Symbol("Min_Retired_Cap_Charge_DC_MW"))) for p=1:cur_stage))

	### Constraints ###

	# Keep track of newly built capacity from previous stages
	@constraint(EP, cCapTrackNewChargeDC[y in RET_CAP_CHARGE_DC], eNewCapChargeDC[y] == vCAPTRACKCHARGEDC[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cCapTrackChargeDC[y in RET_CAP_CHARGE_DC,p=1:(cur_stage-1)], vCAPTRACKCHARGEDC[y,p] == 0)

	# Keep track of retired capacity from previous stages
	@constraint(EP, cRetCapTrackNewChargeDC[y in RET_CAP_CHARGE_DC], eRetCapTrackChargeDC[y] == vRETCAPTRACKCHARGEDC[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cRetCapTrackChargeDC[y in RET_CAP_CHARGE_DC,p=1:(cur_stage-1)], vRETCAPTRACKCHARGEDC[y,p] == 0)

	@constraint(EP, cLifetimeRetChargeDC[y in RET_CAP_CHARGE_DC], eNewCapTrackChargeDC[y] + eMinRetCapTrackChargeDC[y] <= eRetCapTrackChargeDC[y])
end

function endogenous_retirement_vre_stor_discharge_ac!(EP::Model, inputs::Dict, num_stages::Int, cur_stage::Int, stage_lens::Array{Int, 1})

	println("Endogenous Retirement (VRE-Storage Discharge AC) Module")
	
	dfGen = inputs["dfGen"]

	NEW_CAP_DISCHARGE_AC = inputs["NEW_CAP_DISCHARGE_AC"] # Set of all resources eligible for new capacity
	RET_CAP_DISCHARGE_AC = inputs["RET_CAP_DISCHARGE_AC"] # Set of all resources eligible for capacity retirements

	by_rid(rid, sym) = by_rid_df(rid, sym, inputs["dfVRE_STOR"])

	### Variables ###

	# Keep track of all new and retired capacity from all stages
	@variable(EP, vCAPTRACKDISCHARGEAC[y in RET_CAP_DISCHARGE_AC,p=1:num_stages] >= 0 )
	@variable(EP, vRETCAPTRACKDISCHARGEAC[y in RET_CAP_DISCHARGE_AC,p=1:num_stages] >= 0 )

	### Expressions ###

	@expression(EP, eNewCapDischargeAC[y in RET_CAP_DISCHARGE_AC],
		if y in NEW_CAP_DISCHARGE_AC
			EP[:vCAPDISCHARGE_AC][y]
		else
			EP[:vZERO]
		end
	)

	@expression(EP, eRetCapDischargeAC[y in RET_CAP_DISCHARGE_AC], EP[:vRETCAPDISCHARGE_AC][y])

	# Construct and add the endogenous retirement constraint expressions
	@expression(EP, eRetCapTrackDischargeAC[y in RET_CAP_DISCHARGE_AC], sum(EP[:vRETCAPTRACKDISCHARGEAC][y,p] for p=1:cur_stage))
	@expression(EP, eNewCapTrackDischargeAC[y in RET_CAP_DISCHARGE_AC], sum(EP[:vCAPTRACKDISCHARGEAC][y,p] for p=1:get_retirement_stage(cur_stage, dfGen[!,:Lifetime][y], stage_lens)))
	@expression(EP, eMinRetCapTrackDischargeAC[y in RET_CAP_DISCHARGE_AC], sum((by_rid(y,Symbol("Min_Retired_Cap_Discharge_AC_MW"))) for p=1:cur_stage))

	### Constraints ###

	# Keep track of newly built capacity from previous stages
	@constraint(EP, cCapTrackNewDischargeAC[y in RET_CAP_DISCHARGE_AC], eNewCapDischargeAC[y] == vCAPTRACKDISCHARGEAC[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cCapTrackDischargeAC[y in RET_CAP_DISCHARGE_AC,p=1:(cur_stage-1)], vCAPTRACKDISCHARGEAC[y,p] == 0)

	# Keep track of retired capacity from previous stages
	@constraint(EP, cRetCapTrackNewDischargeAC[y in RET_CAP_DISCHARGE_AC], eRetCapTrackDischargeAC[y] == vRETCAPTRACKDISCHARGEAC[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cRetCapTrackDischargeAC[y in RET_CAP_DISCHARGE_AC,p=1:(cur_stage-1)], vRETCAPTRACKDISCHARGEAC[y,p] == 0)

	@constraint(EP, cLifetimeRetDischargeAC[y in RET_CAP_DISCHARGE_AC], eNewCapTrackDischargeAC[y] + eMinRetCapTrackDischargeAC[y]  <= eRetCapTrackDischargeAC[y])
end

function endogenous_retirement_vre_stor_charge_ac!(EP::Model, inputs::Dict, num_stages::Int, cur_stage::Int, stage_lens::Array{Int, 1})

	println("Endogenous Retirement (VRE-Storage Charge AC) Module")
	
	dfGen = inputs["dfGen"]

	NEW_CAP_CHARGE_AC = inputs["NEW_CAP_CHARGE_AC"] # Set of all resources eligible for new capacity
	RET_CAP_CHARGE_AC = inputs["RET_CAP_CHARGE_AC"] # Set of all resources eligible for capacity retirements

	by_rid(rid, sym) = by_rid_df(rid, sym, inputs["dfVRE_STOR"])

	### Variables ###

	# Keep track of all new and retired capacity from all stages
	@variable(EP, vCAPTRACKCHARGEAC[y in RET_CAP_CHARGE_AC,p=1:num_stages] >= 0 )
	@variable(EP, vRETCAPTRACKCHARGEAC[y in RET_CAP_CHARGE_AC,p=1:num_stages] >= 0 )

	### Expressions ###

	@expression(EP, eNewCapChargeAC[y in RET_CAP_CHARGE_AC],
		if y in NEW_CAP_CHARGE_AC
			EP[:vCAPCHARGE_AC][y]
		else
			EP[:vZERO]
		end
	)

	@expression(EP, eRetCapChargeAC[y in RET_CAP_CHARGE_AC], EP[:vRETCAPCHARGE_AC][y])

	# Construct and add the endogenous retirement constraint expressions
	@expression(EP, eRetCapTrackChargeAC[y in RET_CAP_CHARGE_AC], sum(EP[:vRETCAPTRACKCHARGEAC][y,p] for p=1:cur_stage))
	@expression(EP, eNewCapTrackChargeAC[y in RET_CAP_CHARGE_AC], sum(EP[:vCAPTRACKCHARGEAC][y,p] for p=1:get_retirement_stage(cur_stage, dfGen[!,:Lifetime][y], stage_lens)))
	@expression(EP, eMinRetCapTrackChargeAC[y in RET_CAP_CHARGE_AC], sum((by_rid(y,Symbol("Min_Retired_Cap_Charge_AC_MW"))) for p=1:cur_stage))

	### Constraints ###

	# Keep track of newly built capacity from previous stages
	@constraint(EP, cCapTrackNewChargeAC[y in RET_CAP_CHARGE_AC], eNewCapChargeAC[y] == vCAPTRACKCHARGEAC[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cCapTrackChargeAC[y in RET_CAP_CHARGE_AC,p=1:(cur_stage-1)], vCAPTRACKCHARGEAC[y,p] == 0)

	# Keep track of retired capacity from previous stages
	@constraint(EP, cRetCapTrackNewChargeAC[y in RET_CAP_CHARGE_AC], eRetCapTrackChargeAC[y] == vRETCAPTRACKCHARGEAC[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cRetCapTrackChargeAC[y in RET_CAP_CHARGE_AC,p=1:(cur_stage-1)], vRETCAPTRACKCHARGEAC[y,p] == 0)

	@constraint(EP, cLifetimeRetChargeAC[y in RET_CAP_CHARGE_AC], eNewCapTrackChargeAC[y] + eMinRetCapTrackChargeAC[y] <= eRetCapTrackChargeAC[y])
end
