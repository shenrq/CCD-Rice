#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AUTHOR: Shen Ruoque
VERSION: v2023.08.09

Extent the training time series.

Randomly delete a certain proportion of values in the sample time series
to simulate the more severe cloud contamination.
The proportion of deletion is determined by
the distribution of good observations from 1990 to 2016 in the province,
to make the proportion of missing values in the sample time series after deletion
consistent with the proportion from 1990 to 2016.
"""
#%%
import pandas as pd
import os
import numpy as np
#%%
def extent_train(sheet0, fraction, proportion):
    """
    Extent the training time series.

    Parameters
    ----------
    sheet0: original training time series
    fraction: fraction to delete
    proportion: proption of samples picked from origional sheet
    """
    num0 = len(sheet0)
    choice0 = np.random.choice(num0, np.round(num0 * proportion).astype(int), replace=False)
    sheet = sheet0.iloc[choice0].copy().reset_index(drop=True)
    num = len(sheet)
    for i in bands0:
        choice = np.random.choice(
            num, np.round(num * fraction).astype(int), replace=False
        )
        sheet.loc[choice, i] = np.nan
    return sheet

def count_proption(sheet0, fracdist0):
    fracdist = fracdist0.copy()
    usedsheet = sheet0[bands1].to_numpy()
    validfrac = 1 - np.sum(np.isnan(usedsheet)) / usedsheet.size

    fracs = np.linspace(0, 1, fracdist.size)
    reduceprops = 1 - fracs / validfrac
    condition = (fracdist > 0.02) & (reduceprops < 1) & (reduceprops > 0)
    fracdist = fracdist[condition]
    reduceprops = reduceprops[condition]

    return fracdist, reduceprops

#%%
place = "Shanghai"
composite1 = range(73, 289+8, 8)
band = "swir1"
edge = "-edge"
# edge = ""
covers = [
    "rice",
    "other_crop",
]
yrstr = "2017_2022"
composite0 = range(1, 361+8, 8)
comp_str0 = f"{composite0[0]}_{composite0.step}_{composite0[-1]}_day"
bands0 = [f"{(i - 1) // 8}_{band}" for i in composite0]
bands1 = [f"{(i - 1) // 8}_{band}" for i in composite1]

#%%
actualvalid = pd.read_csv(f"../num_30m/{place}-all-observation-frequency.csv")
fracdist0 = np.mean(actualvalid.to_numpy(), axis=1)

#%%
sample_path = "../sample-curve"

for cover in covers:
    print(cover)
    sheet0 = pd.read_excel(os.path.join(
        sample_path, f"{place}-{yrstr}-S2_L8_L9_swir1-1_8_361_day{edge}-{cover}.xlsx"
    ))

    fracdist, reduceprops = count_proption(sheet0, fracdist0)

    sheet = pd.DataFrame()
    fracall = np.sum(fracdist)
    for i in range(fracdist.size):
        sheet = pd.concat([sheet, extent_train(
            sheet0, reduceprops[i], min(1, fracdist[i] * 3 / fracall)
        )], ignore_index=True)

    sheet.to_excel(os.path.join(
        sample_path, f"{place}-x-S2_L8_L9_swir1-1_8_361_day{edge}-{cover}.xlsx"
    ), index=False)
