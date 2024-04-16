#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AUTHOR: Shen Ruoque
VERSION: v2023.07.14

Merge each year's sample file,
plot a figure of averaged sample time series.
"""
#%%
import os
import pandas as pd
import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt
from matplotlib import rcParams
rcParams["mathtext.fontset"] = "stix"
rcParams["axes.unicode_minus"] = False
rcParams["font.family"] = "Times New Roman"
plt.rcParams["xtick.direction"] = "in"
plt.rcParams["ytick.direction"] = "in"
#%%
path = "../../sample-curve"
os.chdir(path)
place = "Shanghai"
yrs = range(2017, 2022+1)
satellite = "S2_L8_L9"; composite = range(1, 361+8, 8)
band = "swir1"
edge = "-edge"
# edge = ""
comp_str = f"{composite[0]}_{composite.step}_{composite[-1]}_day"
bands = [f"{i}_{band}" for i in range(len(composite))]
scale = 1000
cover = "rice"
# cover = "other_crop"

#%%
sheet = pd.DataFrame()

for yr in yrs:
    temp = pd.read_csv(f"{place}-{yr}-{satellite}_{band}-{comp_str}{edge}-{cover}.csv", na_values=[0])
    temp["year"] = yr
    sheet = pd.concat([sheet, temp], ignore_index=True)

sheet[bands + ["year"]].to_excel(
    f"{place}-{yrs[0]}_{yrs[-1]}-{satellite}_{band}-{comp_str}{edge}-{cover}.xlsx",
    index=False
)
#%%
washed = pd.DataFrame()
na_percents = np.zeros(len(composite))
for i, jday in enumerate(composite):
    temp = pd.DataFrame()
    temp[band] = sheet[f"{i}_{band}"] / scale
    temp[band][temp[band] > 0.4] = pd.NA
    temp[band][temp[band] < 0] = pd.NA
    temp["year"] = sheet["year"]
    temp["jday"] = jday
    na_percents[i] = np.sum(pd.isna(temp[band])) / len(temp) * 100
    washed = pd.concat([washed, temp], ignore_index=True)

washed.dropna(inplace=True)

#%%
fig = plt.figure(figsize=(8, 6), dpi=500, facecolor="white")
cmap = [
    [0, 114, 178],
    [230, 159, 0],
    [0, 158, 115],
    [204, 121, 167],
    [86, 180, 233],
    [213, 94, 0],
    [240, 228, 66],
]
cmap = [[j / 255 for j in i] for i in cmap]
ax = fig.add_subplot(2, 1, 1)
ax = plt.axes([0.070, 0.285, 0.910, 0.700])
sns.lineplot(
    data=washed, x="jday", y="swir1",
    linewidth=0.5, errorbar="sd", color=cmap[2]
)
plt.ylim(-0.02, 0.42); plt.xticks(ticks=composite[::3], labels=[])
plt.xlim(composite[0]-composite.step, composite[-1]+composite.step)
plt.xlabel(""); plt.ylabel("SWIR1")

ax = plt.axes([0.070, 0.065, 0.910, 0.210])
plt.bar(composite, 100 - na_percents, width=0.7 * composite.step, color=cmap[1])
plt.ylim(0, 100); plt.xticks(ticks=composite[::3])
plt.xlim(composite[0]-composite.step, composite[-1]+composite.step)
plt.xlabel("Day of Year"); plt.ylabel("Good Observations %")
plt.savefig(f"averaged-{place}-{yrs[0]}_{yrs[-1]}-{satellite}-{comp_str}{edge}-sample-curve-{cover}.png")
plt.close()
