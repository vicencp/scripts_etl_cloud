# Specific augmentation for Masats TMB and EMT

def ymdHMS2secs:
    strptime("%Y-%m-%d %H:%M:%S") | strftime("%s") | tonumber;

def tomillis:
    split(",")
    | (.[0]|ymdHMS2secs) as $s
    | (pow(10; 3-(.[1]|length)) * (.[1]|tonumber)) as $ms
    | $s*1000+$ms;

def getcodigo:
    ."@timestamp" as $timestamp
    | .serial as $serial
    | $listfile[0] // []
    | map(select(
        (.serial|ascii_upcase) == ($serial|ascii_upcase)
        and $timestamp > .desde))
    | sort_by(.desde)[-1].codigo;

(.vehicleCode // getcodigo) as $codigo
| ((.TIEMPO_MANIOBRA_ABRIR>0)
    or (.TIEMPO_MANIOBRA_MOTOR_1_ABRIR>0)
    or (.TIEMPO_MANIOBRA_MOTOR_2_ABRIR>0)) as $abrir

| ((.TIEMPO_MANIOBRA_CERRAR>0)
    or (.TIEMPO_MANIOBRA_MOTOR_1_CERRAR>0)
    or (.TIEMPO_MANIOBRA_MOTOR_2_CERRAR>0)) as $cerrar

| (.CONSUMO_MOTOR_1==1 or .CONSUMO_MOTOR_2==1 or .FOTOCELULA==1)
    as $sensibilizacion

| . + {
    codRecurso: $codigo
    , idRecurso: $codigo
    , resourceCode: $codigo
    , timestamp_maniobra_millis: (."@timestamp"|tomillis)
    , ABRIR: $abrir
    , CERRAR: $cerrar
    , FUERA_DE_MANIOBRA: (($abrir|not) and ($cerrar|not))
    , DENTRO_O_FUERA_DE_MANIOBRA: true
    , metavar_sensibilizacion: $sensibilizacion
}

# aplicar factor de escalado
# como los factores son de coma flotante y la versión original no
# filtramos con eso
| with_entries(
    (.value| (tostring|split(".")[1]) == null and type=="number") as $isnotfloat
    | if ((.key[:13] == "CONSUMO_MEDIO" or .key[:12] == "CONSUMO_PICO")
            and $isnotfloat) then
        .value |= (.*0.003223|.*100000|floor/100000)
    elif (.key[:9] == "Consumo_m" and $isnotfloat and $codigo[:3] !="MS_") then
        .value |= (.*0.05156|.*100000|floor/100000)
    else
        .
    end
)





























# ───────────────▄████████▄────────
# ─────────────▄█▀▒▒▒▒▒▒▒▀██▄──────
# ───────────▄█▀▒▒▒▒▒▒▒▒▒▒▒██──────
# ─────────▄█▀▒▒▒▒▒▒▄▒▒▒▒▒▒▐█▌─────
# ────────▄█▒▒▒▒▒▒▒▒▀█▒▒▒▒▒▐█▌─────
# ───────▄█▒▒▒▒▒▒▒▒▒▒▀█▒▒▒▄██──────
# ──────▄█▒▒▒▒▒▒▒▒▒▒▒▒▀█▒▄█▀█▄─────
# ─────▄█▒▒▒▒▒▒▒▒▒▒▒▒▒▒██▀▒▒▒█▄────
# ────▄█▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒█▄───
# ───▄█▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒█▄──
# ──▄█▒▒▒▄██████▄▒▒▒▒▄█████▄▒▒▒▒█──
# ──█▒▒▒█▀░░░░░▀█─▒▒▒█▀░░░░▀█▒▒▒█──
# ──█▒▒▒█░░▄░░░░▀████▀░░░▄░░█▒▒▒█──
# ▄███▄▒█▄░▐▀▄░░░░░░░░░▄▀▌░▄█▒▒███▄
# █▀░░█▄▒█░▐▐▀▀▄▄▄─▄▄▄▀▀▌▌░█▒▒█░░▀█
# █░░░░█▒█░▐▐──▄▄─█─▄▄──▌▌░█▒█░░░░█
# █░▄░░█▒█░▐▐▄─▀▀─█─▀▀─▄▌▌░█▒█░░▄░█
# █░░█░█▒█░░▌▄█▄▄▀─▀▄▄█▄▐░░█▒█░█░░█
# █▄░█████████▀░░▀▄▀░░▀█████████░▄█
# ─██▀░░▄▀░░▀░░▀▄░░░▄▀░░▀░░▀▄░░▀██
# ██░░░░░░░░░░░░░░░░░░░░░░░░░░░░░██
# █░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░█
# █░▄░░░░░░░░░░░░░░░░░░░░░░░░░░░▄░█
# █░▀█▄░░░░░░░░░░░░░░░░░░░░░░░▄█▀░█
# █░░█▀███████████████████████▀█░░█
# █░░█────█───█───█───█───█────█░░█
# █░░▀█───█───█───█───█───█───█▀░░█
# █░░░▀█▄▄█▄▄▄█▄▄▄█▄▄▄█▄▄▄█▄▄█▀░░░█
# ▀█░░░█──█───█───█───█───█──█░░░█▀
# ─▀█░░▀█▄█───█───█───█───█▄█▀░░█▀─
# ──▀█░░░▀▀█▄▄█───█───█▄▄█▀▀░░░█▀──
# ───▀█░░░░░▀▀█████████▀▀░░░░░█▀───
# ────▀█░░░░░▄░░░░░░░░░▄░░░░░█▀────
# ─────▀██▄░░░▀▀▀▀▀▀▀▀▀░░░▄██▀─────
# ────────▀██▄▄░░░░░░░▄▄██▀────────
# ───────────▀▀███████▀▀─────────── 
