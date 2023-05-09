using Distributed, DataStructures, StatsPlots, Serialization, ArgParse, DataFrames, TensorCast


Plots.scalefontsizes(1.5)


include("model/model.jl")

function load_data(config)

	include(config)

	# load data
	results = []
	chunk = 0
	while isfile("$folder/data-$(chunk+=1).dat")
		append!(results, deserialize("$folder/data-$chunk.dat"))
	end

	if length(results) == 0
		println("ERROR: No data found in $folder/data/")
		exit(1)
	end

	# Aggregate data
	single_run_data = Dict()
	aggregated_data = Dict()

	for (exp_name, props) in experiments
		single_run_data[exp_name] = []
		aggregated_data[exp_name] = Dict()

		for i in 1:length(results)
			if results[i][:exp_name] == exp_name
				append!(single_run_data[exp_name], [results[i][:model_data][1:700,:]])
			end
		end

		for agg in run_aggregation

			agg1 = agg

			agg_data_frame = DataFrame()
			for col in propertynames(single_run_data[exp_name][1])
				data = []
				for i in 1:length(single_run_data[exp_name])
					append!(data, [single_run_data[exp_name][i][!, col]])
				end

				agg_data = agg(data)

				agg_data_frame[!, col] = agg_data
			end
			aggregated_data[exp_name][agg] = agg_data_frame
		end
	end

	return single_run_data, aggregated_data
end

folder_plots = "./data/figures_paper/"

if !isdir(folder_plots)
	mkdir(folder_plots)
end

single_run_data, aggregated_data = load_data("experiments/baseline.jl")
agg = run_aggregation[1]

function get_mean_upper_lower(data)
	mean_data = []
	upper =[]
	lower = []

	for i in 1:length(data)
		append!(mean_data, mean(data[i]))
		if !isnan(mean(data[i]))
			append!(upper, quantile(data[i], 0.975) - mean(data[i]))
			append!(lower, mean(data[i]) - quantile(data[i], 0.025))
		else
			append!(upper, NaN)
			append!(lower, NaN)
		end
	end

	return mean_data, upper, lower
end

function time_series_plot(exp, key, label, color, xlabel, ylabel, filename, na_periods=0)

	data = []
	for i in 1:length(single_run_data[exp])
		append!(data, [single_run_data[exp][i][!, key]])

		for t in 1:na_periods
			data[i][t]=NaN
		end

	end
	@cast datat[i][j] := data[j][i]


	mean, upper, lower = get_mean_upper_lower(datat)

	pl = plot(mean, label=label, color=color, linewidth=3,
	ribbon = (lower, upper), xlabel=xlabel, ylabel=ylabel)

	savefig(pl, filename)
end

function time_series_plot2(exp1, exp2, key1, key2, label1, label2, color1, color2, xlabel, ylabel, filename, na_periods=0)

	data1 = []
	for i in 1:length(single_run_data[exp1])
		append!(data1, [single_run_data[exp1][i][!, key1]])

		for t in 1:na_periods
			data1[i][t]=NaN
		end
	end
	@cast datat1[i][j] := data1[j][i]
	mean1, upper1, lower1 = get_mean_upper_lower(datat1)

	data2 = []
	for i in 1:length(single_run_data[exp2])
		append!(data2, [single_run_data[exp2][i][!, key2]])

		for t in 1:na_periods
			data2[i][t]=NaN
		end
	end
	@cast datat2[i][j] := data2[j][i]
	mean2, upper2, lower2 = get_mean_upper_lower(datat2)

	pl = plot(mean1, label=label1, color=color1, linewidth=3,
	ribbon = (lower1, upper1), xlabel=xlabel, ylabel=ylabel)
	plot!(pl, mean2, label=label2, color=color2, linewidth=3,
	ribbon = (lower2, upper2))

	savefig(pl, filename)
end

function hist_market_shares2(exp1, exp2, label1, label2, color1, color2, filename)
	market_shares_a = []
	market_shares_b = []

	for i in 1:no_runs
		market_shares_a = vcat(market_shares_a, single_run_data[exp1][i][601:700, :av_market_share_2])
		market_shares_b = vcat(market_shares_b, single_run_data[exp2][i][601:700, :av_market_share_2])
	end

	market_shares_a = map(s -> max(0.000000001, min(0.999999999,s)), market_shares_a)
	market_shares_b = map(s -> max(0.000000001, min(0.999999999,s)), market_shares_b)

	pl = histogram(market_shares_a, bins=0:0.0125:1, color=palette(:default)[1], alpha=0.5, xlabel="Market share quality strategy", label=label1)
	histogram!(pl, market_shares_b, label=label2, color=palette(:default)[2], bins=0:0.0125:1, alpha=0.5)
	savefig(pl, filename)
end

time_series_plot("baseline", "av_owners", "", palette(:default)[1], "months", "Share AV owners", "$(folder_plots)baseline-share_av_owners.pdf")
time_series_plot("baseline", "yearly_accident_rate_total", "", palette(:default)[1], "months", "Accident rate", "$(folder_plots)baseline-accident_rate.pdf", 13)
time_series_plot("baseline", "av_market_share_2", "", palette(:default)[1], "months", "Market share quality strategy", "$(folder_plots)baseline-market_share_quality_strategy.pdf")
time_series_plot2("baseline", "baseline", "total_av_sold_1", "total_av_sold_2", "Time strategy", "Quality strategy", palette(:default)[2], palette(:default)[1], "months", "Total AV sold", "$(folder_plots)baseline-total_av_sold.pdf")
time_series_plot("baseline", "av_market_share_2", "", palette(:default)[1], "months", "Market share quality strategy", "$(folder_plots)baseline-market_share_quality_strategy.pdf")
time_series_plot("baseline", "current_performance", "", palette(:default)[1], "months", "AV performance", "$(folder_plots)baseline-current_performance.pdf")
time_series_plot("baseline", "current_perceived_prob_acc", "", palette(:default)[1], "months", "AV prob. of accident", "$(folder_plots)baseline-current_prob_accident.pdf", 96)

market_shares_1 = []
market_shares_2 = []

for i in 1:no_runs
	global market_shares_1
	global market_shares_2

	market_shares_1 = vcat(market_shares_1, single_run_data["baseline"][i][601:700, :av_market_share_1])
	market_shares_2 = vcat(market_shares_2, single_run_data["baseline"][i][601:700, :av_market_share_2])
end

market_shares_1 = map(s -> max(0.000000001, min(0.999999999,s)), market_shares_1)
market_shares_2 = map(s -> max(0.000000001, min(0.999999999,s)), market_shares_2)

pl = histogram(market_shares_2,bins=0:0.0125:1, xlabel="Market share quality strategy", label="")
savefig(pl, "$(folder_plots)baseline-end_market_share_quality.pdf")

single_run_data_ft, aggregated_data_ft = load_data("experiments/flat_tech.jl")

single_run_data = merge(single_run_data, single_run_data_ft)

time_series_plot2("baseline", "flat_tech", "av_owners", "av_owners", "Baseline", "Flat technology", palette(:default)[1], palette(:default)[2], "months", "Share AV owners", "$(folder_plots)baseline_vs_flat_tech-share_av_owners.pdf")
hist_market_shares2("baseline", "flat_tech", "Baseline", "Flat technology", palette(:default)[1], palette(:default)[2], "$(folder_plots)baseline_vs_flat_tech-end_market_share_quality.pdf")

single_run_data_nch, aggregated_data_nch = load_data("experiments/no_cons_het.jl")

single_run_data = merge(single_run_data, single_run_data_nch)

time_series_plot2("baseline", "no_cons_het", "av_owners", "av_owners", "Baseline", "No consumer heterogeneity", palette(:default)[1], palette(:default)[2], "months", "Share AV owners", "$(folder_plots)baseline_vs_no_cons_het-share_av_owners.pdf")
hist_market_shares2("baseline", "no_cons_het", "Baseline", "No consumer heterogeneity", palette(:default)[1], palette(:default)[2], "$(folder_plots)baseline_vs_no_cons_het-end_market_share_quality.pdf")

single_run_data_no_unc, aggregated_data_no_unc = load_data("experiments/no_uncertainty.jl")

single_run_data = merge(single_run_data, single_run_data_no_unc)

time_series_plot2("baseline", "no_uncertainty", "av_owners", "av_owners", "Baseline", "No uncertainty", palette(:default)[1], palette(:default)[2], "months", "Share AV owners", "$(folder_plots)baseline_vs_no_uncertainty-share_av_owners.pdf")
hist_market_shares2("baseline", "no_uncertainty", "Baseline", "No uncertainty", palette(:default)[1], palette(:default)[2], "$(folder_plots)baseline_vs_no_uncertainty-end_market_share_quality.pdf")

single_run_data_using, aggregated_data_using = load_data("experiments/using_uncertainty.jl")

single_run_data = merge(single_run_data, single_run_data_using)

time_series_plot2("baseline", "using_uncertainty", "av_owners", "av_owners", "Baseline", "Using uncertainty", palette(:default)[1], palette(:default)[2], "months", "Share AV owners", "$(folder_plots)baseline_vs_using_uncertainty-share_av_owners.pdf")
time_series_plot2("baseline", "using_uncertainty", "yearly_accident_rate_total", "yearly_accident_rate_total", "Baseline", "Using uncertainty", palette(:default)[1], palette(:default)[2], "months", "Accident rate", "$(folder_plots)baseline_vs_using_uncertainty-accident_rate.pdf", 13)
time_series_plot2("using_uncertainty", "using_uncertainty", "total_av_sold_1", "total_av_sold_2", "Time strategy", "Quality strategy", palette(:default)[2], palette(:default)[1], "months", "Total AV sold", "$(folder_plots)using_uncertainty-total_av_sold.pdf")

hist_market_shares2("baseline", "using_uncertainty", "Baseline", "Using uncertainty", palette(:default)[1], palette(:default)[2], "$(folder_plots)baseline_vs_using_uncertainty-end_market_share_quality.pdf")
