#!/usr/bin/env python3
r'''
datik_csv_format2ndjson.py - datetime tab key:value csv to ndjson

DESCRIPTION
    Translate from the custom timestamp prefixed key-colon-value comma
    separated values to a newline character delimited json.

Expected sample input:
    It matches the following regular expression
        [0-9]{4}--[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}
        ,[0-9]{3} # timestamp decimal seconds
        \t # a tab character, you may need to type <CTRL><V> then <TAB>
        # as grep does not understand \t
        ([^,:]:[^,:])    # a key value pair
        (,[^,:]:[^,:])+  # optional key value pairs
    Note that at least one key value pair is expected.
All in one line
    [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2},[0-9]{3}\t[^,:]:[^,:](,[^,:]:[^,:])+

USAGE
    datik_csv_format2ndjson.py [filename]
'''
from __future__ import print_function
import argparse
import errno
import json
import os
import re
import sys
import traceback

PARSEDATETIME = True
try:
    import dateutil.parser
    import dateutil.tz as tz
    TZ = tz.gettz(os.environ.get("TZ", "GMT"))
except Exception:
    PARSEDATETIME = False


THELINE = ('2018-02-16 10:55:25,387\tcharger:CH3,e:185.2,p:0.0'
           ',p_consig:0.0,pdc_max:0.0,soc:0.0,km:0.0,lifesignal:267'
           ',alarms0:16,alarms1:0,alarms2:0,alarms3:128'
           ',vin:54_50_57_53,v_batt1:0.0,i_batt1:0.0,soc_batt1:0.0'
           ',pot_batt1:0.0,temp_batt1:0.0,v_batt2:0.0,i_batt2:0.0'
           ',soc_batt2:0.0,pot_batt2:0.0,temp_batt2:0.0,v_batt3:0.0'
           ',i_batt3:0.0,soc_batt3:0.0,pot_batt3:0.0,temp_batt3:0.0'
           ',v_batt4:0.0,i_batt4:0.0,soc_batt4:0.0,pot_batt4:0.0'
           ',temp_batt4:0.0,v_batt5:0.0,i_batt5:0.0,soc_batt5:0.0'
           ',pot_batt5:0.0,temp_batt5:0.0,v_batt6:0.0,i_batt6:0.0'
           ',soc_batt6:0.0,pot_batt6:0.0,temp_batt6:0.0,v_batt7:0.0'
           ',i_batt7:0.0,soc_batt7:0.0,pot_batt7:0.0,temp_batt7:0.0'
           ',v_batt8:0.0,i_batt8:0.0,soc_batt8:0.0,pot_batt8:0.0'
           ',temp_batt8:0.0,v_batt9:0.0,i_batt9:0.0,soc_batt9:0.0'
           ',pot_batt9:0.0,temp_batt9:0.0,v_batt10:0.0,i_batt10:0.0'
           ',soc_batt10:0.0,pot_batt10:0.0,temp_batt10:0.0'
           ',v_batt11:0.0,i_batt11:0.0,soc_batt11:0.0,pot_batt11:0.0'
           ',temp_batt11:0.0,v_batt12:0.0,i_batt12:0.0,soc_batt12:0.0'
           ',pot_batt12:0.0,temp_batt12:0.0,v_batt13:0.0,i_batt13:0.0'
           ',soc_batt13:0.0,pot_batt13:0.0,temp_batt13:0.0'
           ',v_batt14:0.0,i_batt14:0.0,soc_batt14:0.0,pot_batt14:0.0'
           ',temp_batt14:0.0,v_batt15:0.0,i_batt15:0.0'
           ',soc_batt15:0.0,pot_batt15:0.0,temp_batt15:0.0'
           ',v_batt16:0.0,i_batt16:0.0,soc_batt16:0.0'
           ',pot_batt16:0.0,temp_batt16:0.0')

NUMBER_RE = re.compile("^-?[0-9]+\\.?[0-9]*$")


def main():
    '''
    Read from input stream and if output matches the output newline
    delimited json.
    '''
    # Handle input file.
    parser = argparse.ArgumentParser()

    parser.add_argument('-f', '--file', action='store',
                        dest='input_file', default=sys.stdin,
                        type=argparse.FileType('r'))
    parser.add_argument('-t', '--timestamp-variable-name',
                        action='store', default='@timestamp',
                        dest='timestamp_variable_name',
                        help=('timestamp variable name,'
                              ' defaults to `@timestamp`'))
    parser.add_argument('--parse-timestamp',
                        action='store_true', dest='parse_timestamp',
                        help=('whether to parse and translate the'
                              ' timestamp according to env TZ'))
    parser.add_argument('--jsonify',
                        action='store_true', dest='jsonify',
                        help=('whether to parse and dump the JSON chunks'
                              ' instead of piping the stirng as is'))

    args = parser.parse_args()

    dump = print
    if args.jsonify:
        def dump(json_string): return print(json.dumps(
            json.loads(json_string),
            separators=(',', ':'),
            sort_keys=True))

    # End handling input file.
    with args.input_file as input_file:
        for line in input_file:
            try:
                json_string = line2json_string(
                    line, args.timestamp_variable_name, args.parse_timestamp)
                dump(json_string)
            except IOError as err:
                if err.errno == errno.EPIPE:
                    # Broken pipe, closing output
                    break
                else:
                    print("IO Error", file=sys.stderr)
                    traceback.print_tb(err.__dict__.get('__traceback__'))
            except ValueError as err:
                print(
                    'Wrong formatted line, sorry:\n>>> ' + line, file=sys.stderr)
                traceback.print_tb(err.__dict__.get('__traceback__'))
    return 0


def line2json_string(line, timestamp_variable_name, parse_timestamp=False):
    '''
    Transform a dm1 csv line to a JSON (as string)
    '''
    timestamp, therest = line.rstrip().split('\t', 1)
    if parse_timestamp and PARSEDATETIME:
        outtimestamp = dateutil.parser.parse(timestamp + "Z") \
            .astimezone(TZ) \
            .strftime("%Y-%m-%d %H:%M:%S,%f")[:-3]
    else:
        outtimestamp = timestamp

    json_string = '{"' + timestamp_variable_name + '":"' + outtimestamp + '"'

    for item in therest.split(','):
        try:
            variable, value = item.split(':', 1)
        except ValueError as err:
            print('Got Wrong formatted pair:\n' + item +
                  '\nrecovering and continuing on next\n', file=sys.stderr)
            print(item, file=sys.stderr)
            print(therest, file=sys.stderr)
            traceback.print_tb(err.__dict__.get('__traceback__'))
            raise err
        if not variable:
            continue
        if not NUMBER_RE.search(value):
            value = '"' + value + '"'
        json_string += ',"' + variable + '":' + value
    return json_string + '}'


def line2json(line, timestamp_variable_name):
    '''
    Transform a dm1 csv line to a JSON (as dict object)
    '''
    return json.loads(line2json_string(line, timestamp_variable_name))


if __name__ == "__main__":
    sys.exit(main())
