--Task 1. Explore ecommerce data
#Question: Out of the total visitors who visited our website, what % made a purchase?

#standardSQL
WITH 
	visitors AS(
	SELECT
		COUNT(DISTINCT fullVisitorId) AS total_visitors
	FROM 
		`data-to-insights.ecommerce.web_analytics`
	),
	purchasers AS(
		SELECT
			COUNT(DISTINCT fullVisitorId) AS total_purchasers
		FROM `data-to-insights.ecommerce.web_analytics`
		WHERE totals.transactions IS NOT NULL
		)
SELECT
	total_visitors,
	total_purchasers,
	(total_purchasers / total_visitors)*100 AS conversion_rate
FROM 
	visitors, 
	purchasers

#The result: 2.69%

#Question: What are the top 5 selling products?

SELECT
	p.v2ProductName,
	p.v2ProductCategory,
	SUM(p.productQuantity) AS units_sold,
	ROUND(SUM(p.localProductRevenue/1000000),2) AS revenue
FROM 
	`data-to-insights.ecommerce.web_analytics`,
	UNNEST(hits) AS h,
	UNNEST(h.product) AS p
GROUP BY 
	1, 2
ORDER BY 
	revenue DESC
LIMIT 5;

#The result:
{  "v2ProductName": "Nest® Learning Thermostat 3rd Gen-USA - Stainless Steel",  "v2ProductCategory": "Nest-USA",  "units_sold": "17651",  "revenue": "870976.95"}
{  "v2ProductName": "Nest® Cam Outdoor Security Camera - USA",  "v2ProductCategory": "Nest-USA",  "units_sold": "16930",  "revenue": "684034.55"}
{  "v2ProductName": "Nest® Cam Indoor Security Camera - USA",  "v2ProductCategory": "Nest-USA",  "units_sold": "14155",  "revenue": "548104.47"}
{  "v2ProductName": "Nest® Protect Smoke + CO White Wired Alarm-USA",  "v2ProductCategory": "Nest-USA",  "units_sold": "6394",  "revenue": "178937.6"}
{  "v2ProductName": "Nest® Protect Smoke + CO White Battery Alarm-USA",  "v2ProductCategory": "Nest-USA",  "units_sold": "6340",  "revenue": "178572.4"}

#Question: How many visitors bought on subsequent visits to the website?

# visitors who bought on a return visit (could have bought on first as well
WITH
  all_visitor_stats AS (
  SELECT
    fullvisitorid,
    # 741,721 unique visitors
  IF
    (COUNTIF(totals.transactions > 0
        AND totals.newVisits IS NULL) > 0,
      1,
      0) AS will_buy_on_return_visit
  FROM
    `data-to-insights.ecommerce.web_analytics`
  GROUP BY
    fullvisitorid )
SELECT
  COUNT(DISTINCT fullvisitorid) AS total_visitors,
  will_buy_on_return_visit
FROM
  all_visitor_stats
GROUP BY
  will_buy_on_return_visit

#The result:
{  "total_visitors": "729848",  "will_buy_on_return_visit": "0"}
{  "total_visitors": "11873",  "will_buy_on_return_visit": "1"}

#Analyzing the results, you can see that (11873 / 729848) = 1.6% of total visitors will return and purchase from the website. 
#This includes the subset of visitors who bought on their very first session and then came back and bought again.


#Question:What are some of the reasons a typical ecommerce customer will browse but not buy until a later visit? Choose all that could apply.
#Answer: The customer wants to comparison shop on other sites before making a purchase decision; customer is waiting for products to go on sale or other promotion; moreover, customer is doing additional research.


--Task 2. Select features and create your training dataset

# I decided to test whether these two fields are good inputs for classification model:

#totals.bounces (whether the visitor left the website immediately)
#totals.timeOnSite (how long the visitor was on our website)

#Risks: Whether a user bounces is highly correlated with their time on site (e.g. 0 seconds), using only time spent on the site ignores other potential useful columns (features)

SELECT
  * EXCEPT(fullVisitorId)
FROM
  # features
  (
  SELECT
    fullVisitorId,
    IFNULL(totals.bounces,
      0) AS bounces,
    IFNULL(totals.timeOnSite,
      0) AS time_on_site
  FROM
    `data-to-insights.ecommerce.web_analytics`
  WHERE
    totals.newVisits = 1)
JOIN (
  SELECT
    fullvisitorid,
  IF
    (COUNTIF(totals.transactions > 0
        AND totals.newVisits IS NULL) > 0,
      1,
      0) AS will_buy_on_return_visit
  FROM
    `data-to-insights.ecommerce.web_analytics`
  GROUP BY
    fullvisitorid)
USING
  (fullVisitorId)
ORDER BY
  time_on_site DESC
LIMIT
  10;

#The result:
{  "bounces": "0",  "time_on_site": "15047",  "will_buy_on_return_visit": "0"}
{  "bounces": "0",  "time_on_site": "12136",  "will_buy_on_return_visit": "0"}
{  "bounces": "0",  "time_on_site": "11201",  "will_buy_on_return_visit": "0"}
{  "bounces": "0",  "time_on_site": "10046",  "will_buy_on_return_visit": "0"}
{  "bounces": "0",  "time_on_site": "9974",  "will_buy_on_return_visit": "0"}
{  "bounces": "0",  "time_on_site": "9564",  "will_buy_on_return_visit": "0"}
{  "bounces": "0",  "time_on_site": "9520",  "will_buy_on_return_visit": "0"}
{  "bounces": "0",  "time_on_site": "9275",  "will_buy_on_return_visit": "1"}
{  "bounces": "0",  "time_on_site": "9138",  "will_buy_on_return_visit": "0"}
{  "bounces": "0",  "time_on_site": "8872",  "will_buy_on_return_visit": "0"}


#Question: Looking at the initial data results, do you think time_on_site and bounces will be a good indicator of whether the user will return and purchase or not?

#Answer: It's often too early to tell before training and evaluating the model, but at first glance out of the top 10 time_on_site, only 1 customer returned to buy, which isn't very promising. 
#Let's see how well the model does.


--Task 3. Create a BigQuery dataset to store models
#Done

--Task 4. Select a BigQuery ML model type and specify options

CREATE OR REPLACE MODEL
  `ecommerce.classification_model` OPTIONS ( model_type='logistic_reg',
    labels = ['will_buy_on_return_visit'] ) AS
  #standardSQL
SELECT
  * EXCEPT(fullVisitorId)
FROM
  # features
  (
  SELECT
    fullVisitorId,
    IFNULL(totals.bounces,
      0) AS bounces,
    IFNULL(totals.timeOnSite,
      0) AS time_on_site
  FROM
    `data-to-insights.ecommerce.web_analytics`
  WHERE
    totals.newVisits = 1
    AND date BETWEEN '20160801'
    AND '20170430') # train on first 9 months
JOIN (
  SELECT
    fullvisitorid,
  IF
    (COUNTIF(totals.transactions > 0
        AND totals.newVisits IS NULL) > 0,
      1,
      0) AS will_buy_on_return_visit
  FROM
    `data-to-insights.ecommerce.web_analytics`
  GROUP BY
    fullvisitorid)
USING
  (fullVisitorId);


--Task 5. Evaluate classification model performance

#Now that training is complete, you can evaluate how well the model performs by running this query using ML.EVALUATE:

SELECT
  roc_auc,
  CASE
    WHEN roc_auc > .9 THEN 'good'
    WHEN roc_auc > .8 THEN 'fair'
    WHEN roc_auc > .7 THEN 'not great'
  ELSE
  'poor'
END
  AS model_quality
FROM
  ML.EVALUATE(MODEL ecommerce.classification_model,
    (
    SELECT
      * EXCEPT(fullVisitorId)
    FROM
      # features
      (
      SELECT
        fullVisitorId,
        IFNULL(totals.bounces,
          0) AS bounces,
        IFNULL(totals.timeOnSite,
          0) AS time_on_site
      FROM
        `data-to-insights.ecommerce.web_analytics`
      WHERE
        totals.newVisits = 1
        AND date BETWEEN '20170501'
        AND '20170630') # eval on 2 months
    JOIN (
      SELECT
        fullvisitorid,
      IF
        (COUNTIF(totals.transactions > 0
            AND totals.newVisits IS NULL) > 0,
          1,
          0) AS will_buy_on_return_visit
      FROM
        `data-to-insights.ecommerce.web_analytics`
      GROUP BY
        fullvisitorid)
    USING
      (fullVisitorId) ));

#The result:
{  "Row": "1",  "roc_auc": "0.724588",  "model_quality": "not great"}

#After evaluating your model I get a roc_auc of 0.72, which shows that the model has not great predictive power. 
#Since the goal is to get the area under the curve as close to 1.0 as possible, there is room for improvement.

--Task 6. Improve model performance with feature engineering

#Adding new features and creating a second machine learning model called classification_model_2:

# 1. How far the visitor got in the checkout process on their first visit

# 2. Where the visitor came from (traffic source: organic search, referring site etc.)

# 3. Device category (mobile, tablet, desktop)

# 4. Geographic information (country)


CREATE OR REPLACE MODEL
  `ecommerce.classification_model_2` OPTIONS (model_type='logistic_reg',
    labels = ['will_buy_on_return_visit']) AS
WITH
  all_visitor_stats AS (
  SELECT
    fullvisitorid,
  IF
    (COUNTIF(totals.transactions > 0
        AND totals.newVisits IS NULL) > 0,
      1,
      0) AS will_buy_on_return_visit
  FROM
    `data-to-insights.ecommerce.web_analytics`
  GROUP BY
    fullvisitorid )
  # add in new features
SELECT
  * EXCEPT(unique_session_id)
FROM (
  SELECT
    CONCAT(fullvisitorid, CAST(visitId AS STRING)) AS unique_session_id,
    # labels
    will_buy_on_return_visit,
    MAX(CAST(h.eCommerceAction.action_type AS INT64)) AS latest_ecommerce_progress,
    # behavior on the site
    IFNULL(totals.bounces,
      0) AS bounces,
    IFNULL(totals.timeOnSite,
      0) AS time_on_site,
    totals.pageviews,
    # where the visitor came from
    trafficSource.source,
    trafficSource.medium,
    channelGrouping,
    # mobile or desktop
    device.deviceCategory,
    # geographic
    IFNULL(geoNetwork.country,
      "") AS country
  FROM
    `data-to-insights.ecommerce.web_analytics`,
    UNNEST(hits) AS h
  JOIN
    all_visitor_stats
  USING
    (fullvisitorid)
  WHERE
    1=1
    # only predict for new visits
    AND totals.newVisits = 1
    AND date BETWEEN '20160801'
    AND '20170430' # train 9 months
  GROUP BY
    unique_session_id,
    will_buy_on_return_visit,
    bounces,
    time_on_site,
    totals.pageviews,
    trafficSource.source,
    trafficSource.medium,
    channelGrouping,
    device.deviceCategory,
    country );

#A key new feature that was added to the training dataset query is the maximum checkout progress each visitor reached in their session, which is recorded in the field hits.eCommerceAction.action_type.

#Evaluating this new model to see if there is better predictive power by running the below query:

SELECT
  roc_auc,
  CASE
    WHEN roc_auc > .9 THEN 'good'
    WHEN roc_auc > .8 THEN 'fair'
    WHEN roc_auc > .7 THEN 'not great'
  ELSE
  'poor'
END
  AS model_quality
FROM
  ML.EVALUATE(MODEL ecommerce.classification_model_2,
    (
    WITH
      all_visitor_stats AS (
      SELECT
        fullvisitorid,
      IF
        (COUNTIF(totals.transactions > 0
            AND totals.newVisits IS NULL) > 0,
          1,
          0) AS will_buy_on_return_visit
      FROM
        `data-to-insights.ecommerce.web_analytics`
      GROUP BY
        fullvisitorid )
      # add in new features
    SELECT
      * EXCEPT(unique_session_id)
    FROM (
      SELECT
        CONCAT(fullvisitorid, CAST(visitId AS STRING)) AS unique_session_id,
        # labels
        will_buy_on_return_visit,
        MAX(CAST(h.eCommerceAction.action_type AS INT64)) AS latest_ecommerce_progress,
        # behavior on the site
        IFNULL(totals.bounces,
          0) AS bounces,
        IFNULL(totals.timeOnSite,
          0) AS time_on_site,
        totals.pageviews,
        # where the visitor came from
        trafficSource.source,
        trafficSource.medium,
        channelGrouping,
        # mobile or desktop
        device.deviceCategory,
        # geographic
        IFNULL(geoNetwork.country,
          "") AS country
      FROM
        `data-to-insights.ecommerce.web_analytics`,
        UNNEST(hits) AS h
      JOIN
        all_visitor_stats
      USING
        (fullvisitorid)
      WHERE
        1=1
        # only predict for new visits
        AND totals.newVisits = 1
        AND date BETWEEN '20170501'
        AND '20170630' # eval 2 months
      GROUP BY
        unique_session_id,
        will_buy_on_return_visit,
        bounces,
        time_on_site,
        totals.pageviews,
        trafficSource.source,
        trafficSource.medium,
        channelGrouping,
        device.deviceCategory,
        country ) ));

#The result:
{  "Row": "1",  "roc_auc": "0.910382",  "model_quality": "good"}

#With this new model now a roc_auc of 0.91 which is significantly better than the first model.


--Task 7. Predict which new visitors will come back and purchase
#A prediction query below which uses the improved classification model to predict the probability that a first-time visitor to the Google Merchandise Store will make a purchase in a later visit:

SELECT
  *
FROM
  ml.PREDICT(MODEL `ecommerce.classification_model_2`,
    (
    WITH
      all_visitor_stats AS (
      SELECT
        fullvisitorid,
      IF
        (COUNTIF(totals.transactions > 0
            AND totals.newVisits IS NULL) > 0,
          1,
          0) AS will_buy_on_return_visit
      FROM
        `data-to-insights.ecommerce.web_analytics`
      GROUP BY
        fullvisitorid )
    SELECT
      CONCAT(fullvisitorid, '-',CAST(visitId AS STRING)) AS unique_session_id,
      # labels
      will_buy_on_return_visit,
      MAX(CAST(h.eCommerceAction.action_type AS INT64)) AS latest_ecommerce_progress,
      # behavior on the site
      IFNULL(totals.bounces,
        0) AS bounces,
      IFNULL(totals.timeOnSite,
        0) AS time_on_site,
      totals.pageviews,
      # where the visitor came from
      trafficSource.source,
      trafficSource.medium,
      channelGrouping,
      # mobile or desktop
      device.deviceCategory,
      # geographic
      IFNULL(geoNetwork.country,
        "") AS country
    FROM
      `data-to-insights.ecommerce.web_analytics`,
      UNNEST(hits) AS h
    JOIN
      all_visitor_stats
    USING
      (fullvisitorid)
    WHERE
      # only predict for new visits
      totals.newVisits = 1
      AND date BETWEEN '20170701'
      AND '20170801' # test 1 month
    GROUP BY
      unique_session_id,
      will_buy_on_return_visit,
      bounces,
      time_on_site,
      totals.pageviews,
      trafficSource.source,
      trafficSource.medium,
      channelGrouping,
      device.deviceCategory,
      country ) )
ORDER BY
  predicted_will_buy_on_return_visit DESC;

#Output: the module has for predictions July 2017 ecommerce sessions. Three newly added fields:

#predicted_will_buy_on_return_visit: whether the model thinks the visitor will buy later (1 = yes)
#predicted_will_buy_on_return_visit_probs.label: the binary classifier for yes / no
#predicted_will_buy_on_return_visit_probs.prob: the confidence the model has in it's prediction (1 = 100%)


--Results

#Of the top 6% of first-time visitors (sorted in decreasing order of predicted probability), more than 6% make a purchase in a later visit.

#These users represent nearly 50% of all first-time visitors who make a purchase in a later visit.

#Overall, only 0.7% of first-time visitors make a purchase in a later visit.

#Targeting the top 6% of first-time increases marketing ROI by 9x vs targeting them all!