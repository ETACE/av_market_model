using Agents
using Statistics
using Random
using Distributions
using StatsBase
using DataStructures

include("producer.jl")
include("consumer.jl")
include("statistics.jl")


function consumer_scheduler_randomly(model::ABM)
    return shuffle!(model.rng, collect(keys(model.consumers)))
end

function producer_scheduler_randomly(model::ABM)
    return shuffle!(model.rng, collect(keys(model.producers)))
end

function consumers(f, model::ABM)
    for i in consumer_scheduler_randomly(model)
        f(model.agents[i], model)
    end
end

function producers(f, model::ABM)
    for i in producer_scheduler_randomly(model)
        f(model.agents[i], model)
    end
end

# Implements model_step! function from Agents.jl framework.
function model_step!(model)

    model.iteration+=1

    reset(model.statistics, model)

    producers(model) do producer, model
        reset(producer, model)
        innovation_process(producer, model)
    end

    consumers(model) do consumer, model
        act(consumer, model)
    end

    producers(model) do producer, model
        calc_market_shares(producer, model)
        calculate_accident_prob(producer, model)
    end

end
