#!/usr/bin/python3
'''
Python3 csv 2 json converter.
BEWARE: it's just a kludge/grok.

Usage:

python3 csv2json.py <file.csv

Prints a json representation of the input csv.
It requires a csv header line to be present, else it will print a very
weird output.
'''

import argparse
import csv
import json
import re
import sys

SASIVIN_REGEX = re.compile(r'^[0-9]{2}(_[0-9]{2}){16}^')

def main():
    '''
    The ordered list of objects is stored in an array called json_array:
    Or just pipe the output to a json pretty printer, remember to do one
    thing at a time and to do it well. Pretty pringting via python can
    be done with

    print(json.dumps(json_array, indent=2))

    The workflow is simple: read from stdin, write to stdout. You may
    then pipe it to another file or read it straight out of stdout, as
    you please.

    Happy hackin'!

    >>> import os
    >>> os.popen("printf 'a,b,c,d\\n,,a,b\\n3,2,x,c\\n' | ./csv2json.py").read()
    '[{"c": "a", "d": "b"}, {"a": "3", "b": "2", "c": "x", "d": "c"}]\\n'
    '''

    parser = argparse.ArgumentParser()

    parser.add_argument('-i', '--input-file', action='store',
                        dest='input_stream', default=sys.stdin,
                        type=argparse.FileType('r'))

    parser.add_argument('-d', '--delimiter', action='store',
                        dest='delimiter', default=',',
                        type=lambda x: ('\t' if x in ('\\t', 'tab') else x))

    args = parser.parse_args()

    with args.input_stream as csvfile:
        reader = csv.DictReader(csvfile, delimiter=args.delimiter)
        print('[')
        z = 0
        values_dict = get_values_dict(next(reader), 0)
        if values_dict:
            print(json.dumps(values_dict, ensure_ascii=False))
            z = 1
        for n, row in enumerate(reader, z):
            values_dict = get_values_dict(row, n)
            if values_dict:
                print((', ' if z else '') +
                      json.dumps(values_dict, ensure_ascii=False))
        print(']')

    return 0  # Everything's gone well, 0 errors!

def get_values_dict(row, n):
    '''
    Given a row, get its non-falsy values dict.
    '''
    values_dict = None
    try:
        values_dict = {key: bangjson(row[key])
                       for key in row
                       if row[key] != '' or row[key] is not None}
    except TypeError:
        print("Error in parsing line", n, file=sys.stderr)
        print(row, file=sys.stderr)
    return values_dict

def bangjson(item):
    ''' Try to convert to a json value '''
    result = item
    try:
        result = json.loads(item)
    except json.JSONDecodeError:
        pass
    if SASIVIN_REGEX.match(item):
        result = ''.join(chr(int(k)) for k in item.split('_'))
    return result


if __name__ == '__main__':
    sys.exit(main())
