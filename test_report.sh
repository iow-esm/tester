if [ $# -eq 1 ]; then
	test_config=$1
else
    test_config="./test_config.example"
fi

source ${test_config}

echo "Check for mandatory settings and apply defaults."
if [ -z $src ] || [ -z ${main_dir} ] || [ -z $machine ] || [ -z $user_at_host ] || [ -z $test_dir ] || [ "${#setups[@]}" -eq 0 ]; then
    echo "Some mandatory variable is not correctly set in $test_config"
    exit
fi

# TODO factor out module loading
module load anaconda3
python3 test_report.py ${test_dir} "$setups"

# TODO comment in when everything is ready
#cd report
#./build_report.sh