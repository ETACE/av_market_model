# Sim properties
folder = "data/flat_tech/"
iterations = 700
burn_in = 0
no_runs = 100
run_aggregation = [mean]

# include baseline
include("init_duopoly_survey.jl")

# Define experiments
experiments = Dict(
    "flat_tech" => Dict(:technological_curve => a -> min(1/600*a, 1.0)),
)

# Data Collection
include("data_collection_duopoly.jl")
