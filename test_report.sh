#!/bin/bash

if [ $# -eq 1 ]; then
	test_config=$1
else
    test_config="./test_config.example"
fi

source ${test_config}

echo "Check for mandatory settings and apply defaults."
if [ -z "$src" ] || [ -z "${main_dir}" ] || [ -z "${destination}" ] || [ "${#setups[@]}" -eq 0 ]; then
    echo "Some mandatory variable is not correctly set in $test_config"
    exit
fi

for keyword in  `awk '{print $1}' ${main_dir}/DESTINATIONS` ; do
    if [ "${keyword##*_}" == "sync" ]; then
        sync_targets=(${sync_targets[@]} $keyword)
        continue
    fi

    # skip automatically added destinations

    # for different setups
    for setup in `awk '{print $1}' ${main_dir}/SETUPS`; do
        if [[ "${keyword}" =~ "${setup}" ]]; then
            continue 2
        fi
    done

    # for the base
    if [[ "${keyword}" =~ "_base" ]]; then
        continue 
    fi

    run_targets=(${run_targets[@]} $keyword)


done

cat <<EOF > report/intro.md
# IOW ESM test report

This is an IOW ESM test report.
The test thas been performed in `${run_targets[@]}`.

EOF

for run_target in "${run_targets[@]}"; do

    source ${main_dir}/local_scripts/identify_target.sh ${run_target}

    # test if target is associated with any setup

    #echo ${target} ${dest} ${dest_folder} ${user_at_dest}

    python3 test_report.py ${run_target} ${dest} "$setups" 

done

cd report
source ./build_report.sh

for d in `ls -d  output_*/*/*/figures`; do
    cp -r $d _build/html/$d
done