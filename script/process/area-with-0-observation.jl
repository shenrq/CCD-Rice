#!/usr/bin/env julia
# -*- coding: utf-8 -*-
# AUTHOR: Shen Ruoque
# VERSION: v2023.11.23
#=
Extract pixels with o observations of each province each year.
=#

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

function filter_number(x)
    if x == 0
        return 0x01
    elseif x == 255
        return 0xff
    else
        return 0x00
    end
end

path = "../../num_30m"
yrs = 1990:2016

for place = places
    days = getdays(place)
    outfile = "$path/$place/$place-Landsat_num-$days-obs_eq_0-WGS84.tif"
    ref = gtiffref("$path/$place/$place-1990-Landsat_num-$days-WGS84-cropmask.tif")
    low_obs_areas = zeros(UInt8, ref[:width], ref[:height], length(yrs))
    GC.gc()
    for yr = 1990:2016
        println("$place $yr")
        GC.gc()
        file = "$path/$place/$place-$yr-Landsat_num-$days-WGS84-cropmask.tif"
        temp = readgtiff(file)[1][:, :, 1]
        replace!(filter_number, temp)
        low_obs_areas[:, :, yr-yrs[1]+1] = temp
        temp = nothing
    end
    temp = sum(low_obs_areas, dims=3)
    println("max year ", maximum(temp[temp .<= 27]))
    writegtiff(outfile, low_obs_areas, ref, nthread=8, nodata=0)
end
