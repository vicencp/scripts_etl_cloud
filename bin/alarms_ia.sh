#!/bin/sh

mysql --defaults-file="$HOME/.mysql/.my.cnf"   --defaults-group-suffix=db_telematics  -ABe 'use db_vehicles_external; select v.codigo `key`, e.id_equipamiento `value` from vehiculos v join cliente c on v.historico=0 and c.historico=0 and c.id_cliente=v.id_cliente and c.nombre in ("MASATS_TMB", "MASATS_EMT", "MASATS SINGAPUR") join equipamiento e on e.id_vehiculo=v.id_vehiculo and e.historico=0' | csv2json.py  -d '\t'  | jq from_entries > masatscode2mac.json

OFFSET="${OFFSET:-0d}"

curl  -sL 'https://docs.google.com/spreadsheets/d/1J3arIo5QfibjAuUFvGGKT1aMzIja39w9GlXiPBodhbg/export?format=tsv&gid=1234577899' \
| csv2json.py -d '\t' \
| jq --arg offset "$OFFSET" -c '.[] |
    {index:"tests_insertion_outliers_window"}
    , {
        size:0
        , query:{"query_string":{"query":
            ("bus_id:\(.OPERADOR)*"
                + " AND door:\(.puerta_rampa)"
                + " AND @timestamp:"
                    + "[now-\(.tiempo)-\($offset) TO now-\($offset)]")}}
        , "aggs":{
            "bus_id":{
            "terms":{"field":"bus_id.keyword","size":999,"min_doc_count":1}
            , "aggs":{
                "door":{
                "terms":{"field":"door.keyword","size":314,"min_doc_count":1}
                , "aggs":{


                    "open":{"sum":{"field":"out_algorithm_open"}}
                    , "close":{"sum":{"field":"out_algorithm_close"}}
                    , "percentage_ia":{"bucket_script":{
                        "buckets_path":{
                            "o":"open"
                            , "c":"close"
                            , "tot":"_count"},
                        "script": "(params.o + params.c)/params.tot"}}
                    , "orange_ia":{"bucket_script":{
                        "buckets_path":{}, "script":"\(.orange_ia)"}}
                    , "red_ia":{"bucket_script":{
                        "buckets_path":{}, "script":"\(.red_ia)"}}


                    , "rclose":{"sum":{"field":"Filtro_por_Ruido_close"}}
                    , "ropen":{"sum":{"field":"Filtro_por_Ruido_open"}}
                    , "percentage_ruido":{"bucket_script":{
                        "buckets_path":{
                            "o":"ropen"
                            , "c":"rclose"
                            , "tot":"_count"},
                        "script": "(params.o + params.c)/params.tot"}}
                    , "orange_ruido":{"bucket_script":{
                        "buckets_path":{}, "script":"\(.orange_ruido)"}}
                    , "red_ruido":{"bucket_script":{
                        "buckets_path":{}, "script":"\(.red_ruido)"}}


                    , "ssclose":{"sum":{"field":"short_consumption_array_close"}}
                    , "ssopen":{"sum":{"field":"short_consumption_array_open"}}
                    , "percentage_short_sensi":{"bucket_script":{
                        "buckets_path":{
                            "o":"ssopen"
                            , "c":"ssclose"
                            , "tot":"_count"},
                        "script": "(params.o + params.c)/params.tot"}}
                    , "orange_short_sensi":{"bucket_script":{
                        "buckets_path":{}, "script":"\(.orange_short_sensi)"}}
                    , "red_short_sensi":{"bucket_script":{
                        "buckets_path":{}, "script":"\(.red_short_sensi)"}}


                    , "outliers_total":{"sum":{"field":"outliers_total"}}
                    , "percentage_total":{"bucket_script":{
                        "buckets_path":{
                            "o":"outliers_total"
                            , "tot":"_count"},
                        "script": "params.o/params.tot"}}
                    , "orange_total":{"bucket_script":{
                        "buckets_path":{}, "script":"\(.orange_total)"}}
                    , "red_total":{"bucket_script":{
                        "buckets_path":{}, "script":"\(.red_total)"}}

                    }
                }
            }
        }
        }
    }' \
| sed '$s/$/\n/' \
| curl -s \
    https://search-predictivo-masats-5aml7qgszk3zltmyhwrwhqi4p4.eu-central-1.es.amazonaws.com/_msearch \
    --data-binary @- \
    -H content-type:application/x-ndjson \
| jq -c \
    --arg mydate "$(date +%Y-%m-%d\ 00:00:00 -d -${OFFSET}ays)" \
     --slurpfile c2m masatscode2mac.json \
    '.[][].aggregations.bus_id.buckets[]
    | {bus_id:.key
        , vehicle_name: $c2m[0][.key] 
        , serial: $c2m[0][.key] 
        , date: $mydate
        }
    + (
        .door.buckets[] | {
            door:.key
            , doc_count

            , percentage_ia: .percentage_ia.value
            , orange_ia: .orange_ia.value
            , red_ia: .red_ia.value

            , percentage_ruido: .percentage_ruido.value
            , orange_ruido: .orange_ruido.value
            , red_ruido: .red_ruido.value

            , percentage_short_sensi: .percentage_short_sensi.value
            , orange_short_sensi: .orange_short_sensi.value
            , red_short_sensi: .red_short_sensi.value

            , percentage_total: .percentage_total.value
            , red_total: .red_total.value
            , orange_total: .orange_total.value

            }
        )
    | select(.percentage_ia > .orange_ia
        or .percentage_ruido > .orange_ruido
        or .percentage_short_sensi > .orange_short_sensi
        or .percentage_total > .orange_total
        )
    | .
        + (if .percentage_ia>.red_ia
            then {ALARMA_IA_RED:"😆"}
            elif .percentage_ia>.orange_ia
            then {ALARMA_IA_ORANGE:"🍊"}
            else {}
            end)
        + (if .percentage_ruido>.red_ruido
            then {ALARMA_RUIDO_RED:"😡"}
            elif .percentage_ruido>.orange_ruido
            then {ALARMA_RUIDO_ORANGE:"🤫"}
            else {}
            end)
        + (if .percentage_short_sensi>.red_short_sensi
            then {ALARMA_SHORTSENSI_RED:"🩳"}
            elif .percentage_short_sensi>.orange_short_sensi
            then {ALARMA_SHORTSENSI_ORANGE:"🍊"}
            else {}
            end)
        + (if .percentage_total>.red_total
            then {ALARMA_TOTAL_RED:"🍎"}
            elif .percentage_total>.orange_total
            then {ALARMA_TOTAL_ORANGE:"🥤"}
            else {}
            end)
    | . + {ghost:.door}
    ' \
| sed -E 's/\.([0-9]{3})[0-9]+/.\1/g' \
| jq -Sc '[.]'
