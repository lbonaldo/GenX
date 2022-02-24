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
	write_reserve_margin_revenue(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting the capacity revenue earned by each generator listed in the input file. 
    GenX will print this file only when capacity reserve margin is modeled and the shadow price can be obtained form the solver. 
    Each row corresponds to a generator, and each column starting from the 6th to the second last is the total revenue from each capacity reserve margin constraint. 
    The revenue is calculated as the capacity contribution of each time steps multiplied by the shadow price, and then the sum is taken over all modeled time steps. 
    The last column is the total revenue received from all capacity reserve margin constraints.  
    As a reminder, GenX models the capacity reserve margin (aka capacity market) at the time-dependent level, and each constraint either stands for an overall market or a locality constraint.
"""
function write_reserve_margin_revenue(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	THERM_ALL = inputs["THERM_ALL"]
	VRE = inputs["VRE"]
	HYDRO_RES = inputs["HYDRO_RES"]
	STOR_ALL = inputs["STOR_ALL"]
	FLEX = inputs["FLEX"]
	MUST_RUN = inputs["MUST_RUN"]
	dfResRevenue = DataFrame(Region = dfGen[!, :region], Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone], Cluster = dfGen[!, :cluster], R_ID=dfGen[!, :R_ID], AnnualSum = zeros(G))
	for i in 1:inputs["NCapacityReserveMargin"]
		tempresrev = zeros(G)
		tempresrev[THERM_ALL] = dfGen[THERM_ALL, Symbol("CapRes_$i")] .* (value.(EP[:eTotalCap][THERM_ALL])) * sum(dual.(EP[:cCapacityResMargin][i, :]))
		tempresrev[VRE] = dfGen[VRE, Symbol("CapRes_$i")] .* (value.(EP[:eTotalCap][VRE])) .* (inputs["pP_Max"][VRE, :] * (dual.(EP[:cCapacityResMargin][i, :])))
		tempresrev[MUST_RUN] = dfGen[MUST_RUN, Symbol("CapRes_$i")] .* (value.(EP[:eTotalCap][MUST_RUN])) .* (inputs["pP_Max"][MUST_RUN, :] * (dual.(EP[:cCapacityResMargin][i, :])))
		tempresrev[HYDRO_RES] = dfGen[HYDRO_RES, Symbol("CapRes_$i")] .* (value.(EP[:vP][HYDRO_RES, :]) * (dual.(EP[:cCapacityResMargin][i, :])))
		tempresrev[STOR_ALL] = dfGen[STOR_ALL, Symbol("CapRes_$i")] .* ((value.(EP[:vP][STOR_ALL, :]) - value.(EP[:vCHARGE][STOR_ALL, :]).data) * (dual.(EP[:cCapacityResMargin][i, :])))
		tempresrev[FLEX] = dfGen[FLEX, Symbol("CapRes_$i")] .* ((value.(EP[:vCHARGE_FLEX][FLEX, :]).data - value.(EP[:vP][FLEX, :])) * (dual.(EP[:cCapacityResMargin][i, :])))
		if setup["ParameterScale"] == 1
			tempresrev *= ModelScalingFactor^2
		end
		dfResRevenue.AnnualSum .+= tempresrev
		dfResRevenue = hcat(dfResRevenue, DataFrame([tempresrev], [Symbol("CapRes_$i")]))
	end
	CSV.write(string(path,sep,"ReserveMarginRevenue.csv"), dfResRevenue)
	return dfResRevenue
end
