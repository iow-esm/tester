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

if [ -z "${from_scratch}" ]; then
    from_scratch=false
fi

if ${from_scratch}; then
    if [ -d "${main_dir}" ]; then
        echo "Remove existing ${main_dir}"
        rm -rf ${main_dir}
    fi
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

run_targets=()
sync_targets=()

for keyword in  `awk '{print $1}' ./DESTINATIONS` ; do
    if [ "${keyword##*_}" == "sync" ]; then
        sync_targets=(${sync_targets[@]} $keyword)
        continue
    fi

    run_targets=(${run_targets[@]} $keyword)

done

echo "$setups" > SETUPS

echo ""
echo "##   Testing with following targets/setups   ##"
echo "###############################################"
echo ""

for run_target in "${run_targets[@]}"; do
    for setup in `awk '{print $1}' SETUPS`; do
        if [ "${setup%%_*}" != "${run_target%%_*}" ]; then
            continue
        fi
        sync_to=""
        for sync_target in "${sync_targets[@]}"; do
            if [[ "${sync_target}" =~ "${setup}" ]]; then
                sync_to="| synchronize to: "${sync_target}
                break
            fi
        done
        echo "Run on:" $run_target $sync_to "| with setup: "$setup
    done
done



total_runs=0
for run_target in "${run_targets[@]}"; do

    source ./local_scripts/identify_target.sh ${run_target}

    if ${from_scratch}; then
        echo "Remove ${dest} if existing..."
        ssh -t ${user_at_dest} "if [ -d ${dest_folder} ]; then rm -r ${dest_folder}; fi"
    fi

    echo "Register base directory for all setups."
    echo "${target}_base ${dest}/base" >> DESTINATIONS

    echo "Build the components..."
    ./build.sh ${target}_base
    echo "done."

    echo "$setups" > SETUPS

    echo "Run all the given test setups..."
    for setup in `awk '{print $1}' SETUPS`; do

        if [ "${setup%%_*}" != "${run_target%%_*}" ]; then
            continue
        fi

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
            let total_runs=total_runs+1
        done

        for sync_target in "${sync_targets[@]}"; do
            if [[ ! "${sync_target}" =~ "${setup}" ]]; then
                continue
            fi

            if ${from_scratch}; then
                sync_dest="`awk -v dest="${sync_target}" '{if($1==dest){print $2}}' ./DESTINATIONS`"
                echo "Remove ${sync_dest} if existing..."
                user_at_sync_dest="${sync_dest%:*}"
                sync_dest_folder="${sync_dest#*:}"
                ssh -t ${user_at_sync_dest} "if [ -d ${sync_dest_folder} ]; then rm -r ${sync_dest_folder}; fi"
            fi

            ./sync.sh "${target}_${setup}" "${sync_target}"
            break
        done

         
    done

done

echo "Waiting for test jobs to finish..."

#TODO: this loop stops too early if more than one target is involved
let finished=0
while [ ${finished} -lt ${total_runs} ]; do

    for run_target in "${run_targets[@]}"; do

        source ./local_scripts/identify_target.sh ${run_target} > /dev/null 2>&1

        for setup in `awk '{print $1}' SETUPS`; do

            if [ "${setup%%_*}" != "${run_target%%_*}" ]; then
                continue
            fi

            done=${setup}_done
            if [ "${!done}" == true ]; then
                continue
            fi

            dirs=(`ssh ${user_at_dest} "if [ -d ${dest_folder}/${setup}/input ]; then ls ${dest_folder}/${setup}/input; fi"`)
            if [[ "${dirs[*]}" =~ "global_settings.py" ]]; then 
                dirs=("")
            fi
            success=`ssh -t ${user_at_dest} "ls ${dest_folder}/${setup}/*_finished.txt 2> /dev/null | wc -l" | sed s.'\r'.''.g`
            failed=`ssh -t ${user_at_dest} "ls ${dest_folder}/${setup}/*_failed.txt 2> /dev/null | wc -l" | sed s.'\r'.''.g`
            let completed=0
            let completed=completed+success+failed
            if [[ "$completed" == "${#dirs[@]}" ]]; then 
                let finished=finished+completed
                eval ${setup}_done=true
                echo "   Setup $setup done."
                continue 3 # skip waiting in while loop since this might be the last setup
            fi
        done
    done
    sleep 30
done
echo "... done."

echo "Create test report..."
cd -
./test_report.sh ${test_config}
echo "... done."
