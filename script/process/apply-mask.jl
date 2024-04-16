#!/usr/bin/env julia
# -*- coding: utf-8 -*-
# AUTHOR: Shen Ruoque
# VERSION: v2023.12.20

#=
Mask non-cropland pixels in the observation number file.
(Set 255 to non-cropland pixels)
=#

include("../gtiffio.jl")
yrs = 1990:2016
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

cd("../../num_30m")

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

for place in places
    for yr = yrs
        GC.gc()
        println("$place $yr")
        days = getdays(place)
        outfile = "$place/$place-$yr-Landsat_num-$days-WGS84-cropmask.tif"
        if isfile(outfile) continue end
        mask, _ = readgtiff("../../CLCD-crop/$place/CLCD-crop-v01-$place-$yr-WGS84.tif")
        data, ref = readgtiff("$place/$place-$yr-Landsat_num-$days-WGS84.tif")
        data[mask .== 0] .= 255
        writegtiff(outfile, data, ref, nthread=8, nodata=255)
        data = mask = nothing
        GC.gc()
    end
end
