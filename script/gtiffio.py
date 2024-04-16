#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AUTHOR: Shen Ruoque
VERSION: v2023.08.23
"""
import rasterio
import numpy as np
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

def writegtiff(file, data, ref0, compress="DEFLATE", bigtiff=False, nodata=None, nthread=None):
    ref = ref0.copy()
    if data.ndim == 2: data = data[np.newaxis, :, :]
    ref["count"] = data.shape[0]
    ref["dtype"] = data.dtype
    if compress is not None: ref["compress"] = compress; ref["tiled"] = True
    if bigtiff: ref["BIGTIFF"] = "YES"
    if nodata is not None: ref["nodata"] = nodata
    if nthread is not None: ref["NUM_THREADS"] = nthread
    with rasterio.open(file, "w", driver="GTiff", **ref) as ds:
        ds.write(data)
    return file
