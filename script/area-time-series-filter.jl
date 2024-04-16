#!/usr/bin/env julia
# -*- coding: utf-8 -*-
# AUTHOR: Shen Ruoque
# VERSION: v2024.01.07
#=
The county-level area of the rice map is unstable,
with unreasonable fluctuations between years.

Divide the rice map into blocks of 1000 pixels × 1000 pixels,
calculate the rice area for each grid for each year,
and applya low-pass filtering (5-year sliding average) to the areas.

Regenerate the rice map using the filtered area as threshold.
=#
using Base.Threads
using NaNStatistics
include("./gtiffio.jl")

cd("../classified")
place = "Shanghai"
version = "rf1f-2"
blocksize = 1000
yrs = 1990:2016

function recognize(dist, pixnum, rev=true)
    if pixnum == 0 return fill(false, size(dist)...) end
    valid = dist .≠ 0
    validnum = sum(valid)
    if validnum < pixnum return valid end
    sorted = sort(dist[valid][:]; rev=rev)
    threshold = sorted[pixnum]
    rev ? dist .≥ threshold : dist .≤ threshold
end

version1 = replace(version, r"c$" => "")

infiles = ["classified-$place-$yr-v$version.tif" for yr in yrs]
probfiles = ["prob-$place-$yr-v$(version1).tif" for yr in yrs]
outfiles = ["classified-$place-$yr-v$(version)x.tif" for yr in yrs]

ref = gtiffref(infiles[1])
width = ref[:width]
height = ref[:height]

xlen = width ÷ blocksize + 1
ylen = height ÷ blocksize + 1

xys = [(x, y) for y in 1:ylen for x in 1:xlen]

areas1 = zeros(UInt32, xlen, ylen, length(yrs))

for (i, infile) in enumerate(infiles)
    GC.gc()
    println("read $infile")
    data, _ = readgtiff(infile)
    @threads for xy in xys
        x, y = xy
        xid1 = (x - 1) * blocksize + 1
        xid2 = min(x * blocksize, width)
        yid1 = (y - 1) * blocksize + 1
        yid2 = min(y * blocksize, height)
        areas1[x, y, i] = sum(data[xid1:xid2, yid1:yid2, 1] .== 1)
    end
end

for y in 1:ylen
    for x in 1:xlen
        areas1[x, y, :] = round.(UInt32, movmean(areas1[x, y, :], 5))
    end
end

for (i, probfile) in enumerate(probfiles)
    GC.gc()
    println(probfile)
    prob, _ = readgtiff(probfile)
    newmap = zeros(UInt8, width, height)
    @threads for xy in xys
        x, y = xy
        xid1 = (x - 1) * blocksize + 1
        xid2 = min(x * blocksize, width)
        yid1 = (y - 1) * blocksize + 1
        yid2 = min(y * blocksize, height)

        if areas1[x, y, i] == 0 continue end
        newmap[xid1:xid2, yid1:yid2] = recognize(
            prob[xid1:xid2, yid1:yid2, 1], areas1[x, y, i]
        )
    end
    writegtiff(outfiles[i], newmap, ref, nthread=8)
end
