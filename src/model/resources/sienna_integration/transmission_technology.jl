start_region(t::TransmissionTechnology) = get_start_node(t)
end_region(t::TransmissionTechnology) = get_end_node(t)

zone_id(t::RegionTopology) = get_id(t)

start_region(t::AggregateTransportTechnology) = get_start_region(t)
end_region(t::AggregateTransportTechnology) = get_end_region(t)

line_loss(t::TransmissionTechnology) = get_line_loss(t)
voltage(t::TransmissionTechnology) = get_voltage(t)
resistance(t::TransmissionTechnology) = get_resistance(t)
angle_limit(t::TransmissionTechnology) = get_angle_limit(t)

line_reinforcement_cost(t::TransmissionTechnology) = IS.get_proportional_term(get_capital_cost(t))
line_reinforcement_max(t::TransmissionTechnology) = get_max(get_capacity_limits(t))

#TODO: get_wacc, get_capital_recovery_factor, get_line_max_flow_possible_mw