mutable struct AutonomousVehicle
    model_id::String
    producer_id::Int
    time_of_release::Int64
    performance::Float64
    true_prob_of_accident::Float64
    perceived_prob_of_accident::Float64
    safety::Float64
end

function AutonomousVehicle()
    return AutonomousVehicle("",0,0,0,0,0,0)
end

mutable struct Producer <: AbstractAgent
    id::Int
    label::String
    performance_developed::Float64
    true_prob_of_accident_developed::Float64
    safety_developed::Float64
    perceived_prob_of_accident_developed::Float64
    strategy::String
    vehicles_released::Dict{String, AutonomousVehicle} # {model_id, AV model}
    latest_av_model_id::String
    av_sold::Int64
    market_share_av::Float64
    total_av_sold::Float64
    announcement_active::Bool
    announced_time_next_release::Int64
    announced_performance_next_release::Float64
    announced_prob_of_accident_next_release::Float64
    accidents_reported::Dict{String, Int64}
    vehicle_months::Dict{String, Int64}
    avs_on_road::Int64
    accidents::Int64
    accident_rate::Float64
    avs_on_road_last_month::Int64
    accidents_last_month::Int64
    new_release::Bool
    latest_release_performance::Float64
    latest_release_perceived_prob_of_acc::Float64
    latest_release_true_prob_of_acc::Float64
    latest_release_reported_prob_of_acc::Float64
    innovation_prob_safety::Float64
    innovation_prob_performance::Float64
    innovation_std_safety::Float64
    innovation_std_performance::Float64
    technological_curve::Any
    tech_age::Float64
end

function Producer(id)
    return Producer(id,"",0,0,0,0,"",Dict{Int64,AutonomousVehicle}(),"",0,0,0,false,0,0,0,Dict{String, Int64}(), Dict{String, Int64}(),0,0,0,0,0, false,0,0,0,0,0,0,0,0,0,0)
end

function reset(producer::Producer, model::ABM)
    producer.av_sold = 0
end

function innovation_process(producer::Producer, model::ABM)
    any_changes = false
    producer.new_release = false

    producer.tech_age += model.tech_age_function(producer.avs_on_road_last_month)

    # Safety innovation
    if rand() < producer.innovation_prob_safety
        producer.safety_developed = producer.technological_curve(producer.tech_age)
        producer.true_prob_of_accident_developed = (model.accident_prob_av_start - model.accident_prob_av_end)*(1-(producer.safety_developed)) + model.accident_prob_av_end

        if model.innovation_std_safety > 0.0
            producer.true_prob_of_accident_developed += rand(Normal(0.0, producer.innovation_std_safety))
            producer.true_prob_of_accident_developed = max(0.0, min(1.0,max(model.accident_prob_av_end,producer.true_prob_of_accident_developed)))
        end

        producer.perceived_prob_of_accident_developed = max(0.0, min(1.0,producer.true_prob_of_accident_developed + rand(Normal(0.0, model.prob_of_accident_noise))))
        any_changes = true
    end

    # Performance innovation
    if rand() < producer.innovation_prob_performance
        producer.performance_developed = producer.technological_curve(producer.tech_age)

        if model.innovation_std_performance > 0.0
            producer.performance_developed += rand(Normal(0.0, producer.innovation_std_performance))
        end

        producer.performance_developed = min(1.0,max(0.0,producer.performance_developed))

        any_changes = true
    end

    # Create new AV with latest performance and safety
    new_av = create_new_av(producer, model)

    # Immediate release strategy; Release AV as soon as it becomes available
    if producer.strategy == "IMMEDIATE"
        if any_changes
            introduce_new_av(new_av, producer, model)
        end
    end

    # Announce time strategy: Release new AV in predefined intervals
    if producer.strategy == "ANNOUNCE_TIME" && producer.announcement_active
        if model.iteration == producer.announced_time_next_release
            introduce_new_av(new_av, producer, model)

            producer.announced_time_next_release = model.iteration + model.strategy_announce_time_time_in_months
        end
    end

    # Announce quality strategy:
    if producer.strategy == "ANNOUNCE_QUALITY" && producer.announcement_active
        if (producer.performance_developed >= producer.announced_performance_next_release && producer.perceived_prob_of_accident_developed <= producer.announced_prob_of_accident_next_release) || (length(producer.vehicles_released) == 0 && model.iteration == producer.announced_time_next_release)
            introduce_new_av(new_av, producer, model)

            if model.strategy_announce_quality_percentage
                # percentage version
                producer.announced_performance_next_release = producer.performance_developed * (1 + model.strategy_announce_quality_improvement_pct)
                producer.announced_prob_of_accident_next_release = producer.perceived_prob_of_accident_developed * (1 - model.strategy_announce_quality_improvement_pct)
            end

            if model.strategy_announce_quality_linear
                # linear version
                producer.announced_performance_next_release = producer.performance_developed  + model.strategy_announce_quality_perf_increase
                producer.announced_prob_of_accident_next_release = producer.perceived_prob_of_accident_developed - model.strategy_announce_quality_prob_decrease
            end

            if model.strategy_announce_quality_closing_gap
                # closing gap version
                producer.announced_performance_next_release = producer.performance_developed + model.strategy_announce_quality_closing_pct * (1-producer.performance_developed)
                producer.announced_prob_of_accident_next_release = producer.perceived_prob_of_accident_developed + model.strategy_announce_quality_closing_pct * (0-producer.perceived_prob_of_accident_developed)
            end
        end
    end



    if producer.latest_av_model_id != "-"
        max_performance = 0.99
        min_prob_of_accident = 1.01*model.accident_prob_av_end

        # Avoid impossible announcments
        if producer.announced_performance_next_release >= 1.0
            producer.announced_performance_next_release = max_performance
        end
        if producer.announced_prob_of_accident_next_release <= 0.0
            producer.announced_prob_of_accident_next_release = min_prob_of_accident
        end

        if producer.vehicles_released[producer.latest_av_model_id].performance > max_performance - 1e-5 && producer.vehicles_released[producer.latest_av_model_id].perceived_prob_of_accident < min_prob_of_accident + 1e-7
            # Stop announcing new AVs after max quality and safety has been reached
            producer.announcement_active = false
        end
    end
end

function create_new_av(producer::Producer, model::ABM)
    new_av = AutonomousVehicle()

    new_av.model_id = "$(producer.id)-$(model.iteration)"
    new_av.producer_id = producer.id
    new_av.time_of_release = model.iteration
    new_av.performance = producer.performance_developed
    new_av.true_prob_of_accident = producer.true_prob_of_accident_developed
    #new_av.safety = producer.safety_deveolped
    new_av.perceived_prob_of_accident = producer.perceived_prob_of_accident_developed

    return new_av
end

function introduce_new_av(new_av, producer, model)
    producer.vehicles_released[new_av.model_id] = new_av

    old_av_id = producer.latest_av_model_id

    producer.latest_av_model_id = new_av.model_id

    producer.accidents_reported[new_av.model_id] = 0
    producer.vehicle_months[new_av.model_id] = 0

    producer.new_release = true
    producer.latest_release_performance = new_av.performance
    producer.latest_release_perceived_prob_of_acc = new_av.perceived_prob_of_accident
    producer.latest_release_true_prob_of_acc = new_av.true_prob_of_accident

    producer.latest_release_reported_prob_of_acc = new_av.perceived_prob_of_accident

    # Inform every consumer of new AV model with new beliefs
    for (cid, cons) in model.consumers
        if length(producer.vehicles_released) > 1
            # Introduce beliefs over new AV model taking beliefs of former AV model into account
            w_perf = model.init_belief_function_performance(abs(new_av.performance-cons.beliefs_performance[old_av_id].mean))
            var_perf = w_perf * cons.beliefs_performance[old_av_id].variance + (1-w_perf) * model.max_variance_performance

            w_acc = model.init_belief_function_prob_of_accident(abs(new_av.perceived_prob_of_accident-cons.beliefs_prob_of_accident[old_av_id].mean))
            var_acc = w_acc * cons.beliefs_prob_of_accident[old_av_id].variance + (1-w_acc) * model.max_variance_prob_of_acc
        else
            # No previous AV model: New beliefs with max variance
            var_perf = model.max_variance_performance
            var_acc = model.max_variance_prob_of_acc
        end

        cons.beliefs_performance[new_av.model_id] = Belief(new_av.model_id, new_av.performance, var_perf)
        cons.beliefs_prob_of_accident[new_av.model_id] = Belief(new_av.model_id, new_av.perceived_prob_of_accident, var_acc)
    end
end

function calc_market_shares(producer::Producer, model::ABM)
    # Calculate market share in last period
    total_av_sold = sum(map(p -> p.av_sold, values(model.producers)))

    if total_av_sold > 0
        new_market_share_av = producer.av_sold / total_av_sold
        producer.market_share_av = new_market_share_av
    end
end

function calculate_accident_prob(producer::Producer, model::ABM)
    if producer.avs_on_road > 0
        producer.accident_rate = producer.accidents / producer.avs_on_road
    else
        producer.accident_rate = 0
    end

    # Reset
    producer.accidents_last_month = producer.accidents
    producer.avs_on_road_last_month = producer.avs_on_road
    producer.accidents = 0
    producer.avs_on_road = 0

    # Update safety belief for all AV models
    for (model_id, v) in producer.vehicles_released
        if (model.iteration - v.time_of_release) > 0 && (model.iteration - v.time_of_release) % 12 == 0
            sum_x = producer.accidents_reported[model_id]
            n = producer.vehicle_months[model_id]

            producer.accidents_reported[model_id] = 0
            producer.vehicle_months[model_id] = 0

            if n > 0 && sum_x > 0
                estimated_prob = sum_x / n
                estimated_var = 1/n * estimated_prob * (1 - estimated_prob)

                if producer.latest_av_model_id == model_id
                    producer.latest_release_reported_prob_of_acc = estimated_prob
                end

                for (c_id, c) in model.consumers
                    if rand() < model.prob_read_newspaper
                        update_belief_safety(c, model_id, estimated_prob, estimated_var)
                    end
                end
            end
        end
    end
end
