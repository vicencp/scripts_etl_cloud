#!/usr/bin/python3
'''
USAGE
    dates_in_range.py -s <start date> -n <end date>

    The date format is ISO8601, YYYY-MM-DD.
'''

import datetime
import argparse
import re
import sys

from dateutil import relativedelta


def main():
    '''
    Main function parses CLI args and loops over the date range,
    printing the results to stdout.
    '''
    expected_date_msg = 'ISO861 date string with format %%Y-%%m-%%d'

    parser = argparse.ArgumentParser()

    parser.add_argument('-s', '--start', action='store', required=True,
                        dest='start_date', help=expected_date_msg)

    parser.add_argument('-e', '--end', action='store', required=True,
                        dest='end_date', help=expected_date_msg)

    parser.add_argument('-d', '--delta', action='store', default=1,
                        dest='delta', type=int,
                        help='An integer to specify the delta time')

    parser.add_argument('-f', '--input-strftime-format', action='store',
                        default='%Y-%m-%d', dest='in_format',
                        help='input strftime format')

    parser.add_argument('-F', '--strftime-format', action='store',
                        default='%Y-%m-%d', dest='out_format',
                        help='output strftime format')

    parser.add_argument('-u', '--delta-unit', action='store', default="d",
                        dest='delta_unit', choices=["y", "Q", "M", "w",
                                                    "d", "h", "m", "s",
                                                    "ms"],
                        help='The unit of delta time used to step'
                        ' throught the dates, default is "d". Options'
                        ' are "y" years, "Q" quarters (3 months), "M"'
                        ' months, "w" weeks, "d" days, "h" hours, "m"'
                        ' minutes, "s" seconds, "ms" milliseconds')

    arguments = parser.parse_args()

    start_date = datetime.datetime.strptime(
        arguments.start_date, arguments.in_format)
    end_date = datetime.datetime.strptime(
        arguments.end_date, arguments.in_format)
    delta = period_type2deltatime(arguments.delta, arguments.delta_unit)
    moving_date = start_date
    while moving_date <= end_date:
        print(moving_date.strftime(arguments.out_format))
        moving_date += delta
    return 0


def period_type2deltatime(frecuencia, tipo_frecuencia):
    '''
    | Tiempo       | Código |
    | ------------ | ------ |
    | años         | y      |
    | trimestres   | Q      |
    | meses        | M      |
    | semanas      | w      |
    | días         | d      |
    | horas        | h      |
    | minutos      | m      |
    | segundos     | s      |
    | milisegundos | ms     |
    '''
    if tipo_frecuencia == 'y':
        delta = relativedelta.relativedelta(years=frecuencia)
    elif tipo_frecuencia == 'Q':
        delta = relativedelta.relativedelta(months=3*frecuencia)
    elif tipo_frecuencia == 'M':
        delta = relativedelta.relativedelta(months=frecuencia)
    elif tipo_frecuencia == 'w':
        delta = relativedelta.relativedelta(weeks=frecuencia)
    elif tipo_frecuencia == 'd':
        delta = relativedelta.relativedelta(days=frecuencia)
    elif tipo_frecuencia == 'h':
        delta = relativedelta.relativedelta(hours=frecuencia)
    elif tipo_frecuencia == 'm':
        delta = relativedelta.relativedelta(minutes=frecuencia)
    elif tipo_frecuencia == 's':
        delta = relativedelta.relativedelta(seconds=frecuencia)
    elif tipo_frecuencia == 'ms':
        delta = relativedelta.relativedelta(microseconds=1000*frecuencia)
    else:
        raise Exception("Gimme the right freqtype!")
    return delta


if __name__ == '__main__':
    sys.exit(main())
