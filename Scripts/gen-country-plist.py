#!/usr/bin/env/python2.6
# -*- coding: utf-8 -*-
#
# Generate a country plist from the GeoLite GeoIP CSV file.
#

import sys
import plistlib

f = open('GeoIPCountryWhois.csv')
s = f.read()
lines = s.split('\n')
countries = {}
for line in lines:
	if not len(line):
		break
	elem = line.split(',')
	code = elem[4].strip('"')
	country = elem[5].strip('"')
	countries[code] = country
plistlib.writePlist(countries, 'Countries.plist')
