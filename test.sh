#!/bin/bash

echo "###############################################"
echo "##                                           ##"
echo "##          IOW earth-system model           ##"
echo "##                                           ##"
echo "###############################################"
echo ""
echo "###############################################"
echo "##            Testing the model              ##"
echo "###############################################"
echo ""

if [ $# -gt 1 ]; then
	echo "Usage: `basename "$0"` [<test_config>]"
	echo "<test_config> path to a test config file."
    echo "If left empty the test_config.example is used: user-specific!"
	exit
fi

if [ $# -eq 1 ]; then
	test_config=$1
else
    test_config="./test_config.example"
fi

echo "Apply test config: set version, main_dir, destinations, setups."
source ${test_config}

echo "Check for mandatory settings and apply defaults."
if [ -z "$src" ] || [ -z "${main_dir}" ] || [ -z "${destination}" ] || [ "${#setups[@]}" -eq 0 ]; then
    echo "Some mandatory variable is not correctly set in $test_config"
    exit
fi

mkdir -p ${main_dir}

if [ -d $src ]; then
    echo "Synchronize contents from ${src} to ${main_dir}/"
    rsync -avz --exclude "tester" --exclude ".git" `realpath ${src}`/* `realpath ${main_dir}`/ --delete
    cd ${main_dir}
else
    echo "Create main directory ${main_dir}"

    cd ${main_dir}

    if [ -d .git ]; then
        echo "Update main repository from https://git.io-warnemuende.de/iow_esm/main.git"
        git pull https://git.io-warnemuende.de/iow_esm/main.git $src
    else
        echo "Get main repository from https://git.io-warnemuende.de/iow_esm/main.git"
        git clone --branch $src https://git.io-warnemuende.de/iow_esm/main.git .
    fi

    echo "Get all other reposirtories"
    ./clone_origins.sh
fi    

echo "Register the configured destination"
echo "${destination}" > DESTINATIONS

for keyword in `awk '{if(NR==1){print $1}}' ./DESTINATIONS` ; do

    source ./local_scripts/identify_target.sh ${keyword}

    echo ${target} ${dest} ${dest_folder} ${user_at_dest}

    echo "Register base directory for all setups."
    echo "${target}_base ${dest}/base" >> DESTINATIONS

    echo "Build the components..."
    ./build.sh ${target}_base
    echo "done."

    echo "$setups" > SETUPS

    echo "Run all the given test setups..."
    for setup in `awk '{print $1}' SETUPS`; do

        echo "  Prepare work directory for setup $setup."
        ssh -t ${user_at_dest} "if [ -d ${dest_folder}/${setup} ]; then rm -r ${dest_folder}/${setup}; fi"
        ssh -t ${user_at_dest} "cp -as ${dest_folder}/base ${dest_folder}/${setup}"

        echo "  Register specific destination."
        echo "${target}_${setup} ${dest}/${setup}" >> DESTINATIONS

        echo "  Deploy test setup $setup"
        ./deploy_setups.sh ${target}_${setup} ${setup}

        dirs=(`ssh ${user_at_dest} "if [ -d ${dest_folder}/${setup}/input ]; then ls ${dest_folder}/${setup}/input; fi"`)
        if [[ "${dirs[*]}" =~ "global_settings.py" ]]; then 
            dirs=("")
        fi

        echo "  Run setup $setup"
        for d in "${dirs[@]}"; do 
            echo "   with input folder $d"
            ./run.sh ${target}_${setup} prepare-before-run $d
        done
    done

done

let finished=0
while  [ ${finished} -lt `cat SETUPS | wc -l` ]; do
    let finished=0
    for setup in `awk '{print $1}' SETUPS`; do
        marker=`ssh -t ${user_at_dest} "if [ -f ${dest_folder}/${setup}/*_finished.txt ]; then echo -n ${setup}; fi"`
        if [ "$marker" == "$setup" ]; then
            let finished++
        fi
    done
    sleep 10
done

exit

cd -
./test_report.sh ${test_config}
