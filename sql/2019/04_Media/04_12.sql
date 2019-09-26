#standardSQL
# 04_12: Use of "Vary: User-Agent" or "Vary: Accept" on image responses
CREATE TEMPORARY FUNCTION getVary(payload STRING)
RETURNS ARRAY<STRING> LANGUAGE js AS '''
try {
  var $ = JSON.parse(payload);
  var header = $._headers.response.find(h => h.toLowerCase().startsWith('vary'));
  if (!header) {
    return null;
  }
  var value = header.substr(header.indexOf(':') + 1).trim();
  return value.split(',');
} catch (e) {
  return null;
}
''';

SELECT
  client,
  COUNTIF(varies > 0) AS pages,
  total,
  ROUND(COUNTIF(varies > 0) * 100 / total, 2) AS pct
FROM (
  SELECT
    client,
    page,
    COUNTIF(REGEXP_CONTAINS(vary, '(?i)User-Agent|Accept')) AS varies
  FROM
    `httparchive.almanac.requests`,
    UNNEST(getVary(payload)) AS vary
  WHERE
    type = 'image'
  GROUP BY
    client,
    page)
JOIN
  (SELECT _TABLE_SUFFIX AS client, COUNT(0) AS total FROM `httparchive.summary_pages.2019_07_01_*` GROUP BY _TABLE_SUFFIX)
USING (client)
GROUP BY
  client,
  total