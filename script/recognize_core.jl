#!/usr/bin/env julia
# -*- coding: utf-8 -*-
# AUTHOR: Shen Ruoque
# VERSION: v2021.12.14
#=
Use province-level statistical area to
determin the threshold of probability to get classification map.
(Core function)
=#

@doc raw"""
    gridarea(Δφ, Δθ, θ)

caluculate grid's area (m²).

```math
Area = \int_{\varphi}^{\varphi + \Delta\varphi} \int_{\theta}^{\theta+\Delta\theta}
R \cos\theta \mathrm{d}\varphi R \mathrm{d}\theta
= R^2 \Delta\varphi[\sin(\theta + \Delta\theta) - \sin\theta]
```

Arguments:

- `Δφ`: resolution of longitude (degrees east)
- `Δθ`: resolution of latitude (degrees north)
- `θ`: latitude of the top of the grid (degree)
"""
function gridarea(Δφ, Δθ, θ) :: Float64
    R = 6371008.8
    abs(R ^ 2 * deg2rad(Δφ) * (sind(θ + Δθ) - sind(θ)))
end

"""
    recgnize(dist, ref, croparea, validmax=nothing; proj)

Recognize crop planting place. Returns the threshold and the classified map.

Arguments:

- dist: distance matrix, contains the similaraty of crop
- ref: georeference
- croparea: planting area of the crop (m²)
- validmax: the maximum (or minimum if rev = `true`) posible distance value for the identified crop
- proj: projection (ALBERS or WGS84), string
"""
function recognize(dist, ref, croparea, validmax=nothing; proj, rev=false, mergesort=true)
    if croparea == 0 return NaN, zeros(Bool, size(dist)...) end
    if proj == "ALBERS"
        pixarea = abs(ref[:geotransform][2] * ref[:geotransform][6])
        pixnum = floor(Int, croparea / pixarea)
        sorted = sort(dist[.!isnan.(dist) .& (dist .≠ 0)][:]; rev=rev)
        threshold = sorted[pixnum]
        threshold, rev ? dist .≥ threshold : dist .≤ threshold
    elseif proj == "WGS84"
        _, Δφ, _, θ0, _, Δθ = ref[:geotransform]
        θ = [θ0 + (i - 1) * Δθ for i = 1:ref[:height]]
        pixareas = repeat(gridarea.(Δφ, Δθ, θ), 1, ref[:width])'
        minnum = floor.(Int, croparea / gridarea(Δφ, Δθ, minimum(abs.(θ))))
        maxnum = ceil.(Int, croparea / gridarea(Δφ, Δθ, maximum(abs.(θ))))
        valid0 = .!isnan.(dist) .& (dist .≠ 0)
        if sum(valid0) < maxnum return 0, valid0 end
        # pixels with probability greater than (or less than, if rev is true ) validmax
        # are not involved in sorting to save computation time.
        if isnothing(validmax)
            valid = valid0
        else
            if rev
                valid = dist .> validmax
                while sum(valid) < maxnum # Adaptive expansion
                    validmax -= abs(validmax)
                    valid = dist .> validmax
                end
            else
                valid = dist .< validmax
                while sum(valid) < maxnum # Adaptive expansion
                    validmax += abs(validmax)
                    valid = dist .< validmax
                end
            end
        end
        distvalid = dist[valid]
        pixareas = pixareas[valid]
        println("number of valid pixels: $(sum(valid))")
        println("maximum number of crop pixels: $maxnum")
        valid = nothing
        # Use Merge sort, faster than Quick sort, don't know why
        if mergesort
            order = sortperm(distvalid, alg=MergeSort; rev=rev)[1:maxnum]
        else
            order = sortperm(distvalid; rev=rev)[1:maxnum]
        end
        distpixarea = pixareas[order]
        pixareas = nothing
        println("sort")
        GC.gc()
        threshold = []
        accum = sum(distpixarea[1:minnum-1])
        for i = minnum:maxnum
            accum += distpixarea[i]
            if accum > croparea
                threshold = distvalid[order[i-1]]
                break
            end
        end
        threshold, rev ? dist .≥ threshold : dist .≤ threshold
    end
end
