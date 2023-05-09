using CSV
using DataFrames

# Number of agents
num_consumers = 10000
num_producers = 2

n_link = 3
alpha = -5
beta = 1

# Baseline properties
baseline_properties = Dict(
:unc_using_pct => 0.0,
:no_consumer_het => false,
:accidents_extension => false,
:accident_prob_hv => 0.05 / 12,
:accident_prob_av_start => 0.1 / 12,
:accident_prob_av_end => 0.01 / 12,
:normative_social_influence => false,
:two_of_three => false,
:expectations_wait => true,
:individual_tech_curves => false,
:strategy_immediate_release => false,
:strategy_announce_quality => true,
:strategy_announce_time => false,
:strategy_announce_quality_linear => true,
:strategy_announce_quality_percentage => false,
:strategy_announce_quality_closing_gap => false,
:strategy_announce_quality_perf_increase => 0.1*0.675,
:strategy_announce_quality_prob_decrease => 0.000825*0.675,
:strategy_announce_quality_improvement_pct => 0.01,
:strategy_announce_quality_closing_pct => 0.1,
:strategy_announce_time_time_in_months => 96,
:consumers => Dict{Int64,Consumer},
:producers => Dict{Int64,Producer},
:statistics => StatisticsAgent,
:iteration => 0,
:innovation_prob_safety => 0.05,
:innovation_prob_performance => 0.05,
:innovation_std_safety => 0.0005,
:innovation_std_performance => 0.05,
:technological_curve => a -> 1/(1+exp(-0.02*(a - 300))),
:tech_age_function => n -> 1,
:prob_consider => 0.25,
:max_variance_performance => 0.25,
:max_variance_prob_of_acc => 0.0025,
:init_belief_function_performance => d -> 1/(1+exp(50*(d-0.1))),
:init_belief_function_prob_of_accident => d -> 1/(1+exp(50000*(d-0.0001))),
:perf_update_own_rate => 0.2,
:perf_update_own_noise => 0.1,
:prob_of_accident_noise => 0.0005,
:prob_read_newspaper => 0.1
)

# Function to set up the initial state of the model
function initialize(properties, num_consumers, num_producers)
    model = ABM(Union{Consumer, Producer, StatisticsAgent},  properties = properties, warn = false)

    id = 0

    model.consumers = Dict{Int64,Consumer}()
    model.producers = Dict{Int64,Producer}()

    initial_performance_sv = 0.5

    agent_properties = CSV.read("data/agent_properties_from_kde.csv", DataFrame, header=false)
    agent_properties_times = CSV.read("data/agent_properties_times_from_kde.csv", DataFrame, header=false)

	median_min_performance = median(agent_properties[! , 1])
	median_max_prob_of_accident = median(agent_properties[!, 2])
	median_prob_threshold = median(agent_properties[!, 3])
	median_prob_talk_to_friend = median(agent_properties[!, 4])
	median_communication_noise = median(agent_properties[!, 5])

	median_car_min_life = Int64(round(median(agent_properties_times[!, 1])))
	median_car_max_life = Int64(round(median(agent_properties_times[!, 2])))

    for i in 1:num_consumers
        id+=1
        cons = Consumer(id)

        cons.owns_sv = true
        cons.age_car = rand(1:120)
        cons.performance_owned = initial_performance_sv

        cons.pos_x = rand()
        cons.pos_y = rand()

		if model.no_consumer_het
			cons.min_performance = rand(Normal(1.0, 0.1)) * median_min_performance
			cons.max_prob_of_accident = rand(Normal(1.0, 0.1)) * median_max_prob_of_accident
			cons.prob_threshold = rand(Normal(1.0, 0.1)) * median_prob_threshold
			cons.prob_talk_to_friend = rand(Normal(1.0, 0.1)) * median_prob_talk_to_friend
			cons.communication_noise = rand(Normal(1.0, 0.1)) * median_communication_noise
			cons.nsi_threshold = 0
			cons.car_min_life = rand(Normal(1.0, 0.1)) * median_car_min_life
			cons.car_max_life = rand(Normal(1.0, 0.1)) * median_car_max_life
		else
			sample_id = (model.run_id - 1) * num_consumers + i

	        cons.min_performance = agent_properties[sample_id,1]
	        cons.max_prob_of_accident = agent_properties[sample_id,2]
	        cons.prob_threshold = agent_properties[sample_id,3]
			cons.prob_talk_to_friend = agent_properties[sample_id,4]
	        cons.communication_noise = agent_properties[sample_id,5]
	        cons.nsi_threshold = 0
	        cons.car_min_life = Int64(round(agent_properties_times[sample_id,1]))
	        cons.car_max_life = Int64(round(agent_properties_times[sample_id,2]))
		end

		if rand() < model.unc_using_pct
			cons.prob_threshold = 0.2 + rand(Normal(0.0, 0.05))
			cons.special = true
		end

		if cons.car_max_life < cons.car_min_life+12
            cons.car_max_life = cons.car_min_life+12
        end

        add_agent!(cons, model)
        model.consumers[id] = cons
    end

    for i_p in 1:num_producers
        id+=1
        prod = Producer(id)

        prod.performance_developed = 0.0
        prod.true_prob_of_accident_developed = 0.01
        prod.perceived_prob_of_accident_developed = 0.01
        prod.market_share_av = 1 / num_producers
        prod.latest_av_model_id = "-"

        prod.innovation_prob_safety = model.innovation_prob_safety
        prod.innovation_prob_performance = model.innovation_prob_performance
        prod.innovation_std_safety = model.innovation_std_safety
        prod.innovation_std_performance = model.innovation_std_performance
        prod.technological_curve = model.technological_curve

        if i_p == 1
            prod.strategy = "ANNOUNCE_TIME"
            prod.label = "announce_time"
        end

        if i_p == 2
            prod.strategy = "ANNOUNCE_QUALITY"
            prod.label = "announce_quality"
        end

        prod.announcement_active = true
        prod.announced_time_next_release = rand(1:model.strategy_announce_time_time_in_months)
        prod.announced_performance_next_release = 1
        prod.announced_prob_of_accident_next_release = 1

        add_agent!(prod, model)
        model.producers[id] = prod
    end

    id+=1
    stat = StatisticsAgent(id)
    add_agent!(stat, model)
    model.statistics = stat

    # Barabasi-Albert network
    for id in 1:n_link+1
        for id2 in 1:n_link+1
            if id != id2
                push!(model[id].friends, id2)
                push!(model[id2].friends, id)
            end
        end
    end


    for id in (n_link+2):num_consumers
        total_score = 0
        scores = zeros(id-1)
        for id2 in 1:id-1
            scores[id2] = length(model[id2].friends)^beta*distance(model[id],model[id2])^alpha
            total_score += scores[id2]
        end

        weights = map(s -> s/total_score, scores)

        friends_sample = sample(1:id-1, Weights(weights), n_link, replace=false, ordered=false)

        for fid in friends_sample
            push!(model[fid].friends, id)
            push!(model[id].friends, fid)
        end
    end

    return model
end

function distance(c1::Consumer, c2::Consumer)
    return sqrt((c1.pos_x-c2.pos_x)^2+(c1.pos_y-c2.pos_y)^2)
end
