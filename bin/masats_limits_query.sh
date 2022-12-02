#!/bin/sh
### masats_limits_query.sh - recompute out of limits index in grafana
###
###

# BEWARE: quite ugly stuff

set -a
TSV_URL="${TSV_URL:-https://docs.google.com/spreadsheets/d/1J3arIo5QfibjAuUFvGGKT1aMzIja39w9GlXiPBodhbg/export?format=tsv}"
ES_URL="${ES_URL:-https://search-predictivo-masats-5aml7qgszk3zltmyhwrwhqi4p4.eu-central-1.es.amazonaws.com}"

tmpconf=/dev/shm/percentiles_conf.json
bupconf="$HOME/percentiles_conf.json"
curl -Ls "$TSV_URL" | csv2json.py -d '\t' | jq -Sc . >  "$tmpconf"

ls "$bupconf" 1>/dev/null 2>&1 || touch "$bupconf"
currsum=$(md5sum "$tmpconf" | awk '{print $1}')
prevsum=$(md5sum "$bupconf" | awk '{print $1}')
now=$(date +%s)
lastmodified=$(stat -c %Y "$bupconf")

printf '[%s] currsum=%s, prevsum=%s, now-lastmodified=%s\n' \
    $(date -Im) $currsum $prevsum $((now-lastmodified)) >&2

if [ "$currsum" != "$prevsum"  ]; then
    echo New checksum, proceed to computation. >&2
    cp "$tmpconf" "$bupconf"
elif [ $((now-lastmodified)) -gt $((60*60*24)) ]; then
    echo Backup is old, proceed to computation. >&2
    touch "$bupconf"
else
    echo Checksums are equal and backup is fresh, skip computation. >&2
    exit 0
fi

curl -sX DELETE "$ES_URL/thresholds" | jq -c .
curl -sX PUT "$ES_URL/thresholds" | jq -c .

for operador in $(jq -r .[].OPERADOR "$tmpconf"  | sort -u); do
for pr in $(jq -r .[].puerta_rampa "$tmpconf"  | sort -u); do
for ab in ABRIR CERRAR; do

conf=/dev/shm/conf_${operador}_${pr}_${ab}.json


cat "$tmpconf" \
| jq -rc --arg ab $ab --arg op $operador --arg pr $pr 'map(
    select(.OPERADOR == $op
        and .puerta_rampa == $pr
        # (string|test(re)) -> true if re matches string else false
        and (.VARIABLE|test({"ABRIR":"CERRAR", "CERRAR":"ABRIR"}[$ab])|not))
    | {key:.VARIABLE,
        value:  with_entries(
            select(
                (.key[:3]=="min" or .key[:3]=="max")
                and
                (.value|type == "number")
                and
                (.value != 0)
            )
        )
    }
    | select(.value != {})
)|from_entries
' > "$conf"

date +"%Y-%m-%d %H:%M:%S doing $conf" >&2

if [ $(wc -c < $conf) -lt 11 ]; then
    continue
fi

cat "$tmpconf" \
| jq -rc --arg op "$operador" --arg pr "$pr" --arg ab "$ab" 'map(
    select(.OPERADOR == $op
        and .puerta_rampa == $pr
        and (.VARIABLE|test({"ABRIR":"CERRAR", "CERRAR":"ABRIR"}[$ab]) == false))
    | {VARIABLE, OPERADOR, puerta_rampa}
    + with_entries(select((.key[:3]=="min" or .key[:3]=="max") and (.value|type == "number"))))
    | map(select(length>3))
    | {aggs:
    ( map({
        key: "per_\(.VARIABLE)", value: {"percentiles":{"field":.VARIABLE,"percents":["75","50","25"]}}}
        , {key:"ext_\(.VARIABLE)", value :{"extended_stats":{"field":.VARIABLE}}}
    )|from_entries)}
    | {
        "query" : {
          "bool" : {
          "must" : [
            {"query_string":{"query":"manoeuvre_name:\($pr) AND resourceCode:\($op)* AND \($ab):true"}},
            {"range": { "@timestamp": {"gte": "now-8w", "lt": "now"}}}
          ]}
        },
        "size": 0,
        "aggs": { "boo" : {
            "date_histogram" : {"field" : "@timestamp", "interval" : "week"},
            "aggs": { "perveh": {
                "terms": {"field": "resourceCode.keyword", "size": 10000},
                 "aggs": ((.aggs) + {top_hits:{top_hits:{size:1, "_source":["serial"]}}})
            }}
        }}
    }
' \
| curl -s -H content-type:application/json "$ES_URL/main/_search" -d @- \
| sed 's/\<avg\>/mean/g' \
| jq -c '
    .aggregations.boo.buckets[]
    | {week:.key_as_string}
    + (.perveh.buckets[] |
    { v: (.key), serial:(.top_hits.hits.hits[]._source.serial), doc_count}
    + (.|
        [[to_entries[] | select(.key[:4]=="ext_" or .key[:4] == "per_")]
            | group_by(.key[4:])[]
            | {key:.[0].key[4:],value:(.[0].value+.[1].value)}]
        |from_entries))
' \
| jq -c --arg ab "$ab" --arg pr "$pr" --arg op "$operador" --argfile a "$conf" '
    . as $data
    | $a|to_entries[]
    | select(.value!={})
    | .value as $conds
    | .key as $var
    | $data[$var] as $vals
    | $conds
    | to_entries[]
    | .value as $threshold
    | .key as $cond
    | .key
    | split(" +";"g")
    | .[0] as $mm
    | .[1]
    | (if (.[0:1] == "p") then 
        $vals["values"][(.[1:]+".0")]
        else $vals[.] end) as $val
    | select($val | type == "number")
    | {
        week: $data["week"]
        , "@timestamp": $data["week"]
        , manoeuvre_name: $pr
        , resourceCode: $data["v"]
        , serial : $data["serial"]
        , doc_count: $data["doc_count"]
        , var: $var
        , ($ab): true
        , DENTRO_O_FUERA_DE_MANIOBRA : true
        , out: (
            if ($mm == "min") then
                $val < ($threshold * .8)
            elif ($mm == "max") then
                $val > ($threshold * 1.2)
            else false end
        )
        , measured: $val
        , threshold: $threshold
        , cause: $cond
        , last_execution: (now|strftime("%Y-%m-%dT%H:%M:%S"))
    }
    | select(.out)
    | . + {"_myid": (
            [ ."@timestamp"
            , .resourceCode
            , $pr
            , $ab
            , .var
            , .cause
            ]|join("-"))}
'

date +"%Y-%m-%d %H:%M:%S done  $conf" >&2

done
done
done \
| UPSERT="${UPSERT:-create}" feeding_my_elastic.sh thresholds

date +"%Y-%m-%d %H:%M:%S done"
