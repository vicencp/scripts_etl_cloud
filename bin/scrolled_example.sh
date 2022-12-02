#!/bin/sh
HELPMESSAGE="scrolled_example.sh - scrolled ES search, one json result per line

USAGE
    scrolled_example.sh [-h/--help] esindex query_file [URL]

    output goes to STDOUT

OPTIONS
    -h, --help
        Print this help message and exit.

OUTPUT
    It pipes to STDOUT all the items matching the query as json
    documents, one per line.

ARGUMENTS

    esindex
        The ES index to search in, it will be globbed
        Default: datik-test.

    query_file
        A json file contain the ES query to be performed.
        Default: stdin.

    URL
        The ES url endpoint.

REQUIREMENTS
    curl, jq, a bourne shell"

if [ "$1" = '--help' ] || [ "$1" = '-h' ]; then
    echo "$HELPMESSAGE"
    exit 0
fi

index="${1:-main}"
query_file="${2:--}"
url="${3:-https://search-predictivo-masats-5aml7qgszk3zltmyhwrwhqi4p4.eu-central-1.es.amazonaws.com}"

count=0
idx="$(printf '%05d' "$count")"
folder="$(mktemp -d "/tmp/scrolled_${index}_XXXXXX")"
echo "$folder" >&2

# set up a cleanup trap!
trap "rm -rf -- '$folder'" INT TERM EXIT

curl -gs -XPOST "${url}/${index}*/_search?scroll=1m" \
    -H 'Content-Type: application/json' -d@"${query_file}" \
    > "${folder}/${idx}.json"
#jq . "${folder}/${idx}.json" >&2

_scroll_id="$(jq -r ."_scroll_id" "$folder/$idx.json")"
json="{\"scroll\" : \"1m\", \"scroll_id\" : \"${_scroll_id}\"}"
length="$(jq -r ".hits.hits|length" "$folder/$idx.json")"
total="$(jq -r ".hits.total" "$folder/$idx.json")"
partial=0

printf '\r%s of %s' "$partial" "$total" >&2
while [ "$length" != 0 ]; do
    # This line pipes the result to STDOUT:
    jq -Sc '.hits.hits[]._source' "${folder}/${idx}.json"

    count="$((count + 1))"
    partial="$((partial + length))"
    printf '\r%s of %s' "$partial" "$total" >&2

    idx="$(printf '%05d' "$count")"

    curl -sg -XPOST "${url}/_search/scroll" \
        -H 'Content-Type: application/json' -d"$json" \
        > "$folder/$idx.json"

    length="$(test -f "$folder/$idx.json" &&
        jq -r ".hits.hits|length" "$folder/$idx.json" ||
        echo 0)"
done

# 一緒に旅行！何処でもいいです。
