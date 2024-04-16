#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AUTHOR: Shen Ruoque
VERSION: v2023.08.29

Calculate planting frequency
"""
#%%
import os, gc
import rasterio
os.chdir(os.path.dirname(__file__))
from gtiffio import *
#%%
places = [
    "Shanghai",
]
yrs = range(1990, 2016+1)

path = "../../classified"

os.chdir(path)

version = "rf1f"

for place in places:
    gc.collect()
    ref = gtiffref(f"classified-{place}-1990-v{version}.tif")

    freq = np.zeros([ref["height"], ref["width"]], dtype=np.uint8)

    for yr in yrs:
        print(place, yr)
        data, _ = readgtiff(f"classified-{place}-{yr}-v{version}.tif")
        freq += data[0, :, :]

    writegtiff(f"frequency-{place}-v{version}.tif", freq, ref, nthread=8, nodata=0)
