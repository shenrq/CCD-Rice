#!/usr/bin/env julia
# -*- coding: utf-8 -*-
# AUTHOR: Shen Ruoque
# VERSION: v2023.07.28

#=
Mask non-cropland pixels in downloaded images using CLCD product.
=#

include("../gtiffio.jl")
yrs = 1990:2016
place = "Shanghai"
cd("../../swir1_30m/$place")
composite = "97_8_289_day"

for yr = yrs
    GC.gc()
    println(yr)
    outfile = "$yr/$place-$yr-Landsat_swir1-$composite-WGS84-2.tif"
    if isfile(outfile) continue end
    mask, _ = readgtiff("../..//CLCD-crop/$place/CLCD-crop-v01-$place-$yr-WGS84.tif")
    data, ref = readgtiff("$yr/$place-$yr-Landsat_swir1-$composite-WGS84.tif")
    data .*= mask
    writegtiff(outfile, data, ref, nthread=8)
    data = mask = nothing
    GC.gc()
end
