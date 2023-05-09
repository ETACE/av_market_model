# Sim properties
folder = "data/no_uncertainty/"
iterations = 700
burn_in = 0
no_runs = 100
run_aggregation = [mean]

# include baseline
include("init_duopoly_survey.jl")

# Define experiments
experiments = Dict(
    "no_uncertainty" => Dict(:innovation_std_safety => 0.0,
    :innovation_std_performance => 0.0,
    :prob_of_accident_noise => 0.0,
    :innovation_prob_safety => 1.0,
    :innovation_prob_performance => 1.0,
    :prob_read_newspaper => 1.0,
    :perf_update_own_noise => 0.0,
    :max_variance_performance => 0.0,
    :max_variance_prob_of_acc => 0.0,
    :perf_update_own_rate => 1.0)
)

# Data Collection
include("data_collection_duopoly.jl")
