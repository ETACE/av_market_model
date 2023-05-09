# AV Market Model

Version: May 2023

This is the source code of a model used to study how uncertainty about performance and safety of autonomous vehicles influences the success of two prototypical strategies governing the producers’ timing of the release of new models.

## Getting Started

These instructions will allow you to run the model on your system.

### System Requirements and Installation

To run the code you need to install **[Julia](https://julialang.org/)** (v1.7.2). Additionally, the following packages need to be installed:

* [Agents](https://juliadynamics.github.io/Agents.jl/stable/) - Version 5.4.0
* [ArgParse](https://argparsejl.readthedocs.io/en/latest/argparse.html) - Version 1.1.4
* [CSV](https://csv.juliadata.org/stable/) - Version 0.10.4
* [DataFrames](https://juliadata.github.io/) - Version 1.3.2
* [DataStructures](https://juliacollections.github.io/DataStructures.jl/latest/) - Version 0.18.12
* [Distributions](https://github.com/JuliaStats/Distributions.jl) - Version 0.25.58
* [Plots](http://docs.juliaplots.org/) - Version 1.26.0
* [StatsBase](https://juliastats.org/StatsBase.jl/stable/) - Version 0.33.16
* [StatsPlots](https://github.com/JuliaPlots/StatsPlots.jl) - Version 0.14.33
* [TensorCast](https://github.com/mcabbott/TensorCast.jl) - Version 0.4.4

In order to install a package, start *julia* and execute the following command:

```
using Pkg; Pkg.add("<package name>")
```

### Running The Model

The model implementation is located in the *model/* folder. In order to run the model, the initial state has to be set-up. Our baselinite initialization is specified in the *experiments/init_duopoly_survey.jl* file. By default, the subset of data stored during a simulation run is defined in the *experiments/data_collection_duopoly.jl* file.

To conduct an experiment and execute several runs of the model (batches) in parallel, execute *run_exp.jl*. This requires to set-up the experiment(s) in a configuration file, see *experiments/baseline.jl* as an example. In order to execute an experiment, use the following command:

```
julia -p <no_cpus> run_exp.jl <config-file> [--chunk <i>] [--no_chunks <n>]
```

The julia parameter *-p <no_cpus>* specifies how many cpu cores will be used in parallel. The *--chunk* and *--no_chunk* parameters are optional and can be used to break up the experiment into several chunks, e.g. to distribute execution among different machines.

Plots from experiments can be created by using the following command:

```
julia plot_exp.jl <config-file>
```

By default, data and plots will be stored in the *data/* folder.

## Replication

To reproduce the results from the paper by re-simulating the model, use the following commands:

```
julia -p <no_cpus> run_exp.jl experiments/baseline.jl
julia -p <no_cpus> run_exp.jl experiments/flat_tech.jl
julia -p <no_cpus> run_exp.jl experiments/no_cons_het.jl
julia -p <no_cpus> run_exp.jl experiments/no_uncertainty.jl
julia -p <no_cpus> run_exp.jl experiments/using_uncertainty.jl
```

The resulting data will be stored in *data/*, which by default contains the data used to create the plots in the paper. 

In order to recreate all plots from the paper, run:

```
julia plots_paper.jl
```

## Empirical Data

We conducted a survey among German car owners and sampled from a kernel density estimation (KDE) to populate the model with heterogenous agents.
The original survey data (in SPSS Statistics file format) as well as the data sampled from the KDE (as CSV files) can be found in the *data/* folder.

## Authors

Herbert Dawid, Dirk Kohlweyer, Melina Schleef, Christian Stummer

## Further Links

* [ETACE](https://www.uni-bielefeld.de/fakultaeten/wirtschaftswissenschaften/lehrbereiche/etace/) - Economic Theory and Computational Economics, Bielefeld University
* [ITM](https://www.uni-bielefeld.de/fakultaeten/wirtschaftswissenschaften/lehrbereiche/itm/index.xml) - Innovation and Technology Management, Bielefeld University