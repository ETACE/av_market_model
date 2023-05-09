mutable struct StatisticsAgent <: AbstractAgent
    id::Int
    accidents_total::Int64
    accidents_hv::Int64
    accidents_av::Int64
    accidents_total_ts::CircularBuffer{Int64}
    accidents_av_ts::CircularBuffer{Int64}
    accidents_hv_ts::CircularBuffer{Int64}
    yearly_accident_rate_total::Float64
    yearly_accident_rate_hv::Float64
    yearly_accident_rate_av::Float64
end

function StatisticsAgent(id)
    return StatisticsAgent(id,0,0,0,CircularBuffer{Int64}(12),CircularBuffer{Int64}(12),CircularBuffer{Int64}(12),0,0,0)
end

function report_accident_hv(model)
    model.statistics.accidents_total += 1
    model.statistics.accidents_hv += 1
end

function report_accident_av(producer::Producer, av_model_id, model)
    producer.accidents_reported[av_model_id] += 1
    producer.accidents += 1
    model.statistics.accidents_total += 1
    model.statistics.accidents_av += 1
end

function reset(stat::StatisticsAgent, model)
    push!(stat.accidents_total_ts, stat.accidents_total)
    push!(stat.accidents_hv_ts, stat.accidents_hv)
    push!(stat.accidents_av_ts, stat.accidents_av)

    stat.accidents_total = 0
    stat.accidents_hv = 0
    stat.accidents_av = 0

    v_acc_tot = convert(Vector{Int64}, stat.accidents_total_ts)
    v_acc_hv = convert(Vector{Int64}, stat.accidents_hv_ts)
    v_acc_av = convert(Vector{Int64}, stat.accidents_av_ts)

    n_tot = length(model.consumers)
    n_av = sum(map(c -> c.owns_av, values(model.consumers)))
    n_hv = n_tot - n_av

    stat.yearly_accident_rate_total = sum(v_acc_tot) * (12 / length(v_acc_tot)) / n_tot
    n_hv > 99 ? stat.yearly_accident_rate_hv = sum(v_acc_hv) * (12 / length(v_acc_hv)) / n_hv  : NaN
    n_av > 99 ? stat.yearly_accident_rate_av = sum(v_acc_av)  * (12 / length(v_acc_av)) / n_av : NaN
end
