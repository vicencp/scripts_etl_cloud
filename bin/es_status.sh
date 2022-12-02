#!/bin/sh
#ES STATUS
for i in health allocation indices shards; do
    echo;
    echo $i:;
    curl -s "search-predictivo-masats-5aml7qgszk3zltmyhwrwhqi4p4.eu-central-1.es.amazonaws.com/_cat/$i?v&format=json" \
    | jq -c .[];
done 
