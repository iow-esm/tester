import glob
import os

class TestReporter:

    def __init__(self, test_dir, setups, report_dir = "./report"):

        self.test_dir = test_dir
        self.report_dir = report_dir
        self.setups = setups

        self.intro_file_name = self.report_dir + "/intro.md"
        with open(self.intro_file_name, "w") as file:
            file.write("# IOW ESM test report\n\n\n")

        self.binaries = {
            "components/CCLM" : "cclm/bin_PRODUCTION/lmparbin",
            "components/MOM5" : "exec/IOW_ESM_PRODUCTION/MOM_SIS/fms_MOM_SIS.x",
            "components/flux_calculator" : "bin_PRODUCTION/flux_calculator",
            "components/OASIS3-MCT" : "oasis3-mct/IOW_ESM_PRODUCTION/*",
            "tools/I2LM" : "int2lm/bin_PRODUCTION/int2lm.exe"
        }

        self.summary = {}

    def check_build(self):

        build_report_dir = self.report_dir+"/build"
        os.system("mkdir "+build_report_dir)

        check_build_file_name = build_report_dir+"/build.md"
        with open(check_build_file_name, "w") as file:
            file.write("# IOW ESM build report\n\n\n")

            for component in self.binaries.keys():
                file.write("## Build report for "+component+"\n\n")
                found_binaries = glob.glob(self.test_dir+"/base/"+component+"/"+self.binaries[component])
                
                if not found_binaries:
                    file.write("**Could not find binary "+self.binaries[component]+" for "+component+"**\n")
                    self.summary["Build:"+component] = False
                else:
                    file.write("Binaries "+str(found_binaries)+" has been built for "+component+"\n")
                    self.summary["Build:"+component] = True

                file.write("\n\n")

    def check_output(self):
        output_report_dir = self.report_dir+"/output"
        os.system("mkdir "+output_report_dir)

        check_output_file_name = output_report_dir+"/output.md"
        with open(check_output_file_name, "w") as file:
            file.write("# IOW ESM output report\n\n\n")
            for setup in self.setups:
                file.write("## Output report for "+setup+"\n\n")

                found_output = glob.glob(self.test_dir+"/"+setup+"/output/*")
                if not found_output:
                    file.write("**Could not find output for "+setup+"**\n")
                    self.summary["Output:"+setup] = False
                else:
                    file.write("Output "+str(found_output)+" has been generated for "+setup+"\n")
                    self.summary["Output:"+setup] = True

                file.write("\n\n")
    
    def write_summary(self):
        failed = 0
        with open(self.intro_file_name, "a") as file:
            file.write("## Summary\n\n")

            file.write("| checkpoint       | success  |\n")
            file.write("|---               |---       |\n")
            for checkpoint in self.summary.keys():
                file.write("|"+checkpoint+"|"+str(self.summary[checkpoint])+"|\n")

                if not self.summary[checkpoint]:
                    failed += 1

            if failed > 0:
                file.write("\n"+str(failed)+" two checkpoints failed!\n")
