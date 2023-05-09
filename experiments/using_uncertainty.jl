# Sim properties
folder = "data/using_uncertainty/"
iterations = 700
burn_in = 0
no_runs = 100
run_aggregation = [mean]

# include baseline
include("init_duopoly_survey.jl")

# Define experiments
experiments = Dict(
    "using_uncertainty" => Dict(:unc_using_pct => 0.2)
)

# Data Collection
include("data_collection_duopoly.jl")
