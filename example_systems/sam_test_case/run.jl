ENV["GENX_PRECOMPILE"] = "false"

using Pkg; Pkg.activate("GenX.jl")
using GenX
using PowerSystemsInvestmentsPortfolios
using Gurobi
# using TimeSeries
# using CSV
# using DataFrames
const PSIP=PowerSystemsInvestmentsPortfolios

# p = PSIP.db_to_portfolio_parser(joinpath(@__DIR__, "RTS_GMLC.db"))


p = PSIP.Portfolio(joinpath(@__DIR__, "portfolio.json"))



