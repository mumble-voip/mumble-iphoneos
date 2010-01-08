#!/bin/bash
#
# Convert svg icons to pdf for use on the iPhone
#
for i in `ls ./icons/svg/*.svg`; do
	svg2pdf $i > icons/`basename ${i%.svg}.pdf`
done
