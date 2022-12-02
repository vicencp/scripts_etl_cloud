#!/bin/sh

export AWS_PROFILE=masats
export TZ=GMT;

date=$(date -I);
thishour=$(date +%Y%m%dT%H );
lasthour=$(date +%Y%m%dT%H -d "-1 hour");

temp="$(mktemp -d)"
export temp

s3_many_copy -from-bucket predictivo-masats \
    -filter "_event_.*-($thishour|$lasthour)" \
    -download "$temp" \
    -from-prefix "dcbl-files/$date" -concurrency 88


find "$temp" -iname '*.csv' \
| awk -F- '{print $4}' \
| uniq \
| sort -u \
| parallel '
    serial={}

    echo "$serial $(find "$temp" -iname "*${serial}*.csv" | wc -l)" >&2;

    find "$temp" -iname "*${serial}*.csv" -print0 \
    | xargs -0 cat \
    | dm1_csv_format_2_ndjson.py \
    | jq -c --arg serial "$serial" \
        --slurpfile listfile ~/bin/lista_dcbl_masats.json \
        -f ~/bin/augment_masats.jq
' > "$temp/supercahe"
exit 0

export ES_URL='https://search-predictivo-masats-5aml7qgszk3zltmyhwrwhqi4p4.eu-central-1.es.amazonaws.com'

feeding_my_elastic.sh main < "$temp/supercahe"

# cat "$temp/supercahe" \
# | jq -cf ~/bin/separate_muestras.jq \
# | feeding_my_elastic.sh samples

echo "workdir was $temp" >&2

rm -rf "$temp"
