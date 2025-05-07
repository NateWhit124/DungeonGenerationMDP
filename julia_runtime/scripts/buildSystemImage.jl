using PackageCompiler
using CommonRLInterface
using StaticArrays
using Statistics
using StatsBase
using Compose
using ColorSchemes
using DataStructures
using JSON3
using Cairo
using Fontconfig
using Flux
using Flux: throttle, flatten, mse, gradient
using Statistics
using Random
using CommonRLInterface
using Plots
using Flux, JLD2, FileIO

create_sysimage(
    [
        "CommonRLInterface",
        "StaticArrays",
        "Statistics",
        "StatsBase",
        "Compose",
        "ColorSchemes",
        "DataStructures",
        "JSON3",
        "Cairo", 
        "Fontconfig",
        "Flux",
        "Statistics",
        "Random",
        "Plots",
        "Flux",
        "FileIO",
        "JLD2"
    ],
    sysimage_path="..\\my_sysimage.so", 
    precompile_execution_file="handler.jl"
)