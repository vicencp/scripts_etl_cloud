URL=https://search-predictivo-masats-5aml7qgszk3zltmyhwrwhqi4p4.eu-central-1.es.amazonaws.com
curl -gs "$URL"/_cat/indices \
| awk '{print $3}' \
| while read -r index; do
curl -gs -XPOST "$URL/$index/_forcemerge?only_expunge_deletes=true&max_num_segments=1"
done
