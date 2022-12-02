#!/bin/bash
export PATH="$PATH:$HOME/bin"

main() {
    d="${1:-$(date -I -d -1day)}"
    listfile="${listfile:-$HOME/bin/lista_dcbl_masats.json}"
    export listfile
    export AWS_PROFILE="${AWS_PROFILE:-masats}"

    workdir="$(mktemp -d /tmp/sync_1_day_of_masats_data_XXXXXXX)"
    # trap "cd '$PWD' && rm -rf '$workdir'" EXIT
    cd "$workdir" || exit 1
    echo "workdir is $workdir" >&2

    export ES_URL='https://search-predictivo-masats-5aml7qgszk3zltmyhwrwhqi4p4.eu-central-1.es.amazonaws.com'

    for client in masats_singapur EMT_MADRID TMB_MASATS; do
    s3_many_copy -download . -from-bucket datik-telemetry-files \
        --filter "_reader_config_and_event" \
        --from-prefix "$client/$d" -concurrency 200
    done

    find . -iname '*.csv' \
    | awk -F- '{print $4}' \
    | sort -u \
    | tr a-z A-Z \
    | while read -r serial; do
        find . -iname "*${serial}*.csv" -print0 \
        | xargs -0 cat \
        | dm1_csv_format_2_ndjson.py \
        | jq -c '.+{serial:"'$serial'"}'
    done \
    | jq --slurpfile listfile "$listfile" \
        -f ~/bin/augment_masats.jq \
    | feeding_my_elastic.sh "${INDEX:-main}"

    # jq -c . oo.ndjson \
    # | parallel --line-buffer --pipe jq -cf ~/bin/separate_muestras.jq \
    # | feeding_my_elastic.sh "${INDEX_MUESTRAS:-samples}" \

    echo "workdir was $workdir" >&2
}

main "$@"
