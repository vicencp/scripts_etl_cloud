#!/bin/sh
ES_URL=https://search-predictivo-masats-5aml7qgszk3zltmyhwrwhqi4p4.eu-central-1.es.amazonaws.com

curl -sg -XPOST "$ES_URL/main/_delete_by_query?q=@timestamp:[*%20TO%20now-60d]%20AND%20(NOT%20manoeuvre_name:(re1%20OR%20rt1))"

curl -sg -XPOST "$ES_URL/main/_delete_by_query?q=@timestamp:[*%20TO%20now-444d]%20AND%20manoeuvre_name:(re1%20OR%20rt1)"

curl -sg -XPOST "$ES_URL/anomalous_consumption_arrays,test*/_delete_by_query?q=@timestamp:[*%20TO%20now-60d]"
curl -sg -XPOST "$ES_URL/tests_insertion_outliers_window/_delete_by_query?q=@timestamp:[*%20TO%20now-60d]"
curl -sg -XPOST "$ES_URL/tests_insertion_window/_delete_by_query?q=@timestamp:[*%20TO%20now-60d]"

