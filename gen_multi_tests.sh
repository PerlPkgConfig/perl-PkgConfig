#!/bin/sh
cd t
templ=iterfiles_template
test_base="02-iterfiles"
find usr | split -l 50 - FLIST

for f in FLIST*; do
    cp $templ "$test_base-$f.t"
done
