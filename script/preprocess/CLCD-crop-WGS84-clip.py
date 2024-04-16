#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AUTHOR: Shen Ruoque
VERSION: v2023.08.02


Extract cropland pixels from the CLCD product (Yang and Huang, 2021),
resample to WGS84,
clip out cropland for each province
according to the range of each province's downloaded tiff file.
Used for mask the downloaded images.
"""
#%%
import os
import rasterio
import numpy as np
import multiprocessing as mp
#%%
def gtiffref(file):
    with rasterio.open(file) as ds:
        ref = {
            "width": ds.width,
            "height": ds.height,
            "count": ds.count,
            "dtype": ds.dtypes[0],
            "transform": ds.transform,
            "crs": ds.crs,
        }
    return ref

def readgtiff(file):
    with rasterio.open(file) as ds:
        data = ds.read()
    return data, gtiffref(file)

def writegtiff(file, data, ref, compress="DEFLATE", bigtiff=False, nodata=None, nthread=None):
    ref["count"] = data.shape[0]
    ref["dtype"] = data.dtype
    if compress is not None: ref["compress"] = compress; ref["tiled"] = True
    if bigtiff: ref["BIGTIFF"] = "YES"
    if nodata is not None: ref["nodata"] = nodata
    if nthread is not None: ref["NUM_THREADS"] = nthread
    with rasterio.open(file, "w", driver="GTiff", **ref) as ds:
        ds.write(data)
    return file

#%%
oripath = "/path/to/CLCD" # download from https://doi.org/10.5281/zenodo.8176941
outpath = "../../CLCD-crop"

for yr in range(1990, 2021+1):
    orifile = f"CLCD_v01_{yr}_albert.tif"
    outfile = os.path.join(outpath, f"CLCD-crop_v01_{yr}_albert.tif")
    if os.path.isfile(outfile):continue
    print(yr)
    data, ref = readgtiff(os.path.join(oripath, orifile))
    data = np.uint8(data == 1)
    writegtiff(outfile, data, ref, nthread=8)

#%%
def clip_CLCD(yr, place, res, tif_range):
    print(yr)
    albers = (
        "+proj=aea +lat_0=0 +lon_0=105 +lat_1=25 +lat_2=47 " +
        "+x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs +type=crs"
    )
    inpath = "../../CLCD-crop"
    infile = os.path.join(inpath, f"CLCD-crop_v01_{yr}_albert.tif")

    outpath = f"{inpath}/{place}"
    outfile = os.path.join(outpath, f"CLCD-crop-v01-{place}-{yr}-WGS84.tif")
    if os.path.isfile(outfile): return 1

    os.system(
        f"gdalwarp -s_srs '{albers}' -t_srs EPSG:4326 -tr {res} {res} -r near " +
        f"-te {tif_range} -te_srs EPSG:4326 -multi -of GTiff " +
        "-co COMPRESS=DEFLATE -co PREDICTOR=2 -co ZLEVEL=9 -co NUM_THREADS=20 " +
        f"{infile} {outfile}"
    )
    return 0

place = "Shanghai"
ref0 = gtiffref(
    f"../../swir1_30m/{place}/1990/{place}-1990-Landsat_swir1-97_8_289_day-WGS84.tif"
)
transform = ref0["transform"]
res = transform[0]
left = transform[2]
right = left + res * ref0["width"]
top = transform[5]
bottom = top - res * ref0["height"]
tif_range = f"{left} {bottom} {right} {top}"

def clip(yr):
    return clip_CLCD(yr, place, res, tif_range)

pools = mp.Pool(4)

status = pools.map(clip, range(1990, 2021+1))
pools.close()
pools.join()
