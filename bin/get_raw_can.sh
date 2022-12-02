#!/bin/sh
### get_raw_can.sh infile - schedule candump for port/bus pairs in infile
###
### ARGUMENTS
###     infile, default "portsMS"
###         Text file with space separated port/busname pairs.
###         For instance:
###         $ cat infile
###         551/MS_11
###         552/MS_12
###         553/MS_13
###         $
###
### OUTPUT
###    A collection log-formatted and gzipped candump trace files.
###    Contuing with the previous example, the output files would be
###         log_MS_11.csv.gz
###         log_MS_12.csv.gz
###         log_MS_13.csv.gz
###

if [ "$1" = '-h' ] || [ "$1" = '--help' ]; then
    sed -rn 's/^### ?//;T;p' "$0"
    exit 0
fi

infile="${infile:-portsMS}"

if [ ! -r get_bei_data.sh ]; then
    echo "please prived" >&2
    exit 1
fi


start=$(date +%s)

while [ $(date +%s) -lt $((start+72*60*60)) ]; do
	for k in $(cat "$infile"); do
		p="${k%/*}"; b="${k#*/}";
		logfile="$log_$b.csv.gz"
		if ! lsof "$logfile" >/dev/null 2>&1; then
			sshpass -p datikinstaller ssh -C -o ConnectTimeout=10 -p "$p" \
				-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
				root@localhost \
				candump -L -n 10000 -T 3000 \
					can1,18FCA100:DFFFF00 \
					can1,18FCA200:DFFFF00 \
					can1,18FCA300:DFFFF00 \
					can1,18FCB100:DFFFF00 \
					can1,18FCC100:DFFFF00 \
					can1,18FCC200:DFFFF00 \
					can1,18FCC300:DFFFF00 \
					can1,18FCD100:DFFFF00 \
					can1,18FCE100:DFFFF00 \
				| gzip \
				>> "$logfile" &
			echo "$(date -Is) - scheduled raw can frames collection on $b"
		else
			echo "$(date -Is) - already working on $b"
		fi
	done
	sleep 60
done
