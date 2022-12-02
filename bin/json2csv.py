#!/usr/bin/python3
# -*- coding: utf-8 -*-
'''
Python3 json 2 csv converter. It tries to handle JSON formatted input from
stdin and pipes out a csv.
BEWARE: it's just a kludge/grok.

Usage:

python3 json2csv.py [args...]

Prints a csv with the given attributes if it can.
If any of the attr is *, all or All, then all columns are printed.
'''

import argparse
import csv
import errno
import json
import sys
from collections import OrderedDict


def main():
    '''
    take (nd)json output csv
    '''

    # The headers are just the keys in each json (which we expect to be constant
    # thoughout the array)
    parser = argparse.ArgumentParser(description='''
        Convert a json input (an array of objects)
        to a csv file in which each row corresponds to each
        item in the json array.''')

    parser.add_argument('-i', '--input-file', action='store',
                        dest='input_file', default=sys.stdin,
                        type=argparse.FileType('r'))

    parser.add_argument('-D', '--output-delimiter',
                        help='delimiter to be used in the output',
                        dest='out_delimiter', type=str,
                        default=',')

    parser.add_argument('-C', '--column-names',
                        dest='cname',
                        nargs='*', default=None,
                        help='The column names, at least one please.')

    parser.add_argument('--ndjson', dest='ndjson', action='store_true',
                        help='Whether to take one object per line.')

    args = parser.parse_args()

    if args.ndjson:
        rows = (json.loads(line) for line in args.input_file)
    else:
        rows = (d for d in json.load(args.input_file))

    try:
        row = next(rows)
    except StopIteration:
        print("json2csv.py [ERROR]: Empty input, provide some lines please",
              file=sys.stderr)
        return 1

    if args.cname is not None:
        key_list = list(OrderedDict([(k,0) for k in args.cname]).keys())
    elif not args.ndjson:
        rows = list(rows)
        key_list = list(OrderedDict([(key,0)
                            for token in rows+[row]
                            for key in token]).keys())
    else:
        key_list = list(OrderedDict([(k,0)for k in row]).keys())

    # Create a writer object, let the `csv` library deal with the edge
    # cases of poorly specified, greatly varying csv's in the wild.
    writer = csv.DictWriter(sys.stdout, fieldnames=key_list,
                            extrasaction='ignore',
                            delimiter=args.out_delimiter.replace('\\t', '\t'))

    # Then we `print' the header, i.e. pipe it to stdout.
    writer.writeheader()

    # As for the rows, we go through each object in the array and we print the
    # values in a CSV (comma separated values) fashion.
    writer.writerow(row)
    for row in rows:
        writer.writerow(row)

    # happy hackin'!
    #
    #
    # PS: you may pipe it to another file or read it straight out
    # of stdout, as you please.
    return 0


if __name__ == "__main__":
    code = 0
    try:
        code = main()
    except IOError as e:
        if e.errno == errno.EPIPE:
            code = 0
    sys.exit(code)
