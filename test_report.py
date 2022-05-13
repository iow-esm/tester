import sys

test_dir = str(sys.argv[1])
setups_str = str(sys.argv[2])

setups=[]
for setup in setups_str.split("\n"):
    setups.append(setup.split(" ")[0])

from test_reporter import TestReporter

test_reporter = TestReporter(test_dir, setups)

test_reporter.check_build()
test_reporter.check_output()
test_reporter.write_summary()