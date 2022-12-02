#!/bin/bash

export AWS_PROFILE=masats
export TZ=GMT;

date=$(date -I);
thishour=$(date +%Y%m%dT%H );
lasthour=$(date +%Y%m%dT%H -d "-1 hour");

for client in EMT_MADRID TMB_MASATS masats_singapur; do
    echo "s3_many_copy $client/$date" >&2
    s3_many_copy -from-bucket datik-telemetry-files \
        -filter "_event_.*-($thishour|$lasthour)" \
        -to-bucket predictivo-masats -to-prefix dcbl-files/ \
        -from-prefix "$client/$date" -concurrency 88
done
