import glob
import os
import subprocess

class Logger:
    def __init__(self, directory, file_name, parent = None, overwrite = True):
        self.directory = directory
        self.file_name = file_name
        self.parent = parent
        if glob.glob(self.directory) and overwrite:
            os.system("rm -r "+self.directory)
        os.system("mkdir -p "+self.directory)
        self.file_path = self.directory+'/'+self.file_name

        if overwrite:
            self.file = open(self.file_path, "w")
        else:
            self.file = open(self.file_path, "a")

        if self.parent is not None:
            self.parent.report_files.append(self.file_path)
    
    def log(self, text):
        self.file.write(text)

    def __del__(self):
        self.file.close()

class TestReporter:

    def __init__(self, target, dest, setups, report_dir = "./report"):

        self.target = target
        self.dest = dest
        self.report_dir = report_dir
        self.setups = setups

        self.binaries = {
            "components/CCLM" : ["cclm/bin_PRODUCTION/lmparbin"],
            "components/MOM5" : ["exec/IOW_ESM_PRODUCTION/MOM_SIS/fms_MOM_SIS.x"],
            "components/flux_calculator" : ["bin_PRODUCTION/flux_calculator"],
            "components/OASIS3-MCT" : ["oasis3-mct/IOW_ESM_PRODUCTION/build/lib/psmile.MPI1/*", "oasis3-mct/IOW_ESM_PRODUCTION/build/lib/mct/*", "oasis3-mct/IOW_ESM_PRODUCTION/lib/*"],
            "tools/I2LM" : ["int2lm/bin_PRODUCTION/int2lm.exe"]
        }

        self.summary = {}
        self.report_files = []

        self.user_at_host, self.host_path = self.dest.split(":")

        self.summary_logger = Logger(self.report_dir, "intro.md", self, overwrite=False)
        self.summary_logger.log("\n\n## Test summary for "+self.target+"\n\n")

        print("# Reporter for "+self.target+" started.")

    def _glob_remote(self, pattern):
        cmd = "ssh "+self.user_at_host+" \"ls "+pattern+" 2> /dev/null\""
        sp = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE)
        output = sp.stdout.read().decode("utf-8").split("\n")
        return [i for i in output if i != ""]      

    def check_build(self):

        print("Check build...")

        logger = Logger(self.report_dir+"/build_"+self.target, "build.md", self)
        logger.log("# IOW ESM build report\n\n\n")

        for component in self.binaries.keys():
            logger.log("## Build report for "+component+"\n\n")

            found_binaries = []

            for binary in self.binaries[component]:
                found_binaries = self._glob_remote(self.host_path+"/base/"+component+"/"+binary)
            
            if not found_binaries:
                logger.log("**Could not find binaries "+str(self.binaries[component])+" for "+component+"**\n")
                self.summary["Build:"+component] = False
            else:
                logger.log("Binaries `"+str(found_binaries)+"` has been built for "+component+"\n")
                self.summary["Build:"+component] = True

            logger.log("\n\n")

        print("...done.")

    def check_output(self):

        print("Check output...")

        logger = Logger(self.report_dir+"/output_"+self.target, "output.md", self)
        logger.log("# IOW ESM output report\n\n\n")

        for setup in self.setups:

            if self.target not in setup:
                continue

            print(" Check setup "+setup+"...")

            input_folders = self._glob_remote("-d "+self.host_path+"/"+setup+"/input/*/ | grep -v ^_")

            if input_folders == []:
                input_folders = self._glob_remote(self.host_path+"/"+setup+"/input/global_settings.py")
                if input_folders == []:
                    continue

                input_folders = [""]

            for input_folder in input_folders:
                print("  Check output for input folder "+input_folder+"...")
                if input_folder != "" and input_folder[-1] == "/":
                    input_folder = input_folder[:-1] 
                input_folder = input_folder.split("/")[-1]

                logger.log("## Output report for `"+setup+"` and input folder `"+input_folder+"`\n\n")

                found_output = self._glob_remote(self.host_path+"/"+setup+"/output/"+input_folder)
                if not found_output:
                    logger.log("**Could not find output for "+setup+" and input folder `"+input_folder+"`**\n")
                    self.summary["Output:"+setup+":"+input_folder] = False
                else:
                    logger.log("Output `"+str(found_output)+"` has been generated for "+setup+" and input folder `"+input_folder+"`.\n")
                    self.summary["Output:"+setup+":"+input_folder] = True

                logger.log("\n")

                model_outputs = self._glob_remote("-d "+self.host_path+"/"+setup+"/output/"+input_folder+"/*")

                for model_output in model_outputs:
                    
                    if model_output[-1] == "/":
                        model_output = model_output[:-1]
                                                    
                    model = model_output.split("/")[-1].split("_")[0]

                    print("   Check model "+model+"...")
                    results_dir = model_output.split("/output/")[-1].replace("/", "_")
                    found_report = self._glob_remote(self.host_path+"/"+setup+"/postprocess/"+model+"/create_validation_report/results/*"+results_dir+"*/validation_report.md")                      
                    
                    print("   ...done.")
                    if not found_report:
                        continue

                    validation_report_dir = self.report_dir+"/output_"+self.target+"/"+input_folder+"/"+model

                    os.system("mkdir -p "+validation_report_dir)
                    cmd = "scp -r "+self.dest+"/"+setup+"/postprocess/"+model+"/create_validation_report/results/*"+results_dir+"*/* "+validation_report_dir
                    sp = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE)
                    sp.wait()

                    logger.log("### "+model+"\n\n")
                    logger.log("Validation report has been generated for "+model+".\n\n")

                logger.log("\n\n")
                print("  ...done.")
            print(" ...done.")
        print("...done.")
    
    def write_summary(self):
        print("Write summary...")

        failed = 0
        self.summary_logger.log("| checkpoint       | success  |\n")
        self.summary_logger.log("|---               |---       |\n")
        for checkpoint in self.summary.keys():
            self.summary_logger.log("|"+checkpoint+"|`"+str(self.summary[checkpoint])+"`|\n")

            if not self.summary[checkpoint]:
                failed += 1

        if failed > 0:
            self.summary_logger.log("### Failure\n\n")
            self.summary_logger.log("\n"+str(failed)+" checkpoints failed!\n")
        else:
            self.summary_logger.log("### Success\n\n")
            self.summary_logger.log("\n<span style=\"color:green\">All checkpoints succeeded!</span>\n")

        print("...done.")

    def __del__(self):
        print("# Reporter for "+self.target+" finished.")
