#!/usr/bin/env julia
# -*- coding: utf-8 -*-
# AUTHOR: Shen Ruoque
# VERSION: v2021.12.28
#=
Merge geotiff files downloaded from GEE (in WGS84)
=#
include(joinpath(@__DIR__, "./gtiffio.jl"))

"""
    mergelist(path, flist, outfile)

Merge geotiff files downloaded from GEE (in WGS84),
with the suffix format of "-\\d10-\\d10.tif".

From top-left to bottom-right.

Numbers in the suffix before and after "-"
represent the vertical (height) and horizontal (width), respectively.

If the file suffix does not follow this format,
the merging will be done based on the geographical information of each file.

Required that all files merge into a rectangular area.
"""
function mergelist(path, flist, outfile)
    if length(flist) == 0 error("No input file!") end
    if length(flist) == 1 return mv(joinpath(path, flist[1]), outfile) end
    patterns = [match(r"-(\d+)-(\d+)\.tif", file) for file = flist]
    if any(isnothing.(patterns))
        lefttops = hcat(
            [gtiffref(joinpath(path, file))[:geotransform][[1, 4]] for file = flist]...
        )
        file0 = flist[findmin(sum(lefttops .* [1, -1]; dims=1)[1, :])[2]]
        ref0 = gtiffref(joinpath(path, file0))
        res = ref0[:geotransform][[2, 6]]
        xys = round.(Int, (lefttops .- ref0[:geotransform][[1, 4]]) ./ res)
    else
        xys = hcat(
            [[parse(Int, pattern[2]), parse(Int, pattern[1])] for pattern = patterns]...
        )
        prefix = match(r"(^.+-)\d+-\d+\.tif", flist[1])[1]
        file0= "$(prefix)0000000000-0000000000.tif"
        ref0 = gtiffref(joinpath(path, file0))
    end

    rightdown = maximum(xys, dims=2)
    frightdown = flist[all(xys .== rightdown; dims=1)[1, :] |> findfirst]
    refx = gtiffref(joinpath(path, frightdown))
    ref0[:width], ref0[:height] = rightdown .+ [refx[:width], refx[:height]]
    total = Array{ref0[:dtype]}(undef, ref0[:width], ref0[:height], ref0[:nbands])

    for (i, fname) = enumerate(flist)
        x, y = xys[:, i]
        println(fname)
        data, ref = readgtiff(joinpath(path, fname))
        total[x+1:x+ref[:width], y+1:y+ref[:height], :] = data
    end
    data = nothing

    writegtiff(outfile, total, ref0, bigtiff=true, nthread=8)
end
