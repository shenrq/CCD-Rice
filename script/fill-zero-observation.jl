#!/usr/bin/env julia
# -*- coding: utf-8 -*-
# AUTHOR: Shen Ruoque
# VERSION: v2023.12.21
#=
Some pixels in images may not have 0 good observation at that year.
Therefore, these pixels cannot obtain probability values through RF classifier.
Probability values from neibouring years were used to fill in these pixels.
=#

using Base.Threads
using Statistics
include("./gtiffio.jl")

place = ARGS[1]
version = ARGS[2]

numpath = "../num_30m"
probpath = "../classified"

yrs = 1990:2016
yrnum = length(yrs)

function getdays(place)
    if place in ["Anhui", "Hubei", "Zhejiang", "Jiangxi", "Hunan"]
        return "73_8_289_day"
    elseif place in ["Guangdong", "Guangxi", "Fujian", "Hainan"]
        return "33_8_289_day"
    elseif place in ["Heilongjiang", "Jilin", "Liaoning", "Inner_Mongolia1", "Inner_Mongolia2", "Inner_Mongolia3", "Inner_Mongolia", "Ningxia", "Tianjin", "Hebei"]
        return "97_8_217_day"
    else
        return "97_8_289_day"
    end
end

days = getdays(place)

numfile = joinpath(numpath, "$place/$place-Landsat_num-$days-obs_eq_0-WGS84.tif")
nums, ref = readgtiff(numfile)

probfiles = [joinpath(probpath, "prob-$place-$yr-v$(version).tif") for yr in yrs]
probs = stack([readgtiff(probfile)[1] for probfile in probfiles], dims=4)
probtype = eltype(probs)

println("read finish.")

failpixs = nums .== 1
validpixs = .!failpixs .& (nums .!= 255)

pixcels = findall(any(failpixs, dims=3)[:, :, 1])

@threads for pixcel in pixcels
    fails = findall(failpixs[pixcel, :])
    valids = findall(validpixs[pixcel, :])
    for fail in fails
        formers = valids[valids .< fail]
        laters = valids[valids .> fail]
        if length(formers) != 0
            former = maximum(formers)
            if length(laters) != 0
                later = minimum(laters)
                average = mean([probs[pixcel, :, former], probs[pixcel, :, later]])
                if probtype <: Integer
                    probs[pixcel, :, fail] = round.(probtype, average)
                else
                    probs[pixcel, :, fail] = average
                end
            else
                probs[pixcel, :, fail] = probs[pixcel, :, former]
            end
        else
            if length(laters) != 0
                later = minimum(laters)
                probs[pixcel, :, fail] = probs[pixcel, :, later]
            end
        end
    end
end

println("fill finish.")

for yr in yrs
    writegtiff(
        joinpath(probpath, "prob-$place-$yr-v$(version)f.tif"),
        probs[:, :, :, yr-yrs[1]+1], ref, nthread=8
    )
end
