mutable struct Belief
    model_id::String
    mean::Float64
    variance::Float64
end

mutable struct Consumer <: AbstractAgent
    id::Int64
    pos_x::Float64
    pos_y::Float64
    min_performance::Float64
    max_prob_of_accident::Float64
    prob_threshold::Float64
    nsi_threshold::Float64
    prob_talk_to_friend::Float64
    communication_noise::Float64
    car_min_life::Float64
    car_max_life::Float64
    performance_owned::Float64
    safety_owned::Float64
    owns_sv::Bool
    owns_av::Bool
    owns_av_producer_id::Int64
    owns_av_model_id::String
    age_car::Int64
    friends::Set{Int64}
    beliefs_performance::Dict{String, Belief}
    beliefs_prob_of_accident::Dict{String, Belief}
    performance_satisfied::Bool
    safety_satisfied::Bool
    bought_same_brand::Bool
    just_adapted_av::Bool
    special::Bool
end

function Consumer(id)
    return Consumer(id, 0,0,0,0, 0,0,0,0, 0, 0,0,0, false, false, 0,"-",0, Set{Int64}(),Dict{String, Belief}(), Dict{String, Belief}(), false, false, false,false, false)
end

function act(consumer::Consumer, model::ABM)
    producer = get_best_av_producer(consumer, model)

    consumer.just_adapted_av = false

    log = false

    # Select latest AV on market
    latest_av = nothing
    if producer != nothing
        latest_av = producer.vehicles_released[producer.latest_av_model_id]
        satisfied, perf_prob, safety_prob = check_av(consumer, model, latest_av.model_id) # For statistics only

        consumer.performance_satisfied = perf_prob >= consumer.prob_threshold

        consumer.safety_satisfied = safety_prob >= consumer.prob_threshold
    end

    # Increment age of car
    if consumer.owns_sv || consumer.owns_av
        consumer.age_car += 1
    end

    # In case consumer owns AV:
    if consumer.owns_av
        # Update performance perception
        if rand() < model.perf_update_own_rate
            update_performance_perception(consumer, model)
        end
    end

    # Simulate accidents
    simulate_accidents(consumer, model)

    # Decide wether to buy a new vehicle (AV or HV)
    buy_hv, buy_av, wait = decide(consumer, model)

    # buy AV
    if buy_av
        if consumer.owns_av_producer_id == producer.id
            consumer.bought_same_brand = true
        end
        producer.av_sold += 1
        producer.total_av_sold += 1

        if !consumer.owns_av
            consumer.just_adapted_av = true
        end

        consumer.owns_sv = false
        consumer.owns_av = true
        consumer.owns_av_producer_id = latest_av.producer_id
        consumer.owns_av_model_id = latest_av.model_id
        consumer.age_car = 0
        consumer.performance_owned = producer.performance_developed
    end

    # buy HV
    if buy_hv
        consumer.owns_sv = true
        consumer.owns_av = false
        consumer.age_car = 0
        consumer.owns_av_producer_id = 0
    end
end

function decide(consumer::Consumer, model::ABM)
    buy_hv = false
    buy_av = false
    wait = false

    producer = get_best_av_producer(consumer, model)
    if producer != nothing
        av = producer.vehicles_released[producer.latest_av_model_id]
    else
        av = nothing
    end

    if consumer.age_car >= consumer.car_max_life
        # Car to old -> Consumer has to buy now, decide between AV amd HV
        if av != nothing
            buy_av, p, q = check_av(consumer, model, av.model_id)
        end
        if !buy_av
            buy_hv = true
        end
    else
        if consumer.age_car > consumer.car_min_life && consumer.age_car < consumer.car_max_life
            # Consider buying
            if rand() < model.prob_consider
                # Check if currently available AV is good enough
                if av != nothing
                    buy_av, p, q = check_av(consumer, model, av.model_id)
                end

                # If not, consider waiting
                if !buy_av
                    wait = wait_time_announced(consumer, model) || wait_quality_announced(consumer, model)

                    # Buy HV if decide not to wait
                    buy_hv = !wait
                else
                    if model.expectations_wait
                        # Consider waiting for a better option
                        wait = wait_better_option(consumer, model)

                        if wait
                            buy_hv = false
                            buy_av = false
                        end
                    end
                end
            end
        end
    end

    return buy_hv, buy_av, wait
end

function get_best_av_producer(consumer::Consumer, model::ABM)
    satisfied_max = false
    prob_max = 0.0
    best_producer = nothing

    for producer in shuffle!(collect(values(model.producers)))
    #for (p_id, producer) in model.producers
        if producer.latest_av_model_id != "-"

            satisfied, prob_perf, prob_safety = check_av(consumer, model, producer.latest_av_model_id)
            prob = prob_perf * prob_safety
            new_best = false

            if satisfied_max == false && satisfied == true
                new_best = true
            end
            if satisfied_max == false && prob > prob_max
                new_best = true
            end
            if satisfied_max == true && satisfied == true && prob > prob_max
                new_best = true
            end

            if new_best
                best_producer = producer
                satisfied_max = satisfied
                prob_max = prob
            end
        end
    end

    return best_producer
end

function wait_better_option(consumer::Consumer, model::ABM)
    best_producer = get_best_av_producer(consumer, model)
    satisfied_best, prob_perf_best, prob_safety_best = check_av(consumer, model, best_producer.latest_av_model_id)
    prob_best = prob_perf_best * prob_safety_best

    for (p_id, producer) in model.producers
        if producer.strategy == "ANNOUNCE_TIME" && producer.announcement_active
            arrives_in_time = (producer.announced_time_next_release - model.iteration + consumer.age_car) < consumer.car_max_life

            if arrives_in_time
                exp_perf, exp_acc_prob = calculate_expected_quality_next_release(producer, model)

                calculate_beliefs_future_av(exp_perf, exp_acc_prob, consumer, producer, model)
                satisfied, p1, p2 = check_av(consumer, model, "future_av")

                if p1*p2 > prob_best
                    return true
                end
            end
        end

        if producer.strategy == "ANNOUNCE_QUALITY" && producer.announcement_active
            exp_t = calculate_expected_time_next_release(producer, model)

            arrives_in_time = (exp_t - model.iteration + consumer.age_car) < consumer.car_max_life

            if arrives_in_time
                calculate_beliefs_future_av(producer.announced_performance_next_release, producer.announced_prob_of_accident_next_release, consumer, producer, model)
                satisfied, p1, p2 = check_av(consumer, model, "future_av")

                if p1*p2 > prob_best
                    return true
                end
            end
        end
    end

    return false
end

function wait_time_announced(consumer::Consumer, model::ABM)
    for (p_id, producer) in model.producers
        if producer.strategy == "ANNOUNCE_TIME" && producer.announcement_active
            if (producer.announced_time_next_release - model.iteration + consumer.age_car) < consumer.car_max_life
                if !model.expectations_wait
                    # Wait
                    return true
                else
                    exp_perf, exp_acc_prob = calculate_expected_quality_next_release(producer, model)

                    calculate_beliefs_future_av(exp_perf, exp_acc_prob, consumer, producer, model)

                    satisfied, p1, p2 = check_av(consumer, model, "future_av")

                    return satisfied
                end
            end
        end
    end
    return false
end

function calculate_expected_quality_next_release(producer::Producer, model::ABM)
    perfs = Dict{Int64, Float64}()
    acc_probs = Dict{Int64, Float64}()

    for (av_id, av) in producer.vehicles_released
        perfs[av.time_of_release] = av.performance
        acc_probs[av.time_of_release] = av.perceived_prob_of_accident
    end

    release_times = collect(keys(perfs))

    if length(release_times) > 1
        sort!(release_times, rev = true)

        exp_perf = perfs[release_times[1]] + (perfs[release_times[1]] - perfs[release_times[2]])
        exp_acc_prob = acc_probs[release_times[1]] + (acc_probs[release_times[1]] - acc_probs[release_times[2]])

        return exp_perf, exp_acc_prob
    end

    return 0.0, 1.0
end

function calculate_expected_time_next_release(producer::Producer, model::ABM)
    release_times = []

    for (av_id, av) in producer.vehicles_released
        append!(release_times, av.time_of_release)
    end

    if length(release_times) > 1
        sort!(release_times)

        exp_t = release_times[1] + (release_times[1] - release_times[2])
        return exp_t
    end

    return 999999999999999999999999
end

function calculate_beliefs_future_av(perf_mean, acc_prob_mean, consumer::Consumer, producer::Producer, model::ABM)
    if length(producer.vehicles_released) > 1
        old_av_id = producer.latest_av_model_id

        w_perf = 2/(1+exp(10*(abs(perf_mean-consumer.beliefs_performance[old_av_id].mean))))
        var_perf = w_perf * consumer.beliefs_performance[old_av_id].variance + (1-w_perf) * model.max_variance_performance

        w_acc = 2/(1+exp(1000*(abs(acc_prob_mean-consumer.beliefs_prob_of_accident[old_av_id].mean))))
        var_acc = w_acc * consumer.beliefs_prob_of_accident[old_av_id].variance + (1-w_acc) * model.max_variance_prob_of_acc
    else
        var_perf = model.max_variance_performance
        var_acc = model.max_variance_prob_of_acc
    end

    consumer.beliefs_performance["future_av"] = Belief("future_av", perf_mean, var_perf)
    consumer.beliefs_prob_of_accident["future_av"] = Belief("future_av", acc_prob_mean, var_acc)
end

function wait_quality_announced(consumer::Consumer, model::ABM)
    for (p_id, producer) in model.producers
        if producer.strategy == "ANNOUNCE_QUALITY"
            # Do not wait if producer hasn't announced new AV
            if producer.announcement_active
                if length(producer.vehicles_released) > 1
                    old_av_id = producer.latest_av_model_id

                    w_perf = 2/(1+exp(10*(abs(producer.announced_performance_next_release-consumer.beliefs_performance[old_av_id].mean))))
                    var_perf = w_perf * consumer.beliefs_performance[old_av_id].variance + (1-w_perf) * model.max_variance_performance

                    w_acc = 2/(1+exp(1000*(abs(producer.announced_prob_of_accident_next_release-consumer.beliefs_prob_of_accident[old_av_id].mean))))
                    var_acc = w_acc * consumer.beliefs_prob_of_accident[old_av_id].variance + (1-w_acc) * model.max_variance_prob_of_acc
                else
                    var_perf = model.max_variance_performance
                    var_acc = model.max_variance_prob_of_acc
                end

                consumer.beliefs_performance["future_av"] = Belief("future_av", producer.announced_performance_next_release, var_perf)
                consumer.beliefs_prob_of_accident["future_av"] = Belief("future_av", producer.announced_prob_of_accident_next_release, var_acc)

                satisfiend, p1, p2 = check_av(consumer, model, "future_av")

                arrives_in_time = true
                if model.expectations_wait
                    # Check wether car would arrive in time
                    exp_t = calculate_expected_time_next_release(producer, model)

                    arrives_in_time = (exp_t - model.iteration + consumer.age_car) < consumer.car_max_life
                end

                if satisfiend && arrives_in_time
                    return true
                end
            end
        end
    end
    return false
end

function check_av(consumer::Consumer, model::ABM, av_model_id::String)
    perf_prob = 0.0
    safety_prob = 0.0

    performance_satisfied = false
    safety_satisifed = false

    if length(consumer.beliefs_performance) > 0
        # Check if available AV is good enough
        perf_mean = consumer.beliefs_performance[av_model_id].mean
        perf_std = sqrt(consumer.beliefs_performance[av_model_id].variance)

        prob_acc_mean = consumer.beliefs_prob_of_accident[av_model_id].mean
        prob_acc_std = sqrt(consumer.beliefs_prob_of_accident[av_model_id].variance)

        if perf_std > 0.0
            d_perf = Normal(perf_mean, perf_std)
            perf_prob = 1-cdf(d_perf, consumer.min_performance)
        else
            perf_prob = perf_mean >= consumer.min_performance ? 1 : 0
        end

        if prob_acc_std > 0.0
            d_prob_acc = Normal(prob_acc_mean, prob_acc_std)
            safety_prob = cdf(d_prob_acc, consumer.max_prob_of_accident)
        else
            safety_prob = prob_acc_mean <= consumer.max_prob_of_accident ? 1 : 0
        end

        performance_satisfied = perf_prob >= consumer.prob_threshold

        safety_satisfied = safety_prob >= consumer.prob_threshold

        nsi = true
        if model.normative_social_influence
             nsi = check_normative_social_influence(consumer, model)
        end


        if performance_satisfied && safety_satisfied && nsi
            return true, perf_prob, safety_prob
        end

        if model.two_of_three && safety_satisfied && performance_satisfied + nsi >= 1
            return true, perf_prob, safety_prob
        end
    end

    return false, perf_prob, safety_prob
end

function check_normative_social_influence(consumer::Consumer, model::ABM)
    total_friends = length(consumer.friends)
    adopter_friends = 0
    for f_id in consumer.friends
        f = model[f_id]
        if f.owns_av
            adopter_friends += 1
        end
    end

    if adopter_friends / total_friends >= consumer.nsi_threshold
        return true
    else
        return false
    end
end

function update_performance_perception(consumer::Consumer, model::ABM)
    producer = model[consumer.owns_av_producer_id]

    if model.perf_update_own_noise > 0.0
        signal_own = producer.vehicles_released[consumer.owns_av_model_id].performance + rand(Normal(0, model.perf_update_own_noise))
    else
        signal_own = producer.vehicles_released[consumer.owns_av_model_id].performance
    end

    # Update own belief
    update_belief_performance(consumer, consumer.owns_av_model_id, signal_own, model.perf_update_own_noise)

    # send signal to friends
    for f_id in consumer.friends
        friend = model[f_id]
        if rand() < friend.prob_talk_to_friend

            noise = (consumer.communication_noise + friend.communication_noise) / 2

            signal_friend = consumer.beliefs_performance[consumer.owns_av_model_id].mean + rand(Normal(0, noise))

            # Update friend's belief
            update_belief_performance(friend, consumer.owns_av_model_id, signal_friend, noise)
        end
    end
end

function update_belief_performance(consumer::Consumer, model_id, signal, signal_variance)
    if consumer.beliefs_performance[model_id].variance > 0.0 # If current belief has no variance -> no update
        if signal_variance > 0.0
            tau_perf = 1 / consumer.beliefs_performance[model_id].variance
            tau_s = 1 / signal_variance

            post_mean = (tau_perf * consumer.beliefs_performance[model_id].mean + tau_s * signal) / (tau_perf + tau_s)
            post_variance = 1 / (tau_perf + tau_s)

            consumer.beliefs_performance[model_id].mean = post_mean
            consumer.beliefs_performance[model_id].variance = post_variance
        else
            consumer.beliefs_performance[model_id].mean = signal
            consumer.beliefs_performance[model_id].variance = 0.0
        end
    end
end

function update_belief_safety(consumer::Consumer, model_id, signal, signal_variance)
    if consumer.beliefs_prob_of_accident[model_id].variance > 0.0 # If current belief has no variance -> no update
        if signal_variance > 0.0
            tau_prior = 1 / consumer.beliefs_prob_of_accident[model_id].variance
            tau_s = 1 / signal_variance

            post_mean = (tau_prior * consumer.beliefs_prob_of_accident[model_id].mean + tau_s * signal) / (tau_prior + tau_s)
            post_variance = 1 / (tau_prior + tau_s)

            consumer.beliefs_prob_of_accident[model_id].mean = post_mean
            consumer.beliefs_prob_of_accident[model_id].variance = post_variance
        else
            consumer.beliefs_prob_of_accident[model_id].mean = signal
            consumer.beliefs_prob_of_accident[model_id].variance = 0.0
        end
    end
end

function simulate_accidents(consumer::Consumer, model::ABM)
    N = 100

    if consumer.owns_av
        producer = model[consumer.owns_av_producer_id]

        producer.vehicle_months[consumer.owns_av_model_id] += 1
        producer.avs_on_road += 1
    end

    if !model.accidents_extension
        if consumer.owns_av
            for _ in 1:N
                if rand() < producer.vehicles_released[consumer.owns_av_model_id].true_prob_of_accident / N
                    report_accident_av(producer, consumer.owns_av_model_id, model)
                end
            end
        else
            for _ in 1:N
                if rand() < model.accident_prob_hv / N
                    report_accident_hv(model)
                end
            end
        end
    else
        if consumer.owns_av
            producer = model[consumer.owns_av_producer_id]
            av_hv_prob = producer.vehicles_released[consumer.owns_av_model_id].true_prob_of_accident
            av_av_prob = producer.vehicles_released[consumer.owns_av_model_id].true_prob_of_accident / 2
        end

        sample = rand([1, length(model.consumers)], N)

        for i in sample
            if !consumer.owns_av
                if rand() < (model.accident_prob_hv / N)
                    report_accident_hv(model)
                end
            else
                if model[i].owns_av
                    if rand() < (av_av_prob / N)
                        report_accident_av(producer, consumer.owns_av_model_id, model)
                    end
                else
                    if rand() < (av_hv_prob / N)
                        report_accident_av(producer, consumer.owns_av_model_id, model)
                    end
                end
            end
        end
    end
end
