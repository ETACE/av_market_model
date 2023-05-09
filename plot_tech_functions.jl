using Plots

Plots.scalefontsizes(1.5)

include("model/model.jl")
folder_plots = "./data/figures_paper/"

if !isdir(folder_plots)
	mkdir(folder_plots)
end

include("experiments/baseline.jl")

perf_function = baseline_properties[:technological_curve]
pl_perf = plot(perf_function, 0, 700, linewidth=3, label="", xlabel="months", ylabel="performance")
savefig(pl_perf, "$(folder_plots)tech_function_performance.pdf")

prob_of_acc_function(t) = (baseline_properties[:accident_prob_av_start] - baseline_properties[:accident_prob_av_end]) * ((-1) * baseline_properties[:technological_curve](t)) + baseline_properties[:accident_prob_av_start]
pl_prob_of_acc = plot(prob_of_acc_function, 0, 700, linewidth=3, label="", xlabel="months", ylabel="prob. of accident", ylims=(0,baseline_properties[:accident_prob_av_start]))
savefig(pl_prob_of_acc, "$(folder_plots)tech_function_prob_of_acc.pdf")
