#standardSQL
CREATE TEMPORARY FUNCTION getGlobalKeywords(css STRING) RETURNS
ARRAY<STRUCT<property STRING, keyword STRING, freq INT64>> LANGUAGE js AS '''
try {
  function compute(ast) {
    let ret = {};

    walkDeclarations(ast, ({property, value}) => {
      let key = value;

      ret[value] = ret[value] || {};

      incrementByKey(ret[value], "total");
      incrementByKey(ret[value], property);
    }, {
      values: ["inherit", "initial", "unset", "revert"]
    });

    for (let keyword in ret) {
      ret[keyword] = sortObject(ret[keyword]);
    }

    return ret;
  }
  var ast = JSON.parse(css);
  var kw = compute(ast);
  return Object.entries(kw).flatMap(([keyword, properties]) => {
    return Object.entries(properties).filter(([property]) => {
      return property != 'total';
    }).map(([property, freq]) => {
      return {property, keyword, freq};
    });
  });
} catch (e) {
  return [];
}
'''
OPTIONS (library="gs://httparchive/lib/css-utils.js");

SELECT
  *
FROM (
  SELECT
    client,
    kw.keyword,
    kw.property,
    SUM(kw.freq) AS freq,
    SUM(SUM(kw.freq)) OVER (PARTITION BY client, kw.keyword) AS total,
    SUM(kw.freq) / SUM(SUM(kw.freq)) OVER (PARTITION BY client, kw.keyword) AS pct
  FROM
    `httparchive.almanac.parsed_css`,
    UNNEST(getGlobalKeywords(css)) AS kw
  WHERE
    date = '2020-08-01'
  GROUP BY
    client,
    keyword,
    property)
WHERE
  pct >= 0.01
ORDER BY
  client,
  keyword,
  pct DESC