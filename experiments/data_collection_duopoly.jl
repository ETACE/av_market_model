when_collect(model, s) = true

performance_developed(m) = mean(map(p -> p.performance_developed, values(m.producers)))
true_prob_of_accident_developed(m) = mean(map(p -> p.true_prob_of_accident_developed, values(m.producers)))
perceived_prob_of_accident_deveolped(m) = mean(map(p -> p.perceived_prob_of_accident_developed, values(m.producers)))
average_performance_owned(m) = mean(map(c -> c.performance_owned, values(m.consumers)))
average_age_car(m) = mean(map(c -> c.age_car, values(m.consumers)))
av_purchases(m) = mean(map(p -> p.av_sold, values(m.producers)))
av_owners(m) = mean(map(c -> c.owns_av, values(m.consumers)))
no_av_models(m) = mean(map(p -> length(p.vehicles_released), values(m.producers)))
announced_performance(m) = mean(map(p -> p.announced_performance_next_release, values(m.producers)))
announced_prob_of_accident(m) = mean(map(p -> p.announced_prob_of_accident_next_release, values(m.producers)))
performance_satisfied(m) = mean(map(c -> c.performance_satisfied, values(m.consumers)))
safety_satisfied(m) = mean(map(c -> c.safety_satisfied, values(m.consumers)))

avs_on_road(m) = sum(map(p -> p.avs_on_road_last_month, values(m.producers)))
accidents(m) = sum(map(p -> p.accidents_last_month, values(m.producers)))
yearly_accident_rate_total(m) = m.statistics.yearly_accident_rate_total
yearly_accident_rate_hv(m) = m.statistics.yearly_accident_rate_hv
yearly_accident_rate_av(m) = m.statistics.yearly_accident_rate_av

av_owners_special(m) = mean(map(c -> c.owns_av, filter(c -> c.special, collect(values(m.consumers)))))
av_owners_non_special(m) = mean(map(c -> c.owns_av, filter(c -> !c.special, collect(values(m.consumers)))))
av_owners_all(m) = mean(map(c -> c.owns_av, values(m.consumers)))

current_performance(m) = mean(map(p -> if p.latest_av_model_id != "-" p.vehicles_released[p.latest_av_model_id].performance else 0 end, values(m.producers)))
current_perceived_prob_acc(m) = mean(map(p -> if p.latest_av_model_id != "-" p.vehicles_released[p.latest_av_model_id].perceived_prob_of_accident else 0 end, values(m.producers)))
current_true_prob_acc(m) = mean(map(p -> if p.latest_av_model_id != "-" p.vehicles_released[p.latest_av_model_id].true_prob_of_accident else 0 end, values(m.producers)))

bought_same_brand(m) = mean(map(c -> c.bought_same_brand, values(m.consumers)))

av_market_share_1(m) = m.producers[10001].market_share_av
av_market_share_2(m) = m.producers[10002].market_share_av
av_release_1(m) = m.producers[10001].new_release
av_release_2(m) = m.producers[10002].new_release
performance_1(m) = m.producers[10001].latest_release_performance
performance_2(m) = m.producers[10002].latest_release_performance
safety_1(m) = m.producers[10001].latest_release_true_prob_of_acc
safety_2(m) = m.producers[10002].latest_release_true_prob_of_acc
total_av_sold_1(m) = m.producers[10001].total_av_sold
total_av_sold_2(m) = m.producers[10002].total_av_sold

dev_performance_1(m) = m.producers[10001].performance_developed
dev_performance_2(m) = m.producers[10002].performance_developed
dev_true_prob_acc_1(m) = m.producers[10001].true_prob_of_accident_developed
dev_true_prob_acc_2(m) = m.producers[10002].true_prob_of_accident_developed
dev_perceived_prob_acc_1(m) = m.producers[10001].perceived_prob_of_accident_developed
dev_perceived_prob_acc_2(m) = m.producers[10002].perceived_prob_of_accident_developed
label_1(m) = m.producers[10001].label
label_2(m) = m.producers[10002].label

strictly_dominates_1(m) = m.producers[10001].latest_release_performance >  m.producers[10002].latest_release_performance &&  m.producers[10001].latest_release_true_prob_of_acc > m.producers[10002].latest_release_true_prob_of_acc
strictly_dominates_2(m) = m.producers[10002].latest_release_performance >  m.producers[10001].latest_release_performance &&  m.producers[10002].latest_release_true_prob_of_acc > m.producers[10001].latest_release_true_prob_of_acc

no_av_models_1(m) = length(m.producers[10001].vehicles_released)
no_av_models_2(m) = length(m.producers[10002].vehicles_released)

avs_on_road_1(m) = m.producers[10001].avs_on_road_last_month
avs_on_road_2(m) = m.producers[10002].avs_on_road_last_month

adaption(m) = mean(map(c -> c.just_adapted_av, values(m.consumers)))

accidents_hv(m) = m.statistics.accidents_hv
accidents_av(m) = m.statistics.accidents_av
accidents_total(m) = m.statistics.accidents_total

mdata = [av_owners_special, av_owners_all, av_owners_non_special, avs_on_road_1, avs_on_road_2, strictly_dominates_1,strictly_dominates_2,performance_1,performance_2,safety_1,safety_2,av_release_1, av_release_2, av_market_share_1, av_market_share_2, performance_satisfied, safety_satisfied, performance_developed, true_prob_of_accident_developed, average_performance_owned, average_age_car, av_purchases, av_owners, no_av_models, announced_performance, announced_prob_of_accident,
avs_on_road,
current_performance,current_perceived_prob_acc,current_true_prob_acc, bought_same_brand,no_av_models_1,no_av_models_2,
total_av_sold_1,total_av_sold_2,adaption,
dev_performance_1,dev_performance_2,dev_true_prob_acc_1,dev_true_prob_acc_2,dev_perceived_prob_acc_1,dev_perceived_prob_acc_2, accidents, accidents_hv, accidents_av, accidents_total, yearly_accident_rate_total, yearly_accident_rate_hv, yearly_accident_rate_av]
adata = nothing
