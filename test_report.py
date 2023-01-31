import sys

target = str(sys.argv[1])
dest = str(sys.argv[2])
setups_str = str(sys.argv[3])


setups=[]
for setup in setups_str.split("\n"):
    setups.append(setup.split(" ")[0])

from test_reporter import TestReporter

test_reporter = TestReporter(target, dest, setups)

test_reporter.check_build()
test_reporter.check_output()
test_reporter.write_summary()