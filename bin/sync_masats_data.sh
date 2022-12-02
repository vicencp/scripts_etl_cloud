#!/bin/sh

export AWS_PROFILE=masats
end="${end:-$(date +%Y-%m)}"
start="${start:-$(date -I -d -3days)}"
dates="$(dates_in_range.py -s "$start" -e "$end" | tac)"

# raw data
for d in $dates; do
    d1="$(date +%Y%m%d -d "$d")"
    d2="$(date +%Y%m%d -d "$d -1 day")"
    for client in EMT_MADRID TMB_MASATS masats_singapur; do
        echo "s3_many_copy $client/$d" >&2
        s3_many_copy -from-bucket datik-telemetry-files \
            -filter "_event_($d1|$d2)" \
            -to-bucket predictivo-masats -to-prefix dcbl-files/ \
            -from-prefix "$client/$d" -concurrency 200
    done
    sync1day_elasticsearch_masats.sh "$d"
done

