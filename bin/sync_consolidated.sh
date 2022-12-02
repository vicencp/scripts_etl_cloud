#!/bin/sh

export AWS_PROFILE=masats
end="${end:-$(date -I -d -1days)}"
start="${start:-$(date -I -d -3days)}"
dates="$(dates_in_range.py -s "$start" -e "$end" | tac)"

# consolidated data
for d in $dates; do
    for t in TMB_MASATS EMT_MADRID masats_singapur; do
        s3_many_copy \
            -from-bucket datik-telemetry-files-consolidados \
            -from-prefix "$t/consolidated/dt_=$d" \
            -to-bucket predictivo-masats \
            -to-prefix dcbl-files-consolidated \
            -concurrency 20 --keep-path
    done
done
