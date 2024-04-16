#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AUTHOR: Shen Ruoque
VERSION: v2023.08.07

Mask non-cropland pixels in resent rice map.
(Set the values of non-cropland pixels to 2).
"""
#%%
import os
import multiprocessing as mp
import rasterio
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
res20 = 0.000179663056823904
res10 = 0.000089831528412
res = res10
vecpath = "../../boundary/province2017"
places = [
    "Shanghai",
]
maskpath = "../../fromglc10_2017v01/cropland"
inpath = f"../../distribution_map"
outpath = f"../../masked/distribution_map"

for place in places:
    maskfile = f"{outpath}/{place}-cropland-WGS84-20m.tif"
    if not os.path.isfile(maskfile):
        ref0 = gtiffref(f"{inpath}/classified-{place}-2019-middle_rice-WGS84-v1.tif")
        transform = ref0["transform"]
        res = transform[0]
        left = transform[2]
        right = left + res * ref0["width"]
        top = transform[5]
        bottom = top - res * ref0["height"]
        tif_range = f"{left} {bottom} {right} {top}"
        os.system(
            f"gdalwarp -tr {res} {res} -r max " +
            f"-te {tif_range} -te_srs EPSG:4326 -multi -of GTiff " +
            "-co COMPRESS=DEFLATE -co PREDICTOR=2 -co ZLEVEL=9 -co NUM_THREADS=20 " +
            f"{maskpath}/{place}-cropland-WGS84.tif " +
            f"{outpath}/{place}-cropland-WGS84-20m.tif"
        )
    def call_mask(yr):
        print(yr)
        data, ref = readgtiff(f"{inpath}/classified-{place}-{yr}-middle_rice-WGS84-v1.tif")
        mask, _ = readgtiff(f"{outpath}/{place}-cropland-WGS84-20m.tif")
        data[mask != 1] = 2
        writegtiff(
            f"{outpath}/classified-{place}-{yr}-middle_rice-WGS84-v1-cropmask.tif",
            data, ref
        )
        del mask, data
    yrs = range(2017, 2022+1)
    pool = mp.Pool(len(yrs))
    pool.map(call_mask, yrs)
    pool.close()
    pool.join()
