function configure_cplex(solver_settings_path::String)

    solver_settings = YAML.load(open(solver_settings_path))

    # Set solve to use CPLEX for MIP or LP problems
    # Optional setup parameters ############################################
    MyFeasibilityTol = 1e-6 # Constraint (primal) feasibility tolerances. See https://www.ibm.com/support/knowledgecenter/en/SSSA5P_12.5.1/ilog.odms.cplex.help/CPLEX/Parameters/topics/EpRHS.html
        if(haskey(solver_settings, "Feasib_Tol")) MyFeasibilityTol = solver_settings["Feasib_Tol"] end
    MyOptimalityTol = 1e-6 # Dual feasibility tolerances. See https://www.ibm.com/support/knowledgecenter/en/SSSA5P_12.5.1/ilog.odms.cplex.help/CPLEX/Parameters/topics/EpOpt.html
        if(haskey(solver_settings, "Optimal_Tol")) MyOptimalityTol = solver_settings["Optimal_Tol"] end
    MyPresolve = 1 	# Decides if presolve is applied. See https://www.ibm.com/support/knowledgecenter/en/SSSA5P_12.5.1/ilog.odms.cplex.help/CPLEX/Parameters/topics/PreInd.html
        if(haskey(solver_settings, "Pre_Solve")) MyPresolve = solver_settings["Pre_Solve"] end
    MyAggFill = 10 		# Allowed fill during presolve aggregation. See https://www.ibm.com/support/knowledgecenter/en/SSSA5P_12.5.1/ilog.odms.cplex.help/CPLEX/Parameters/topics/AggFill.html
        if(haskey(solver_settings, "AggFill")) MyAggFill = solver_settings["AggFill"] end
    MyPreDual = 0		# Decides whether presolve should pass the primal or dual linear programming problem to the LP optimization algorithm. See https://www.ibm.com/support/knowledgecenter/en/SSSA5P_12.5.1/ilog.odms.cplex.help/CPLEX/Parameters/topics/PreDual.html
        if(haskey(solver_settings, "PreDual")) MyPreDual = solver_settings["PreDual"] end
    MyTimeLimit = 1e+75	# Limits total time solver. See https://www.ibm.com/support/knowledgecenter/en/SSSA5P_12.5.1/ilog.odms.cplex.help/CPLEX/Parameters/topics/TiLim.html
        if(haskey(solver_settings, "TimeLimit")) MyTimeLimit = solver_settings["TimeLimit"] end
    MyMIPGap = 1e-4		# Relative (p.u. of optimal) mixed integer optimality tolerance for MIP problems (ignored otherwise). See https://www.ibm.com/support/knowledgecenter/en/SSSA5P_12.5.1/ilog.odms.cplex.help/CPLEX/Parameters/topics/EpGap.html
        if(haskey(solver_settings, "MIPGap")) MyMIPGap = solver_settings["MIPGap"] end
    MyCrossover = 0 	# Barrier crossver strategy. See https://www.ibm.com/support/knowledgecenter/hr/SSSA5P_12.8.0/ilog.odms.cplex.help/CPLEX/Parameters/topics/BarCrossAlg.html
        if(haskey(solver_settings, "Crossover")) MyCrossover = solver_settings["Crossover"] end
    MyMethod = 0		# Algorithm used to solve continuous models (including MIP root relaxation). See https://www.ibm.com/support/knowledgecenter/de/SSSA5P_12.7.0/ilog.odms.cplex.help/CPLEX/Parameters/topics/LPMETHOD.html
        if(haskey(solver_settings, "Method")) MyMethod = solver_settings["Method"] end
    MyBarConvTol = 1e-8 	# Barrier convergence tolerance (determines when barrier terminates). See https://www.ibm.com/support/knowledgecenter/en/SSSA5P_12.5.1/ilog.odms.cplex.help/CPLEX/Parameters/topics/BarEpComp.html
        if(haskey(solver_settings, "BarConvTol")) MyBarConvTol = solver_settings["BarConvTol"] end
    MyNumericFocus = 0 	# Numerical precision emphasis. See https://www.ibm.com/support/knowledgecenter/en/SSSA5P_12.5.1/ilog.odms.cplex.help/CPLEX/Parameters/topics/NumericalEmphasis.html
        if(haskey(solver_settings, "NumericFocus")) MyNumericFocus = solver_settings["NumericFocus"] end
    MyBarObjRng = 1e+75 	# Sets the maximum absolute value of the objective function. See https://www.ibm.com/support/knowledgecenter/en/SSSA5P_12.5.1/ilog.odms.cplex.help/CPLEX/Parameters/topics/BarObjRng.html
        if(haskey(solver_settings, "BarObjRng")) MyBarObjRng = solver_settings["BarObjRng"] end
    MySolutionType = 2 	# Solution type for LP or QP. See https://www.ibm.com/support/knowledgecenter/hr/SSSA5P_12.8.0/ilog.odms.cplex.help/CPLEX/Parameters/topics/SolutionType.html
        if(haskey(solver_settings, "SolutionType")) MySolutionType = solver_settings["SolutionType"] end
  ########################################################################
    
    OPTIMIZER = optimizer_with_attributes(CPLEX.Optimizer,
        "CPX_PARAM_EPRHS" => MyFeasibilityTol,
        "CPX_PARAM_EPOPT" => MyOptimalityTol,
        "CPX_PARAM_AGGFILL" => MyAggFill,
        "CPX_PARAM_PREDUAL" => MyPreDual,
        "CPX_PARAM_TILIM" => MyTimeLimit,
        "CPX_PARAM_EPGAP" => MyMIPGap,
        "CPX_PARAM_BARCROSSALG" => MyCrossover,
        "CPX_PARAM_LPMETHOD" => MyMethod,
        "CPX_PARAM_BAREPCOMP" => MyBarConvTol,
        "CPX_PARAM_NUMERICALEMPHASIS" => MyNumericFocus,
        "CPX_PARAM_BAROBJRNG" => MyBarObjRng,
        "CPX_PARAM_SOLUTIONTYPE" => MySolutionType
    
    )
    return OPTIMIZER
end