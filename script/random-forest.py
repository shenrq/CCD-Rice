#!/usr/bin/env python3
# -*- encoding: utf-8 -*-
"""
AUTHOR : Shen Ruoque
VERSION : v2023.07.16

Using Random Forest Classifier to classify rice and non-rice.
"""
#%%
from sklearnex import patch_sklearn
patch_sklearn()
import numpy as np
import os
import yaml
import rasterio
import multiprocessing as mp
from sklearn.ensemble import RandomForestClassifier
import pandas as pd
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

def writegtiff(file, data, ref, compress="DEFLATE", bigtiff=False, nthread=None):
    ref["count"] = data.shape[0]
    ref["dtype"] = data.dtype
    if compress is not None: ref["compress"] = compress; ref["tiled"] = True
    if bigtiff: ref["BIGTIFF"] = "YES"
    if nthread is not None: ref["NUM_THREADS"] = nthread
    with rasterio.open(file, "w", driver="GTiff", **ref) as ds:
        ds.write(data)
    return 0

def classify_train(X, y):
    rf_model = RandomForestClassifier() # default
    rf_model.fit(X, y)
    return rf_model

#%%
irice = 1
inon_mr = 0
#%%
place = "Shanghai"
band = "swir1"
composite1 = range(97, 289+8, 8)
comp_str1 = f"{composite1[0]}_{composite1.step}_{composite1[-1]}_day"
bands1 = [f"{(i - 1) // 8}_{band}" for i in composite1]
outtype = "prob" # return probability using model
# outtype = "classified" # directly return classified result
outpath = "../classified"
version = "rf1"
yrs = range(1990, 2016+1)

#%%
def read_curve(file, cover):
    sample_path = "../sample-curve/"
    sample_curve = pd.read_excel(os.path.join(
        sample_path, file
    ))
    sample_curve["class"] = cover
    return sample_curve

place1 = "Liaoning" if place in ["Tianjin", "Hebei"] else place

curve1_1 = read_curve(f"{place1}-2017_2022-S2_Landsat_swir1-1_8_361_day-other_crop.xlsx", inon_mr)
curve1_2 = read_curve(f"{place1}-2017_2022-S2_Landsat_swir1-1_8_361_day-rice.xlsx", irice)
curve1_3 = read_curve(f"{place1}-2017_2022-S2_Landsat_swir1-1_8_361_day-edge-other_crop.xlsx", inon_mr)
curve1_4 = read_curve(f"{place1}-2017_2022-S2_Landsat_swir1-1_8_361_day-edge-rice.xlsx", irice)
curve2_1 = read_curve(f"{place1}-x-S2_Landsat_swir1-1_8_361_day-other_crop.xlsx", inon_mr)
curve2_2 = read_curve(f"{place1}-x-S2_Landsat_swir1-1_8_361_day-rice.xlsx", irice)
curve2_3 = read_curve(f"{place1}-x-S2_Landsat_swir1-1_8_361_day-edge-other_crop.xlsx", inon_mr)
curve2_4 = read_curve(f"{place1}-x-S2_Landsat_swir1-1_8_361_day-edge-rice.xlsx", inon_mr)

curve1 = pd.concat([
    curve1_1, curve1_2, curve1_3, curve1_4, curve2_1, curve2_2, curve2_3, curve2_4
], ignore_index=True)
del curve1_1, curve1_2, curve1_3, curve1_4, curve2_1, curve2_2, curve2_3, curve2_4

#%%
y = np.uint8(curve1["class"].to_numpy())
X = np.uint16(curve1[bands1].to_numpy())
del curve1
valid = np.any(X != 0, axis=1)
X = X[valid, :]; y = y[valid]
trained = classify_train(X, y)

def get_predicted(batch):
    return trained.predict(batch)

def get_prob(batch):
    return trained.predict_proba(batch)[:, irice]

#%%
for yr in yrs:
    print(yr)
    outfile = f"{outpath}/{outtype}-{place}-{yr}-v{version}.tif"
    if os.path.isfile(outfile): continue
    tif_path = f"../swir1_30m/{place}/{yr}"
    os.chdir(tif_path)
    data1, ref = readgtiff(f"{place}-{yr}-Landsat_swir1-{comp_str1}-WGS84-2.tif")
    data = data1
    valid = np.any(data1 != 0, axis=0)
    index = np.where(valid)
    validnum = index[0].size
    data = data[:, index[0], index[1]]
    del data1

    bsize = 1000000
    batches = [data[:, i*bsize:min(validnum, (i+1)*bsize)].T for i in range(validnum // bsize + 1)]

    pools = mp.Pool(60)
    predicted = pools.map(get_prob if outtype == "prob" else get_predicted, batches)
    del batches, data
    pools.close()
    pools.join()

    predicted = np.hstack(predicted)
    classified = np.float32(valid) if outtype == "prob" else np.uint8(valid)
    classified[index[0], index[1]] = predicted
    writegtiff(outfile, classified[np.newaxis, :, :], ref, nthread=8)
    del classified, valid, index

#%%
status = os.system(
    "julia -t 20 ./fill-zero-observation.jl " +
    f"{place} {version}"
)

#%%
if outtype == "prob":
    def recognize(yr):
        print(yr)
        outfile = f"{outpath}/classified-{place}-{yr}-v{version}f.tif"
        if os.path.isfile(outfile): return 0
        probfile = f"{outpath}/prob-{place}-{yr}-v{version}f.tif"
        area = yaml.safe_load(open("./area.yaml"))[place][yr]
        status = os.system(
            "julia ./recognize-simple.jl " +
            f"{probfile} {area} WGS84 {outfile}"
        )
        return status

    pools = mp.Pool(min(len(yrs), 6))
    status = pools.map(recognize, yrs)
    pools.close()
    pools.join()
