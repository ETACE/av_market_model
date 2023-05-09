# Sim properties
folder = "data/baseline/"
iterations = 700
burn_in = 0
no_runs = 100
run_aggregation = [mean]

# include baseline
include("init_duopoly_survey.jl")

# Define experiments
experiments = Dict(
    "baseline" => Dict(),
)

# Data Collection
include("data_collection_duopoly.jl")
