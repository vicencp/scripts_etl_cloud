#!/bin/sh

sh alarmas_masats.sh | tee /dev/fd/2 | publish2sns.py
sh alarms_ia.sh | tee /dev/fd/2 | publish2sns.py

