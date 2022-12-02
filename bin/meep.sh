for client in EMT_MADRID TMB_MASATS masats_singapur; do
    for d in 2021-09-{11..27}; do
        s3_many_copy -download . -from-bucket datik-telemetry-files \
            --filter "_reader_config_and_event" \
            --from-prefix "$client/$d" -concurrency 200

        find . -iname '*.csv' | xargs cat \
        | dm1_csv_format_2_ndjson.py \
        | jq -Rc '(try fromjson catch null)| select(.!=null) | .+{resourceCode:.vehicleCode}'  \
        | ES_URL=https://search-predictivo-masats-5aml7qgszk3zltmyhwrwhqi4p4.eu-central-1.es.amazonaws.com feeding_my_elastic.sh main

        find . -type f -iname '*csv' -delete
    done
done

