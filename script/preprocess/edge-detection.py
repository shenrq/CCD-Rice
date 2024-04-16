#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AUTHOR: Shen Ruoque
VERSION: v2023.08.02

Use the Canny algorithm provided by OpenCV to
perform edge detection on the rice map,
obtaining pixels at the boundary between rice and non-rice areas,
which are used to extract edge pixels for model training.
"""
#%%
import os
import cv2
import numpy as np
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
place = "Shanghai"

inpath = f"../../masked/distribution_map/"
outpath = f"../../edge/distribution_map/"

for yr in range(2017, 2022+1):
    print(yr)
    infile = os.path.join(inpath, f"classified-{place}-{yr}-middle_rice-WGS84-v1-cropmask.tif")
    outfile = os.path.join(outpath, f"edge-{place}-{yr}-middle_rice-WGS84-v1-cropmask.tif")
    if os.path.isfile(outfile): continue
    data, ref = readgtiff(infile)
    data = data[0, :, :]
    data1 = np.uint8(data != 1)
    edge = cv2.Canny(data1, 0, 1)
    data[edge <= 0] = 2
    writegtiff(outfile, data[np.newaxis, :, :], ref, nthread=8)
