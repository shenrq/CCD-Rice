#!/usr/bin/env julia
# -*- coding: utf-8 -*-
# AUTHOR: Shen Ruoque
# VERSION: v2023.11.23
#=
Get the full study area of the province,
and rewrite the observation number file by
setting 255 to pixels out the province' range.
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
    # "Hebei",
    # "Tianjin"
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

path = "../../num_30m"

for place = places
    days = getdays(place)
    ref = gtiffref("$path/$place/$place-1990-Landsat_num-$days-WGS84.tif")
    full_area = zeros(Bool, ref[:width], ref[:height])
    GC.gc()
    outfile = "$path/$place/$place-full_area-WGS84.tif"
    for yr in 1990:2016
        println("$place $yr")
        GC.gc()
        file = "$path/$place/$place-$yr-Landsat_num-$days-WGS84.tif"
        data = readgtiff(file)[1][:, :, 1]
        full_area .|= data .≠ 0
    end
    writegtiff(outfile, UInt8.(full_area), ref, nthread=8, nodata=0)

    for yr in 1990:2016
        println("$place $yr rewrite")
        GC.gc()
        file = "$path/$place/$place-$yr-Landsat_num-$days-WGS84.tif"
        data = readgtiff(file)[1][:, :, 1]
        data[.!full_area] .= 255
        writegtiff(file, UInt8.(data), ref, nthread=8, nodata=255)
    end
end
