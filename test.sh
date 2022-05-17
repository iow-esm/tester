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

echo "Apply test config: set version, main_dir, machine, user_at_host, test_dir, setups."
source ${test_config}

echo $src ${main_dir} $machine $user_at_host $test_dir $setups

echo "Check for mandatory settings and apply defaults."
if [ -z $src ] || [ -z ${main_dir} ] || [ -z $machine ] || [ -z $user_at_host ] || [ -z $test_dir ] || [ "${#setups[@]}" -eq 0 ]; then
    echo "Some mandatory variable is not correctly set in $test_config"
    exit
fi

mkdir -p ${main_dir}

if [ -d $src ]; then
    echo "Synchronize contents from ${version}/* to ${main_dir}/"
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

echo "Register the base destination ${machine}_base ${user_at_host}:${test_dir}/base"
echo "${machine}_base ${user_at_host}:${test_dir}/base" > DESTINATIONS

echo "Build the components..."
./build.sh ${machine}_base
echo "done."

echo "$setups" > SETUPS

echo "Run all the given test setups..."
for setup in `awk '{print $1}' SETUPS`; do

        echo "  Prepare work directory for setup $setup."
        ssh -t ${user_at_host} "if [ -d ${test_dir}/${setup} ]; then rm -r ${test_dir}/${setup}; fi"
        ssh -t ${user_at_host} "cp -as ${test_dir}/base ${test_dir}/${setup}"

        echo "  Register specific destination."
        echo "${machine}_${setup} ${user_at_host}:${test_dir}/${setup}" >> DESTINATIONS

        echo "  Deploy test setup $setup"
        ./deploy_setups.sh ${machine}_${setup} ${setup}

        echo "  Run setup $setup"
        ./run.sh ${machine}_${setup}
done

let finished=0
while  [ ${finished} -lt `cat SETUPS | wc -l` ]; do
    let finished=0
    for setup in `awk '{print $1}' SETUPS`; do
        marker=`ssh -t ${user_at_host} "if [ -f ${test_dir}/${setup}/*_finished.txt ]; then echo ${setup}; fi"`
        if [ "$marker" == "$setup" ]; then
            let finished++
        fi
    done
    sleep 10
done
# TODO
# wait for for jobs to be finished (however this could be done)
# and then
# ./test_report.sh ${test_config}
