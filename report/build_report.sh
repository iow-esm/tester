#!/bin/bash

# TODO factor out module loading 
module load miniconda3
# necessary steps for first time
#conda create --name jupyterbook
conda activate jupyterbook
#conda install -c conda-forge jupyter-book

# clean last build
rm -r _build/docs _build/.doctrees

# build _toc.yml
python3 get_files.py

# build book
jupyter-book build -v --keep-going --all .

# prepare folder for github-pages
mv _build/html _build/docs
touch _build/docs/.nojekyll

# using github pages:
# created _build folder should be a git repository that should be pushed to https://github.com/sven-karsten/iow_esm.git
# this github repository must have github-pages enabled
# html content of the docs folder is then available under https://sven-karsten.github.io/iow_esm/intro.html

