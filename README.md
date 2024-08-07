# CCD-Rice: A long-term paddy rice distribution dataset in China at 30 m resolution

This repository stores the codes of a rice mapping method used in paper [*CCD-Rice: A long-term paddy rice distribution dataset in China at 30 m resolution*](https://doi.org/10.5194/essd-2024-147).

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

Please refer to the paper for specific methods.

## Notice

Scripts with extension `js` are GEE codes, please copy the codes and run on GEE code editor.

Scripts with extensions `jl` and `py` are codes run in local devices.

The versions of softwares and the some important packages are as follows:

- Julia: 1.10.0
- Python: 3.9.17
- GDAL: 2.3.3
- ArchGDAL (Julia package): 0.10.2
- DatFrames (Julia package): 1.6.1
- StatsBase (Julia package): 0.33.21
- numpy (Python package): 1.24.3
- scikit-learn (Python package): 1.2.2
- pandas (Python package): 1.5.3
- rasterio (Python package): 1.3.2
- opencv-python (Python package): 4.7.0

## Dataset

The distribution maps of rice in China from 1990 to 2016 (CCD-Rice) generated using this method are publicly available on https://doi.org/10.57760/sciencedb.15865.

## Citation

Shen, R., Peng, Q., Li, X., Chen, X., and Yuan, W.: CCD-Rice: A long-term paddy rice distribution dataset in China at 30 m resolution, Earth Syst. Sci. Data Discuss. \[preprint\], https://doi.org/10.5194/essd-2024-147, in review, 2024.

