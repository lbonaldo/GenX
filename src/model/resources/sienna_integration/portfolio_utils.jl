get_max(x::MinMax) = x.max
get_min(x::MinMax) = x.min
get_in(x::InOut) = x.in
get_out(x::InOut) = x.out

get_parameter_type(t::SupplyTechnology{T}) where T = T
get_parameter_type(t::StorageTechnology{T}) where T = T

function existing_cap_mw(p::Portfolio, t::Union{ResourceTechnology, TransmissionTechnology})
    if IS.has_supplemental_attributes(ExistingCapacity, t)
        gen_names = get_existing_technologies(IS.get_supplemental_attributes(ExistingCapacity, t)[1])
        comp = PSY.get_component.(get_parameter_type(t), Ref(p.base_system), gen_names)
        return sum(PSY.get_rating(t) for t in comp)
    else
        return 0.0
    end
end

function existing_cap_mwh(p::Portfolio, t::StorageTechnology)
    if IS.has_supplemental_attributes(ExistingCapacity, t)
        gen_names = IS.get_existing_technologies(IS.get_supplemental_attributes(ExistingCapacity, t)[1])
        comp = PSY.get_component.(get_parameter_type(t), Ref(p.base_system), gen_names)
        return sum(get_storage_capacity(t) for t in comp)
    else
        return 0.0
    end
end

function set_capacity!(p::Portfolio, capacities::Dict{String, DataFrame})
    inv_schedule = p.investment_schedule
    for (k, v) in capacities
        inv_schedule[k] = v
    end
    return nothing
end

function get_investment_schedule(p::Portfolio)
    return p.investment_schedule
end

