// download-sample-ori.js
// download composited images without interpolation and filtering

/**
 * Obtain optical (L5, L7, L8) images with specified band
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
  var collection_L5 = ee.ImageCollection("LANDSAT/LT05/C02/T1_L2")
    .merge(ee.ImageCollection("LANDSAT/LT05/C02/T2_L2"))
    .filter(dateFilter2).filterBounds(studyPlace)
    .map(pre.scaleFactorsLC2).map(pre.renameBandsL7C2)
    .map(pre.rmCloudLC2).map(pre.rmCloudShadowLC2).map(pre.rmSnowLC2)
    ;
  var collection_L7 = ee.ImageCollection("LANDSAT/LE07/C02/T1_L2")
    .merge(ee.ImageCollection("LANDSAT/LE07/C02/T2_L2"))
    .filter(dateFilter2).filterBounds(studyPlace)
    .map(pre.scaleFactorsLC2).map(pre.renameBandsL7C2)
    .map(pre.rmCloudLC2).map(pre.rmCloudShadowLC2).map(pre.rmSnowLC2)
    ;
  var collection_L8 = ee.ImageCollection("LANDSAT/LC08/C02/T1_L2")
    .merge(ee.ImageCollection("LANDSAT/LC08/C02/T2_L2"))
    .filter(dateFilter2).filterBounds(studyPlace)
    .map(pre.scaleFactorsLC2).map(pre.renameBandsL8C2)
    .map(pre.rmCloudLC2).map(pre.rmCloudShadowLC2).map(pre.rmSnowLC2)
    ;
  var collection_opt =
    collection_L5
    .merge(collection_L7)
    .merge(collection_L8)
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

var pre = require("path/to/preprocess");
var At = "Shanghai";
var chinaProvinces = ee.FeatureCollection("path/to/shp/of/china_provinces");
var studyPlace = chinaProvinces.filterMetadata("NAME", "equals", "上海市");

var band2 = ["swir1"];
Map.addLayer(studyPlace, {}, "study place");

for (var yr = 2000; yr <= 2000; yr++) {

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
  description = description + "-Landsat";
  for (var j = 0; j < band2.length; j++) {
    description = description + "_" + band2[j];
  }
  description = description + "-" + start2 + "_" + dStep2 + "_" + end2 + "_" + unit2;

  var compositedImageClip = exports.getCollection(
    dStart2, dEnd2, studyPlace, pre, dStep2, unit2, mask, band2
  ).multiply(1000).toInt16();

  print("compositedImageClip", compositedImageClip);
  Map.addLayer(compositedImageClip.clip(studyPlace), {}, "Image");

  Export.image.toDrive({
    image: compositedImageClip,
    description: description,
    scale: 30,
    fileNamePrefix: description + "-WGS84",
    maxPixels: 1e13,
    region: studyPlace,
    crs: "EPSG:4326",
  });
};
