#!/usr/bin/env julia -p 4
# -*- coding: utf-8 -*-
# AUTHOR: Shen Ruoque
#=
Merge files that have been sliced by GEE.
=#
using Distributed
addprocs(5)
@everywhere rsindex = "swir1"
@everywhere satellite, composite, prcs = "Landsat", "97_8_217_day", ""
@everywhere include("./mergelist.jl")
@everywhere cd("../../$(rsindex)_30m/")
@everywhere function isfname(place, yr, rsindex, fname)
    isfile(fname) &&
    occursin("$place-$yr-$(satellite)_$rsindex-$composite$prcs-W", fname)
end

@sync @distributed for yr = 1990:2016
    place = "Shanghai"
    path = "./$place/$yr"
    flist = [i for i = readdir(path) if isfname(place, yr, rsindex, joinpath(path, i))]
    outfile = "$place-$yr-$(satellite)_$rsindex-$composite$prcs-WGS84.tif"
    mergelist(path, flist, joinpath(path, outfile))
    [rm(joinpath(path, file)) for file = flist if file ≠ outfile]
    GC.gc()
end

rmprocs(workers())
