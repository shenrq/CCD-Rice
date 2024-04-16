// download-sample-ori.js
// download sample time series without interpolation and filtering

/**
 * Obtain optical (S2, L8, L9) images with specified band
 * within a specified time period
 * @param dStart2 Start date for optical
 * @param dEnd2 End date for optical
 * @param {ee.Feature} studyPlace The extent of the study area
 * @param {Function} pre Preprocessing functions
 * @param dStep2 Optical composite
 * @param unit2 Optical composite unit
 * @param {ee.Image} mask Mask
 * @param {List} band2 Optical bands
 * @returns Composited images (times to bands)
 */
exports.getCollection = function (
  dStart2, dEnd2, studyPlace, pre, dStep2, unit2, mask, band2
) {
  var dateFilter2 = ee.Filter.date(
    dStart2.advance(-dStep2, unit2), dEnd2.advance(dStep2, unit2)
  );
  var S2 = ee.ImageCollection('COPERNICUS/S2')
    .filter(dateFilter2).filterBounds(studyPlace);
  var S2C = ee.ImageCollection('COPERNICUS/S2_CLOUD_PROBABILITY')
    .filter(dateFilter2).filterBounds(studyPlace);
  var collection_S2 = pre.indexJoin(S2, S2C, 'cloud_probability')
    .map(pre.scaleFactorsS2).map(pre.maskImage_S2)
    .map(pre.renameBandsS2)
    ;
  var collection_L8 = ee.ImageCollection("LANDSAT/LC08/C02/T1_L2")
    .merge(ee.ImageCollection("LANDSAT/LC08/C02/T2_L2"))
    .filter(dateFilter2).filterBounds(studyPlace)
    .map(pre.scaleFactorsLC2).map(pre.renameBandsL8C2).map(pre.rmCloudLC2)
    ;
  var collection_L9 = ee.ImageCollection("LANDSAT/LC09/C02/T1_L2")
    .merge(ee.ImageCollection("LANDSAT/LC09/C02/T2_L2"))
    .filter(dateFilter2).filterBounds(studyPlace)
    .map(pre.scaleFactorsLC2).map(pre.renameBandsL8C2)
    .map(pre.rmCloudLC2).map(pre.rmCloudShadowLC2).map(pre.rmSnowLC2)
    ;
  var collection_opt =
    collection_S2
    .merge(collection_L8)
    .merge(collection_L9)
    .select(band2)
    ;

  // composte
  var size2 = dEnd2.difference(dStart2, unit2).divide(dStep2).toInt().getInfo();
  var list2 = ee.List.sequence(0, size2-1, 1);
  var collection2 = ee.ImageCollection(list2.map(function (d) {
    var d_start = dStart2.advance(ee.Number(d).multiply(dStep2), unit2);
    var d_end = d_start.advance(dStep2, unit2);
    var collection_opt_ = collection_opt.select(band2).filterDate(d_start, d_end)
      .select(band2).median().clip(studyPlace);
    return ee.Image(ee.Algorithms.If({
      condition: collection_opt_.bandNames().length().neq(1),
      trueCase: ee.Image.constant(0).rename(band2),
      falseCase: collection_opt_
    }));
  }));

  var collection2_ = collection2;

  var result = collection2_.toBands();
  return result.clip(studyPlace).unmask().updateMask(mask);

};

function output (img, select, text) {
  var select_ = img.sampleRegions({
    collection: select,
    properties: ["class", "year"],
    scale: 20,
    geometries: true,
  })
  ;
  Export.table.toDrive({
    collection: select_,
    description: text + "-" + pre.dateTimeStr(),
    folder: "shen-ruoque2",
    fileNamePrefix: text
  });
  return 0;
}

var pre = require("path/to/preprocess");
var At = "Shanghai";

var band2 = ["swir1"];

var select1 = ee.FeatureCollection("path/sample-" + At + "-2017_2022-v1-5000-rice");
var select2 = ee.FeatureCollection("path/sample-" + At + "-2017_2022-v1-10000-other_crop");
var select3 = ee.FeatureCollection("path/sample-edge-" + At + "-2017_2022-v1-500-rice");
var select4 = ee.FeatureCollection("path/sample-edge-" + At + "-2017_2022-v1-1000-other_crop");
Map.addLayer(select1, {}, "select1");

for (var yr = 2017; yr <= 2022; yr++) {
  var select1_ = select1.filterMetadata("year", "equals", yr);
  var select2_ = select2.filterMetadata("year", "equals", yr);
  var select3_ = select3.filterMetadata("year", "equals", yr);
  var select4_ = select4.filterMetadata("year", "equals", yr);
  var chinaProvinces = ee.FeatureCollection("path/to/shp/of/china_provinces");
  var studyPlace = chinaProvinces.filterMetadata("NAME", "equals", "上海市");

  var mask = ee.Image.constant(1);

  var start2 = "1"; var end2 = "361"; var dStep2 = 8; var unit2 = "day";
  var dStart2 = ee.Date.parse("yyyyDDD", yr + start2);
  var dEnd2 = ee.Date.parse("yyyyDDD", yr + end2).advance(dStep2, unit2);

  var size2 = dEnd2.difference(dStart2, unit2).divide(dStep2).toInt().getInfo();
  var n = 0;
  var bands2 = [];
  for (var j = 0; j < band2.length; j++) {
    for (var i = 0; i < size2; i++) {
      bands2[n] = band2[j] + "_" + i.toString(); n += 1;
    }
  }
  var bands = bands2;
  print(bands);
  var description = At + "-" + yr;
  description = description + "-S2_L8_L9";
  for (var j = 0; j < band2.length; j++) {
    description = description + "_" + band2[j];
  }
  description = description + "-" + start2 + "_" + dStep2 + "_" + end2 + "_" + unit2;

  var compositedImageClip = exports.getCollection(
    dStart2, dEnd2, studyPlace, pre, dStep2, unit2, mask, band2
  ).multiply(1000).toInt16();

  Map.addLayer(compositedImageClip, {}, "Image");

  output(compositedImageClip, select1_, description + "-rice");
  output(compositedImageClip, select2_, description + "-other_crop");
  output(compositedImageClip, select3_, description + "-edge-rice");
  output(compositedImageClip, select4_, description + "-edge-other_crop");
}
