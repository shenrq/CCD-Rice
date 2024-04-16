// preprocess.js

/**
Rename bands of Sentinel-2

https://developers.google.com/earth-engine/datasets/catalog/COPERNICUS_S2
*/
exports.renameBandsS2 = function(img) {
  return img.rename([
    "aerosol", "blue", "green", "red",
    "re1", // Red Edge 1
    "re2", // Red Edge 2
    "re3", // Red Edge 3
    "nir", // Is this nir equal to landsat nir?
    "re4", // Red Edge 4
    "wv", // Water vapor
    "cirrus",
    "swir1", "swir2",
    "qa10", "qa20", // Always empty
    "qa60" // QA Bitmask
  ]);
};
/**
name bands of Sentinel-2_SR

https://developers.google.com/earth-engine/datasets/catalog/COPERNICUS_S2_SR
*/
exports.renameBandsS2_SR = function(img) {
  return img.select("B.+|QA.+").rename([
    "aerosol", "blue", "green", "red",
    "re1", // Red Edge 1
    "re2", // Red Edge 2
    "re3", // Red Edge 3
    "nir", // Is this nir equal to landsat nir?
    "re4", // Red Edge 4
    "wv", // Water vapor
    "swir1", "swir2",
    "qa10", "qa20", // Always empty
    "qa60" // QA Bitmask
  ]);
};

// Join two collections on their 'system:index' property.
// The propertyName parameter is the name of the property
// that references the joined image.
exports.indexJoin = function (collectionA, collectionB, propertyName) {
  var joined = ee.ImageCollection(ee.Join.saveFirst(propertyName).apply({
    primary: collectionA,
    secondary: collectionB,
    condition: ee.Filter.equals({
      leftField: 'system:index',
      rightField: 'system:index'})
  }));
  // Merge the bands of the joined image.
  return joined.map(function(image) {
    return image.addBands(ee.Image(image.get(propertyName)));
  });
};

/**
Cloud mask S2 using S2_CLOUD_PROBABILITY product

https://developers.google.com/earth-engine/datasets/catalog/COPERNICUS_S2_CLOUD_PROBABILITY
*/
exports.maskImage_S2 = function (image) {
  var s2c = image.select('probability');
  var cirrus = image.select('B10').multiply(0.0001);

  var isCloud = s2c.gt(50).or(cirrus.gt(0.01));

  return image.select("B.+|QA.+").updateMask(isCloud.not());
};

/**
Applies scaling factors for Landsat5/7/8 Collection2

https://developers.google.com/earth-engine/datasets/catalog/LANDSAT_LT05_C02_T1_L2
https://developers.google.com/earth-engine/datasets/catalog/LANDSAT_LE07_C02_T1_L2
https://developers.google.com/earth-engine/datasets/catalog/LANDSAT_LE08_C02_T1_L2
*/
exports.scaleFactorsLC2 = function(image) {
  var opticalBands = image.select('SR_B.').multiply(0.0000275).add(-0.2).toFloat();
  var thermalBands = image.select('ST_B.*').multiply(0.00341802).add(149.0).toFloat();
  return image.addBands(opticalBands, null, true)
              .addBands(thermalBands, null, true);
};
/**
Applies scaling factors for Sentinel 2

https://developers.google.com/earth-engine/datasets/catalog/COPERNICUS_S2
*/
exports.scaleFactorsS2 = function(image) {
  var opticalBands = image.select('B.+').multiply(0.0001).toFloat();
  return image.addBands(opticalBands, null, true);
};
/**
Rename bands of Landsat 5 and 7 Collection2

https://developers.google.com/earth-engine/datasets/catalog/LANDSAT_LT05_C02_T1_L2
https://developers.google.com/earth-engine/datasets/catalog/LANDSAT_LE07_C02_T1_L2
*/
exports.renameBandsL7C2 = function(img) {
  return img.select("SR_B.|ST_B.|QA_PIXEL").rename([
    "blue", "green", "red", "nir",
    "swir1", // Shortwave infrared 1
    "swir2", // Shortwave infrared 2
    "st", // surface temperature
    "qa" // Pixel quality attributes generated from the CFMASK algorithm
  ]);
};
/**
Rename bands of Landsat 8 and 9 Collection2

https://developers.google.com/earth-engine/datasets/catalog/LANDSAT_LE08_C02_T1_L2
*/
exports.renameBandsL8C2 = function(img) {
  return img.select("SR_B.+|ST_B.+|QA_PIXEL").rename([
    "aerosol", "blue", "green", "red", "nir",
    "swir1", "swir2",
    "st",
    "qa" // QA Bitmask
  ]);
};
/**
Cloud mask of Landsat 5/7/8/9 Collection 2

- Bits 8-9: Cloud Confidence
- Bits 14-15: Cirrus Confidence
*/
exports.rmCloudLC2 = function(img) {
  var qa = img.select("qa");
  var mask = qa.bitwiseAnd(3 << 8).neq(3 << 8).and(qa.bitwiseAnd(3 << 14).neq(3 << 14));
  return img.updateMask(img.mask().and(mask));
};
/**
Cloud shadow mask of Landsat 5/7/8/9 Collection 2

- Bits 10-11: Cloud Shadow Confidence
*/
exports.rmCloudShadowLC2 = function(img) {
  var qa = img.select("qa");
  var mask = qa.bitwiseAnd(3 << 10).neq(3 << 10);
  return img.updateMask(img.mask().and(mask));
};
/**
Snow/ice mask of Landsat 5/7/8/9 Collection 2

- Bits 12-13: Snow/Ice Confidence
*/
exports.rmSnowLC2 = function(img) {
  var qa = img.select("qa");
  var mask = qa.bitwiseAnd(3 << 12).neq(3 << 12);
  return img.updateMask(img.mask().and(mask));
};

//LSWI: (nir - swir1) / (nir + swir1)
exports.getLSWI = function(img) {
  return img.addBands(img.normalizedDifference(["nir", "swir1"]).rename("LSWI"));
};
// NDVI: (nir - red) / (nir + red)
exports.getNDVI = function(img) {
  return img.addBands(img.normalizedDifference(["nir", "red"]).rename("NDVI"));
};
// EVI: 2.5*(nir - red) / (nir + 6 * red - 7.5 * blue + 1)
exports.getEVI = function(img) {
  var evi = img.expression(
    "2.5 * (nir - red) / (nir + 6 * red - 7.5 * blue + 1)",
    {"nir": img.select("nir"), "red": img.select("red"), "blue": img.select("blue")}
  );
  return img.addBands(evi.rename("EVI"));
};

/**date string*/
exports.dateTimeStr = function() {
  var d = new Date();
  return d.getFullYear() + "-" + Number(d.getMonth() + 1)
  + "-" + d.getDate() + "T" + d.getHours() + "_" + d.getMinutes();
};

