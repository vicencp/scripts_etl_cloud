#!/bin/sh

export ES_URL=https://search-predictivo-masats-5aml7qgszk3zltmyhwrwhqi4p4.eu-central-1.es.amazonaws.com 

for idx in tmb_masats@ emt_madrid@ ; do # masats_singapur@; do
    tmp1=$(mktemp)
    tmp2=$(mktemp)
    echo $idx >&2
    curl -gs "$ES_URL/$idx/_search?q=sendData:[now-${off1:-33}m%20TO%20now-${off0:-0}m]&size=9999&_source_exclude=all" \
    | jq -c .hits.hits[]._source > "$tmp1"
    echo $(wc -l < "$tmp1") manoeuvres for $idx >&2

    < "$tmp1" separate_muestras.py > "$tmp2"

    echo $(wc -l < "$tmp2") samples for $idx >&2

    < "$tmp2" feeding_my_elastic.sh samples
    rm -f "$tmp1" "$tmp2"
done

