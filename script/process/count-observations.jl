#!/usr/bin/env julia
# -*- coding: utf-8 -*-
# AUTHOR: Shen Ruoque
# VERSION: v2023.11.23
#=
Count the number of good observations on each pixel
=#

using Base.Threads
include("../gtiffio.jl")

places = [
    # "Anhui",
    # "Chongqing",
    # "Fujian",
    # "Guangdong",
    # "Guangxi",
    # "Guizhou",
    # "Hainan",
    # "Henan",
    # "Hubei",
    # "Hunan",
    # "Jiangsu",
    # "Jiangxi",
    # "Jilin",
    # "Liaoning",
    # "Ningxia",
    # "Shaanxi",
    # "Shandong",
    "Shanghai",
    # "Zhejiang",
    # "Sichuan",
    # "Yunnan",
    # "Heilongjiang",
    # "Inner_Mongolia",
    # "Tianjin",
    # "Hebei"
]

function getdays(place)
    if place in ["Anhui", "Hubei", "Zhejiang", "Jiangxi", "Hunan"]
        return "73_8_289_day"
    elseif place in ["Guangdong", "Guangxi", "Fujian", "Hainan"]
        return "33_8_289_day"
    elseif place in ["Heilongjiang", "Jilin", "Liaoning", "Inner_Mongolia", "Ningxia", "Tianjin", "Hebei"]
        return "97_8_217_day"
    else
        return "97_8_289_day"
    end
end

path = "../../swir1_30m"
outpath = "../../num_30m"

for place = places
    days = getdays(place)
    GC.gc()
    @threads for yr = 1990:2016
        println("$place $yr")
        GC.gc()
        infile = "$path/$place/$yr/$place-$yr-Landsat_swir1-$days-WGS84.tif"
        outfile = "$outpath/$place/$place-$yr-Landsat_num-$days-WGS84.tif"
        if isfile(outfile) continue end
        data, ref = readgtiff(infile)
        counts = UInt8.(sum(data .≠ 0, dims=3))
        writegtiff(outfile, counts, ref, nthread=8)
    end
end
