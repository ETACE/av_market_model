# Sim properties
folder = "data/no_cons_het/"
iterations = 700
burn_in = 0
no_runs = 100
run_aggregation = [mean]

# include baseline
include("init_duopoly_survey.jl")

# Define experiments
experiments = Dict(
    "no_cons_het" => Dict(:no_consumer_het => true),
)

# Data Collection
include("data_collection_duopoly.jl")
