#!/bin/sh
### feeding_my_elastic.sh - feed NDJSON to a running ES instance
### 
### USAGE
###    feeding_my_elastic.sh [myIndex [myType]]
### 
### DEFAULTS
###     myIndex=foo, the index to write to
###     myType=bar, the type, defaults to type1
### 
### ENVIRONMENT VARIABLES
###     ES_URL
###         The Elasticsearch endpoint, defaults to localhost:9200.
### 
###     other ES endpoints:
###     https://search-telemetry-6x7ecdmovnto3dwid6citjxi3a.eu-central-1.es.amazonaws.com
###     https://search-predictivo-masats-5aml7qgszk3zltmyhwrwhqi4p4.eu-central-1.es.amazonaws.com
###     https://vpc-resources-telemetry-djfcq43btr7vngushe5gynnch4.eu-central-1.es.amazonaws.com
### 
### REQUIREMENTS
###     jq, curl, parallel

if [ "$1" = '-h' ] || [ "$1" = '--help' ]; then
    sed -rn 's/^### ?//;T;p' "$0"
    exit 0
fi

tmpdir="$(mktemp -d /tmp/feeding_my_elastic_XXXXXX)"
echo "tmpdir is $tmpdir" >&2

jq -c \
    --arg myIndex "${1:-foo}" \
    --arg myType "${2:-type1}" \
    --arg fallbackmac \
        "$(od -An -t x2 -N6 /dev/urandom | tr 'a-f' 'A-F' | tr -d ' ')" \
    '(."@timestamp"
        // .date
        // .init_date
        // (now | strftime("%Y-%m-%d %H:%M:%S") + "," + tostring[-6:-3])
    ) as $timestamp

    | (.serial // $fallbackmac) as $serial

    | if ((.lat != null) and (.lon != null)) then
        . + {location:"\(.lat),\(.lat)"}
    else
        .
    end
    | {(env.UPSERT//"create"): {
        _index: $myIndex
        , _type: $myType
        , _id: (._myid//"\($timestamp)-\($serial)")}
    }
    ,
    .
' \
| parallel -j1 --pipe -L2 --block 10M \
    --tmpdir "$tmpdir" \
    curl -s -H content-type:application/x-ndjson \
        "${ES_URL:-http://localhost:9200}/_bulk" --data-binary @- \
| if ! "${DEBUG:-false}"; then
    cat
else
    debugfile=$(mktemp /tmp/debug_feed_elastic_XXXXX)
    tee $debugfile
    echo debugging info in $debugfile >&2
fi \
| jq -c .items[][env.UPSERT].status | uniq -c

echo "tmpdir was $tmpdir" >&2

rm -rf "$tmpdir"
