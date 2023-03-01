#!/bin/bash

# clean last build
rm -r _build/html _build/.doctrees

# build _toc.yml
python3 get_files.py

# build book
jupyter-book build -v --keep-going --all --builder pdfhtml .
jupyter-book build -v --keep-going --all .

# prepare folder for github-pages
touch _build/html/.nojekyll
mv _build/html _build/docs

# using github pages:
# created _build folder should be a git repository that should be pushed to https://github.com/sven-karsten/iow_esm.git
# this github repository must have github-pages enabled
# html content of the docs folder is then available under https://sven-karsten.github.io/iow_esm/intro.html

