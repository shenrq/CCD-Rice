#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AUTHOR: Shen Ruoque
VERSION: v2023.08.30

Some fragmented patches in the rice map.

To eliminate these patches,
assumed that rice must be cultivated for more than 5 years.
Extract pixels from the planting frequency map with planting years ≥ 5 years,
and use this as a mask to eliminate pixels with shorter planting years for re-identification.

For the first five years and the last five years,
relaxed the requirement and only required that
the planting years be greater than or equal to the distance between that year and 1990 or 2016.
"""
#%%
import os
import rasterio
import yaml
import multiprocessing as mp
os.chdir(os.path.dirname(__file__))
from gtiffio import *
import warnings
warnings.filterwarnings("ignore")
#%%
place = "Shanghai"
area_file = "../area.yaml"
yrs = range(1990, 2016+1)

path = "../../classified"

os.chdir(path)
version = "rf1f"
maxnum = 5

#%%
freq, ref = readgtiff(f"frequency-{place}-v{version}.tif")

def filter_less(yr):
    prob, _ = readgtiff(f"prob-{place}-{yr}-v{version}.tif")
    to_edge = min(yr - 1990, 2016 - yr)
    filter_num = min(maxnum, to_edge)
    print(yr, filter_num)
    mask = freq > filter_num
    prob = prob * mask
    writegtiff(f"prob-{place}-{yr}-v{version}-2.tif", prob, ref, nthread=8)
    return 0

pools = mp.Pool(min(len(yrs), 5))
status = pools.map(filter_less, yrs)
pools.close()
pools.join()

#%%
def recognize(yr):
    print(yr)
    outfile = f"{path}/classified-{place}-{yr}-v{version}-2.tif"
    probfile = f"{path}/prob-{place}-{yr}-v{version}-2.tif"
    area = yaml.safe_load(open(area_file))[place][yr]
    status = os.system(
        "julia ../recognize-simple.jl " +
        f"{probfile} {area} WGS84 {outfile}"
    )
    return status

pools = mp.Pool(min(len(yrs), 6))
status = pools.map(recognize, yrs)
pools.close()
pools.join()
