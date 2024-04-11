# CCD-Rice: A long-term paddy rice distribution dataset in China at 30 m resolution

This repository stores the codes of a rice mapping method.

## Usage

Run scripts in the following sequence.

1. Use `script/preprocess/download-ori.js` to download remote sensing images of each province from GEE (Google Earth Engine).
2. Use `script/preprocess/merge.jl` to merge files that have been sliced by GEE.
3. Use `script/preprocess/CLCD-crop-WGS84-clip.py` to cut CLCD product into range of each province.
4. Use `script/preprocess/apply-mask.jl` to mask the non-cropland pixels in downloaded tiff file.
5. Use `script/preprocess/add-crop-mask.py` to mask non-cropland pixels in resent rice map.
6. Use `script/preprocess/edge-detection.py` to extract pixels in the boundary of rice and non-rice.
7. Use `script/preprocess/pick-sample.jl` to pick training points (normal and edge samples).
8. Use `script/preprocess/download-sample-ori.js` to download sample time series from GEE.
9. Use `script/preprocess/sample-curve.py` to merge downloaded each year's sample file into one file.
10. Use `script/process/count-observations.jl` to count the number of good observations on each pixel in downloaded tiff file.
11. Use `script/process/full-area.jl` to get the full study area of the province, and rewrite the observation number file by setting 255 to pixels out the province' range.
12. Use `script/process/number-distribution.py` count the distribution of good observations in each province.
13. Use `script/process/apply-mask.jl` to mask non-cropland pixels in the observation number file.
14. Use `script/train-data-x.py` to extent the training time series, by randomly delete observations in original training time series.
15. Use `script/process/area-with-0-observation.jl` to extract pixels with o observations of each province each year.
16. Run `script/random-forest.py` to classify rice.
17. Use `script/postprocess/frequency.py` to calculate the plant frequency from rice map.
18. Use `script/postprocess/filter-less-years.py` to eliminate the pixels with low planting years and regenerate the rice map.
19. Use `script/area-time-series-filter.jl` to eliminate unreasonable fluctuations in rice area in a small region and regenerate the rice map.

