#!/bin/sh

curl -gsG https://search-predictivo-masats-5aml7qgszk3zltmyhwrwhqi4p4.eu-central-1.es.amazonaws.com/tmb_masats@,emt_madrid@,masats_singapur@/_search \
    --data-urlencode size=1000 \
    --data-urlencode _source=sendData,manoeuvre_name,ALIMENTACION,CC_MOTOR_HD_MOTOR_D,CC_MOTOR_T,FDC_HD_NO_CONECTADO,G3C8_MICROCERRADAPARADA,G3C9_MICROCERRADA,G4C2_IMANBLO,G4C5_OUT3,G3C6_ALIMENTACION,G4C1_MOTOR,G4CC_OUT10,G5C8_ALIMENTACION_12V,@timestamp,serial \
    --data-urlencode 'q=sendData:[now-100d TO now] AND (
        manoeuvre_name:p1 AND (
            ALIMENTACION:1
            OR CC_MOTOR_HD_MOTOR_D:1
            OR CC_MOTOR_T:1)
        ) OR (
        manoeuvre_name:p2 AND (
            ALIMENTACION:1
            OR FDC_HD_NO_CONECTADO:1
            OR CC_MOTOR_HD_MOTOR_D:1)
        ) OR (
        manoeuvre_name:p3 AND (
            ALIMENTACION:1 OR
            FDC_HD_NO_CONECTADO:1 OR
            CC_MOTOR_HD_MOTOR_D:1)
        ) OR (
        manoeuvre_name:re1 AND (
            G3C6_ALIMENTACION:1
            OR G3C8_MICROCERRADAPARADA:1
            OR G3C9_MICROCERRADA:1
            OR G4C2_IMANBLO:1
            OR G4C5_OUT3:1
            OR G5C8_ALIMENTACION_12V:1)
        ) OR (
        manoeuvre_name:rt1 AND (
            G3C6_ALIMENTACION:1
            OR G4C1_MOTOR:1
            OR G4CC_OUT10:1
            OR G5C8_ALIMENTACION_12V:1
            OR G6C6_XAPALETA_NO_DESBLOQUEA:1
            OR G6C5_XAPALETA_NO_BLOQUEA:1
            )
        )' \
| tee /dev/fd/2 \
| jq -c '.hits.hits[]._source' \
| tee /dev/fd/2 \
| jq -c '
    {
      "p1": {
        "ALIMENTACION": true,
        "CC_MOTOR_HD_MOTOR_D": true,
        "CC_MOTOR_T": true
      },
      "p2": {
        "ALIMENTACION": true,
        "FDC_HD_NO_CONECTADO": true,
        "CC_MOTOR_HD_MOTOR_D": true
      },
      "p3": {
        "ALIMENTACION": true,
        "FDC_HD_NO_CONECTADO": true,
        "CC_MOTOR_HD_MOTOR_D": true
      },
      "re1": {
        "G3C6_ALIMENTACION": true,
        "G3C8_MICROCERRADAPARADA": true,
        "G3C9_MICROCERRADA": true,
        "G4C2_IMANBLO": true,
        "G4C5_OUT3": true,
        "G5C8_ALIMENTACION_12V": true
      },
      "rt1": {
        "G3C6_ALIMENTACION": true,
        "G4C1_MOTOR": true,
        "G4CC_OUT10": true,
        "G5C8_ALIMENTACION_12V": true,
        "G6C6_XAPALETA_NO_DESBLOQUEA": true,
        "G6C5_XAPALETA_NO_BLOQUEA": true
      }
    }
    as $f
    | .manoeuvre_name as $m
    | ($f[$m]//{}) as $alarm_names
    | {
        date: (."@timestamp"|split(","))[0],
        lat: "\(.lat)",
        lon: "\(.lon)",
        duration: "0",
        vehicle_name: .serial
    } as $prev
    | [to_entries[].key | select($alarm_names[.] == true)]
    | select(. != [])
    | join(", ")
    | $prev + { label: "\($m): \(.)", id: "100", type_id: "25" }
    | [.]
'
