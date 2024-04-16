#!/usr/bin/env julia
# -*- coding: utf-8 -*-
# AUTHOR: Shen Ruoque
#=
Pick N points from the resent rice map,
considering them as rice and non-rice, respectively,
convert them into coordinates.
=#
using Base.Threads
using Printf, JSON
import ArchGDAL as AG
using DataFrames, CSV
include("../gtiffio.jl")
using Random
using StatsBase


function coords2geojson(fname, coordinates0, class)
    prestring = """{"type":"Feature","properties":{"class":"$class"},""" *
        """"geometry":{"type":"Point","coordinates":"""
    open(fname, "w") do f
        write(f, """{"type":"FeatureCollection","features":[\n""")
        coordinates = [@sprintf "[%4.15f, %4.15f]" i[1] i[2] for i = coordinates0]
        for (i, coordinate) = enumerate(coordinates[1:end-1])
            write(f, prestring * "$coordinate}},\n")
        end
        write(f, prestring * "$(coordinates[end])}}\n]}")
    end
    fname
end

function albers2wgs84(infie, outfile)
    albers = "+proj=aea +lat_0=0 +lon_0=105 +lat_1=25 +lat_2=47" *
        " +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs +type=crs"
    run(`ogr2ogr -s_srs $albers -t_srs 'EPSG:4296' $outfile $infie`)
    outfile
end

function geojson2csv(infile, outfile)
    features = open(infile, "r") do f
        JSON.parse(f)["features"]
    end
    open(outfile, "w") do f
        write(f, "class,longitude,latitude\n")
        for i in features
            lonlat = i["geometry"]["coordinates"]
            class = i["properties"]["class"]
            write(f, "$class,$(lonlat[1]),$(lonlat[2])\n")
        end
    end
    outfile
end

function df2geojson(sheet, outfile)
    prestring = (class, yr) -> ("""{"type":"Feature","properties":{"class":"$class","year":$yr},""" *
        """"geometry":{"type":"Point","coordinates":""")
    open(outfile, "w") do f
        write(f, """{"type":"FeatureCollection","features":[\n""")
        for i in eachrow(sheet[1:end-1, :])
            coordinate = @sprintf("[%4.15f, %4.15f]", i[:longitude], i[:latitude])
            write(f, prestring(i[:class], i[:year]) * "$coordinate}},\n")
        end
        coordinate = @sprintf("[%4.15f, %4.15f]", sheet[end, :longitude], sheet[end, :latitude])
        write(f, prestring(sheet[end, :class], sheet[end, :year]) * "$coordinate}}\n]}")
    end
    outfile
end


"""
    coords2list(fname0, coordinates, class)

coordinates to geojson file
"""
function coords2list(fname0, coordinates0, class)
    fname = coords2geojson(fname0 * ".geojson", coordinates0, class)
    fname2 = geojson2csv(fname, fname0 * ".csv")
    if isfile(fname) rm(fname) end
    fname2
end

"""
    picksample(place, yr, version, pixnum, infile, sample_path, cover)

Read resent rice map, pick samples.
"""
function picksample(place, yr, version, pixnum, infile, sample_path, cover)
    fout = "sample-$place-$yr-v$version-$(pixnum)"

    classified, ref = readgtiff(infile)
    geotrans = ref[:geotransform]
    tot_cover_id = findall(classified[:, :, 1] .== cover.second)

    if length(tot_cover_id) < pixnum error("Pixcel number not enough!") end
    cover_id = sample(tot_cover_id, pixnum; replace=false)

    pick_cover = [[
        geotrans[1] + (i[1] - 1 + 0.5) * geotrans[2],
        geotrans[4] + (i[2] - 1 + 0.5) * geotrans[6],
    ] for i = cover_id]
    coords2list(
        joinpath(sample_path, "$fout-$(cover.first)"), pick_cover, cover.second
    )
end

places = [
    "Shanghai",
]

version = "1"
# prefix = "edge"
prefix = "classified"
path = prefix == "edge" ? prefix : "masked"
inpath = "../../$path/distribution_map/"
sample_path = "../../sample/"

pixnums = Dict(
    "other_crop" => 1_0000, "rice" => 5_000
)
codes = Dict(
    "other_crop" => 0, "rice" => 1
)


for place = places
    println(place)
    for cover = keys(codes)
        pixnum = pixnums[cover]
        sheet = DataFrame()

        @threads for yr = 2017:2022
            infile = joinpath(inpath, "$prefix-$place-$yr-middle_rice-WGS84-v$version-cropmask.tif")
            picksample(place, yr, version, pixnum, infile, sample_path, cover => codes[cover])
        end

        for yr = 2017:2022
            fname = joinpath(sample_path, "sample-$place-$yr-v$version-$(pixnum)-$cover.csv")
            sheet_yr = CSV.read(fname, DataFrame; delim=",")
            if isfile(fname) rm(fname) end
            sheet_yr[!, :year] .= yr
            append!(sheet, sheet_yr)
        end
        outfile = joinpath(
            sample_path,
            (prefix == "edge" ? "sample-edge" : "sample") *
            "-$place-2017_2022-v$version-$(pixnum)-$cover"
        )
        CSV.write(outfile * ".csv", sheet; delim=",")
        df2geojson(sheet, outfile * ".geojson")
    end
end
