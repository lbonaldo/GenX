"""
GenX: An Configurable Capacity Expansion Model
Copyright (C) 2021,  Massachusetts Institute of Technology
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
A complete copy of the GNU General Public License v2 (GPLv2) is available
in LICENSE.txt.  Users uncompressing this from an archive may not have
received this license file.  If not, see <http://www.gnu.org/licenses/>.
"""

@doc raw"""
	function transmission_multi_period(EP::Model, inputs::Dict, UCommit::Int, NetworkExpansion::Int, multi_period_settings_d::Dict)

This function establishes decisions, expressions, and constraints related to transmission power flows between model zones and associated transmission losses (if modeled), compatable with multi-period modeling. It includes all of the variables, expressions, and constraints of transmission() with additional constraints and variables introduced for compatibility with multi-period modeling, which are described below.

Total Line Reinforcement Linking Variables and Constraints:

  * The linking variable vTRANSMAX[l] for $l \in \mathcal{L}$ is introduced and replaces occurrences of the parameter pTrans_Max[l] in all expressions and constraints in transmission().
  * The linking constraint cExistingTransCap[l] for $l \in \mathcal{L}$  is introduced, which is used to link end transmission capacity (after any line reinforcement) from period $p$ to start transmission capacity in period $p+1$. When $p=1$, the constraint sets cExistingTransCap[l] = pTransMax[l].

Scaling Down the Objective Function Contribution:

  * The contribution of eTotalCNetworkExp ($\sum_{l \in \mathcal{L}}\left(\pi^{TCAP}_{l} \times \bigtriangleup\varphi^{max}_{l}\right)$) is scaled down the factor $\sum_{p=1}^{\mathcal{P}} \frac{1}{(1+WACC)^{p-1}}$, where $\mathcal{P}$ is the length of each period and $WACC$ is the weighted average cost of capital, before it is added to the objective function (these costs will be scaled back to their correct value by the method initialize\_cost\_to\_go()).

inputs:

  * EP – JuMP model.
  * inputs – Dictionary object containing model inputs dictionary generated by load\_inputs().
  * UCommit – Integer flag representing unit commitment status, set in genx\_settings.yml.
  * NetworkExpansion – Integer flag representing whether network expansion is active, set in genx\_settings.yml.
  * multi\_period\_settings - Dictionary containing settings dictionary configured in the multi-period settings file multi\_period\_settings.yml.

returns: JuMP model with updated variables, expressions, and constraints.

"""
function transmission_multi_period(EP::Model, inputs::Dict, UCommit::Int, NetworkExpansion::Int, multi_period_settings_d::Dict)

	println("Transmission Module")

	dfGen = inputs["dfGen"]

	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones
	L = inputs["L"]     # Number of transmission lines
	SEG = inputs["SEG"] # Number of load curtailment segments

	## sets and indices for transmission losses and expansion
	TRANS_LOSS_SEGS = inputs["TRANS_LOSS_SEGS"] # Number of segments used in piecewise linear approximations quadratic loss functions - can only take values of TRANS_LOSS_SEGS =1, 2
	LOSS_LINES = inputs["LOSS_LINES"] # Lines for which loss coefficients apply (are non-zero);
	if NetworkExpansion == 1
		# Network lines and zones that are expandable have non-negative maximum reinforcement inputs
		EXPANSION_LINES = inputs["EXPANSION_LINES"]
		NO_EXPANSION_LINES = inputs["NO_EXPANSION_LINES"]
	end

	### Variables ###

	@variable(EP, vTRANSMAX[l=1:L] >= 0)

	# Power flow on each transmission line "l" at hour "t"
	@variable(EP, vFLOW[l=1:L,t=1:T]);

	if NetworkExpansion == 1
		# Transmission network capacity reinforcements per line
		@variable(EP, vNEW_TRANS_CAP[l in EXPANSION_LINES] >= 0)
	end

  	if (TRANS_LOSS_SEGS==1)  #loss is a constant times absolute value of power flow
		# Positive and negative flow variables
		@variable(EP, vTAUX_NEG[l in LOSS_LINES,t=1:T] >= 0)
		@variable(EP, vTAUX_POS[l in LOSS_LINES,t=1:T] >= 0)

		if UCommit == 1
			# Single binary variable to ensure positive or negative flows only
			@variable(EP, vTAUX_POS_ON[l in LOSS_LINES,t=1:T],Bin)
			# Continuous variable representing product of binary variable (vTAUX_POS_ON) and avail transmission capacity
			@variable(EP, vPROD_TRANSCAP_ON[l in LOSS_LINES,t=1:T]>=0)
		end
	else # TRANS_LOSS_SEGS>1
		# Auxiliary variables for linear piecewise interpolation of quadratic losses
		@variable(EP, vTAUX_NEG[l in LOSS_LINES, s=0:TRANS_LOSS_SEGS, t=1:T] >= 0)
		@variable(EP, vTAUX_POS[l in LOSS_LINES, s=0:TRANS_LOSS_SEGS, t=1:T] >= 0)
		if UCommit == 1
			# Binary auxilary variables for each segment >1 to ensure segments fill in order
			@variable(EP, vTAUX_POS_ON[l in LOSS_LINES, s=1:TRANS_LOSS_SEGS, t=1:T], Bin)
			@variable(EP, vTAUX_NEG_ON[l in LOSS_LINES, s=1:TRANS_LOSS_SEGS, t=1:T], Bin)
		end
    	end

	# Transmission losses on each transmission line "l" at hour "t"
	@variable(EP, vTLOSS[l in LOSS_LINES,t=1:T] >= 0)

	### Expressions ###

	## Transmission power flow and loss related expressions:
	# Total availabile maximum transmission capacity is the sum of existing maximum transmission capacity plus new transmission capacity
	if NetworkExpansion == 1
		@expression(EP, eAvail_Trans_Cap[l=1:L],
			if l in EXPANSION_LINES
				vTRANSMAX[l] + vNEW_TRANS_CAP[l]
			else
				vTRANSMAX[l] + EP[:vZERO]
			end
		)
	else
		@expression(EP, eAvail_Trans_Cap[l=1:L], vTRANSMAX[l] + EP[:vZERO])
	end

	# Net power flow outgoing from zone "z" at hour "t" in MW
    	@expression(EP, eNet_Export_Flows[z=1:Z,t=1:T], sum(inputs["pNet_Map"][l,z] * vFLOW[l,t] for l=1:L))

	# Losses from power flows into or out of zone "z" in MW
    	@expression(EP, eLosses_By_Zone[z=1:Z,t=1:T], sum(abs(inputs["pNet_Map"][l,z]) * vTLOSS[l,t] for l in LOSS_LINES))

	## Objective Function Expressions ##

	if NetworkExpansion == 1

		@expression(EP, eTotalCNetworkExp, sum(vNEW_TRANS_CAP[l]*inputs["pC_Line_Reinforcement"][l] for l in EXPANSION_LINES))

		wacc = multi_period_settings_d["WACC"]
		### period_len = multi_period_settings_d["PeriodLength"] # Pre-VSL
		cur_period = multi_period_settings_d["CurPeriod"]
		period_len = multi_period_settings_d["PeriodLengths"][cur_period]

		# DDP - OPEX multiplier to count multiple years between two model time periods
		OPEXMULT = sum([1/(1+wacc)^(i-1) for i in range(1,stop=period_len)])
		# We divide by OPEXMULT since we are going to multiply the entire objective function by this term later,
		# and we have already accounted for multiple years between time periods for fixed costs.
		EP[:eObj] += (1/OPEXMULT)*eTotalCNetworkExp

    end

	## End Objective Function Expressions ##

	## Power Balance Expressions ##

	@expression(EP, ePowerBalanceNetExportFlows[t=1:T, z=1:Z],
		-eNet_Export_Flows[z,t])
	@expression(EP, ePowerBalanceLossesByZone[t=1:T, z=1:Z],
		-(1/2)*eLosses_By_Zone[z,t])

	EP[:ePowerBalance] += ePowerBalanceLossesByZone
	EP[:ePowerBalance] += ePowerBalanceNetExportFlows

	### Constraints ###

	# Linking constraint for existing transmission capacity
	@constraint(EP, cExistingTransCap[l=1:L], vTRANSMAX[l] == inputs["pTrans_Max"][l])

  	## Power flow and transmission (between zone) loss related constraints

	# Maximum power flows, power flow on each transmission line cannot exceed maximum capacity of the line at any hour "t"
	# Allow expansion of transmission capacity for lines eligible for reinforcement
	@constraints(EP, begin
		cMaxFlow_out[l=1:L, t=1:T], vFLOW[l,t] <= eAvail_Trans_Cap[l]
		cMaxFlow_in[l=1:L, t=1:T], vFLOW[l,t] >= -eAvail_Trans_Cap[l]
	end)

	# If network expansion is used:
	if NetworkExpansion == 1
		# Transmission network related power flow and capacity constraints
		# Constrain maximum line capacity reinforcement for lines eligible for expansion
		@constraint(EP, cMaxLineReinforcement[l in EXPANSION_LINES], eAvail_Trans_Cap[l] <= inputs["pTrans_Max_Possible"][l])
	end
	#END network expansion contraints

	# Transmission loss related constraints - linear losses as a function of absolute value
	if TRANS_LOSS_SEGS == 1

		@constraints(EP, begin
			# Losses are alpha times absolute values
			cTLoss[l in LOSS_LINES, t=1:T], vTLOSS[l,t] == inputs["pPercent_Loss"][l]*(vTAUX_POS[l,t]+vTAUX_NEG[l,t])

			# Power flow is sum of positive and negative components
			cTAuxSum[l in LOSS_LINES, t=1:T], vTAUX_POS[l,t]-vTAUX_NEG[l,t] == vFLOW[l,t]

			# Sum of auxiliary flow variables in either direction cannot exceed maximum line flow capacity
			cTAuxLimit[l in LOSS_LINES, t=1:T], vTAUX_POS[l,t]+vTAUX_NEG[l,t] <= eAvail_Trans_Cap[l]
		end)

		if UCommit == 1
			# Constraints to limit phantom losses that can occur to avoid discrete cycling costs/opportunity costs due to min down
			@constraints(EP, begin
				cTAuxPosUB[l in LOSS_LINES, t=1:T], vTAUX_POS[l,t] <= vPROD_TRANSCAP_ON[l,t]

				# Either negative or positive flows are activated, not both
				cTAuxNegUB[l in LOSS_LINES, t=1:T], vTAUX_NEG[l,t] <= eAvail_Trans_Cap[l]-vPROD_TRANSCAP_ON[l,t]

				# McCormick representation of product of continuous and binary variable
				# (in this case, of: vPROD_TRANSCAP_ON[l,t] = eAvail_Trans_Cap[l] * vTAUX_POS_ON[l,t])
				# McCormick constraint 1
				[l in LOSS_LINES,t=1:T], vPROD_TRANSCAP_ON[l,t] <= inputs["pTrans_Max_Possible"][l]*vTAUX_POS_ON[l,t]

				# McCormick constraint 2
				[l in LOSS_LINES,t=1:T], vPROD_TRANSCAP_ON[l,t] <= eAvail_Trans_Cap[l]

				# McCormick constraint 3
				[l in LOSS_LINES,t=1:T], vPROD_TRANSCAP_ON[l,t] >= eAvail_Trans_Cap[l]-(1-vTAUX_POS_ON[l,t])*inputs["pTrans_Max_Possible"][l]
			end)
		end

	end # End if(TRANS_LOSS_SEGS == 1) block

	# When number of segments is greater than 1
	if (TRANS_LOSS_SEGS > 1)
		## between zone transmission loss constraints
		# Losses are expressed as a piecewise approximation of a quadratic function of power flows across each line
		# Eq 1: Total losses are function of loss coefficient times the sum of auxilary segment variables across all segments of piecewise approximation
		# (Includes both positive domain and negative domain segments)
		@constraint(EP, cTLoss[l in LOSS_LINES, t=1:T], vTLOSS[l,t] ==
							(inputs["pTrans_Loss_Coef"][l]*sum((2*s-1)*(inputs["pTrans_Max_Possible"][l]/TRANS_LOSS_SEGS)*vTAUX_POS[l,s,t] for s=1:TRANS_LOSS_SEGS)) +
							(inputs["pTrans_Loss_Coef"][l]*sum((2*s-1)*(inputs["pTrans_Max_Possible"][l]/TRANS_LOSS_SEGS)*vTAUX_NEG[l,s,t] for s=1:TRANS_LOSS_SEGS)) )
		# Eq 2: Sum of auxilary segment variables (s >= 1) minus the "zero" segment (which allows values to go negative)
		# from both positive and negative domains must total the actual power flow across the line
		@constraints(EP, begin
			cTAuxSumPos[l in LOSS_LINES, t=1:T], sum(vTAUX_POS[l,s,t] for s=1:TRANS_LOSS_SEGS)-vTAUX_POS[l,0,t]  == vFLOW[l,t]
			cTAuxSumNeg[l in LOSS_LINES, t=1:T], sum(vTAUX_NEG[l,s,t] for s=1:TRANS_LOSS_SEGS) - vTAUX_NEG[l,0,t]  == -vFLOW[l,t]
		end)
		if UCommit == 0 || UCommit == 2
			# Eq 3: Each auxilary segment variables (s >= 1) must be less than the maximum power flow in the zone / number of segments
			@constraints(EP, begin
				cTAuxMaxPos[l in LOSS_LINES, s=1:TRANS_LOSS_SEGS, t=1:T], vTAUX_POS[l,s,t] <= (inputs["pTrans_Max_Possible"][l]/TRANS_LOSS_SEGS)
				cTAuxMaxNeg[l in LOSS_LINES, s=1:TRANS_LOSS_SEGS, t=1:T], vTAUX_NEG[l,s,t] <= (inputs["pTrans_Max_Possible"][l]/TRANS_LOSS_SEGS)
			end)
		else # Constraints that can be ommitted if problem is convex (i.e. if not using MILP unit commitment constraints)
			# Eqs 3-4: Ensure that auxilary segment variables do not exceed maximum value per segment and that they
			# "fill" in order: i.e. one segment cannot be non-zero unless prior segment is at it's maximum value
			# (These constraints are necessary to prevents phantom losses in MILP problems)
			@constraints(EP, begin
				cTAuxOrderPos1[l in LOSS_LINES, s=1:TRANS_LOSS_SEGS, t=1:T], vTAUX_POS[l,s,t] <=  (inputs["pTrans_Max_Possible"][l]/TRANS_LOSS_SEGS)*vTAUX_POS_ON[l,s,t]
				cTAuxOrderNeg1[l in LOSS_LINES, s=1:TRANS_LOSS_SEGS, t=1:T], vTAUX_NEG[l,s,t] <=  (inputs["pTrans_Max_Possible"][l]/TRANS_LOSS_SEGS)*vTAUX_NEG_ON[l,s,t]
				cTAuxOrderPos2[l in LOSS_LINES, s=1:(TRANS_LOSS_SEGS-1), t=1:T], vTAUX_POS[l,s,t] >=  (inputs["pTrans_Max_Possible"][l]/TRANS_LOSS_SEGS)*vTAUX_POS_ON[l,s+1,t]
				cTAuxOrderNeg2[l in LOSS_LINES, s=1:(TRANS_LOSS_SEGS-1), t=1:T], vTAUX_NEG[l,s,t] >=  (inputs["pTrans_Max_Possible"][l]/TRANS_LOSS_SEGS)*vTAUX_NEG_ON[l,s+1,t]
			end)

			# Eq 5: Binary constraints to deal with absolute value of vFLOW.
			@constraints(EP, begin
				# If flow is positive, vTAUX_POS segment 0 must be zero; If flow is negative, vTAUX_POS segment 0 must be positive
				# (and takes on value of the full negative flow), forcing all vTAUX_POS other segments (s>=1) to be zero
				cTAuxSegmentZeroPos[l in LOSS_LINES, t=1:T], vTAUX_POS[l,0,t] <= inputs["pTrans_Max_Possible"][l]*(1-vTAUX_POS_ON[l,1,t])

				# If flow is negative, vTAUX_NEG segment 0 must be zero; If flow is positive, vTAUX_NEG segment 0 must be positive
				# (and takes on value of the full positive flow), forcing all other vTAUX_NEG segments (s>=1) to be zero
				cTAuxSegmentZeroNeg[l in LOSS_LINES, t=1:T], vTAUX_NEG[l,0,t] <= inputs["pTrans_Max_Possible"][l]*(1-vTAUX_NEG_ON[l,1,t])
			end)
		end
	end # End if(TRANS_LOSS_SEGS > 0) block

	return EP
end
