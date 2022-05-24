# Overview

BigQuery ML (BigQuery machine learning) is a feature in BigQuery where data analysts can create, train, evaluate, and predict with machine learning models with minimal coding. 

The Google Analytics Sample Ecommerce dataset that has millions of Google Analytics records for the Google Merchandise Store loaded into BigQuery. In this lab, I will use this data to run some typical queries that businesses would want to know about their customers' purchasing habits.

# Objectives

In this lab, the following tasks should be performed :

* Loading data into BigQuery from a public dataset;
* Querying and exploring the e-commerce data set;
* Creating a training and evaluation data set to be used for batch prediction;
* Creating a classification, and logistic regression model in BigQuery ML;
* Evaluating the performance of created machine learning model;
* And predicting and ranking the probability that a visitor will make a purchase. 

# Results

* Of the top 6% of first-time visitors (sorted in decreasing order of predicted probability), more than 6% make a purchase in a later visit.
* These users represent nearly 50% of all first-time visitors who make a purchase in a later visit.
* Overall, only 0.7% of first-time visitors make a purchase in a later visit.
* Targeting the top 6% of first-time increases marketing ROI by 9x vs targeting them all!
