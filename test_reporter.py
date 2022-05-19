import glob
import os

class TestReporter:

    def __init__(self, test_dir, setups, report_dir = "./report"):

        self.test_dir = test_dir
        self.report_dir = report_dir
        self.setups = setups

        self.intro_file_name = self.report_dir + "/intro.md"
        with open(self.intro_file_name, "w") as file:
            file.write("# IOW ESM test report\n\n")

            file.write("This is an IOW ESM test report.\n")
            file.write("The tes thas been performed in `"+test_dir+"` with the setups `"+str(setups)+"`.\n")
            file.write("\n\n")


        self.binaries = {
            "components/CCLM" : ["cclm/bin_PRODUCTION/lmparbin"],
            "components/MOM5" : ["exec/IOW_ESM_PRODUCTION/MOM_SIS/fms_MOM_SIS.x"],
            "components/flux_calculator" : ["bin_PRODUCTION/flux_calculator"],
            "components/OASIS3-MCT" : ["oasis3-mct/IOW_ESM_PRODUCTION/build/lib/psmile.MPI1/*", "oasis3-mct/IOW_ESM_PRODUCTION/build/lib/mct/*", "oasis3-mct/IOW_ESM_PRODUCTION/lib/*"],
            "tools/I2LM" : ["int2lm/bin_PRODUCTION/int2lm.exe"]
        }

        self.summary = {}

    def check_build(self):

        build_report_dir = self.report_dir+"/build"
        if glob.glob(build_report_dir):
            os.system("rm -r "+build_report_dir)
        os.system("mkdir "+build_report_dir)

        check_build_file_name = build_report_dir+"/build.md"
        with open(check_build_file_name, "w") as file:
            file.write("# IOW ESM build report\n\n\n")

            for component in self.binaries.keys():
                file.write("## Build report for "+component+"\n\n")

                found_binaries = []
                for binary in self.binaries[component]:
                    found_binaries += glob.glob(self.test_dir+"/base/"+component+"/"+binary)
                
                if not found_binaries:
                    file.write("**Could not find binaries "+str(self.binaries[component])+" for "+component+"**\n")
                    self.summary["Build:"+component] = False
                else:
                    file.write("Binaries `"+str(found_binaries)+"` has been built for "+component+"\n")
                    self.summary["Build:"+component] = True

                file.write("\n\n")

    def check_output(self):
        output_report_dir = self.report_dir+"/output"
        if glob.glob(output_report_dir):
            os.system("rm -r "+output_report_dir)
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
                    file.write("Output `"+str(found_output)+"` has been generated for "+setup+".\n")
                    self.summary["Output:"+setup] = True

                file.write("\n")

                model_outputs = glob.glob(self.test_dir+"/"+setup+"/output/*/*")
                for model_output in model_outputs:
                    model = model_output.split("/")[-1].split("_")[0]
                    results_dir = model_output.split("/output/")[-1].replace("/", "_")
                    fig_dir = self.report_dir+"/output/figures_"+setup+"/"+model
                    found_plots = glob.glob(self.test_dir+"/"+setup+"/postprocess/"+model+"/plot*/results/"+results_dir+"*/*.pdf")
                    
                    if not found_plots:
                        continue

                    file.write("### "+model+"\n\n")
                    file.write(str(len(found_plots))+" figures have been generated for "+model+".\n\n")

                    file.write("<details>\n\n")

                    os.system("mkdir -p "+fig_dir)

                    found_plots = sorted(found_plots)

                    for plot in found_plots:
                        figure = plot.split("/")[-1]
                        try:
                            from pdf2image import convert_from_path
                            print("Convert "+plot+" to png file")
                            figure = figure.replace("pdf","png")
                            pages = convert_from_path(plot, 300)
                            for page in pages:
                                page.save(fig_dir+"/"+figure,'PNG')
                        except: 
                            os.system("cp "+plot+" "+fig_dir+"/")
                        file.write("```{figure} ./figures_"+setup+"/"+model+"/"+figure+"\n")
                        file.write("---\n")
                        file.write("height: 500px\n")
                        file.write("name: fig-"+setup+"-"+model+"-"+figure+"\n")
                        file.write("---\n")
                        file.write(figure+"\n")
                        file.write("```\n\n")

                        self.summary["Output:"+setup+":"+model+":"+figure] = True

                    file.write("</details>\n\n")

                file.write("\n\n")
    
    def write_summary(self):
        failed = 0
        with open(self.intro_file_name, "a") as file:
            file.write("## Summary\n\n")

            file.write("| checkpoint       | success  |\n")
            file.write("|---               |---       |\n")
            for checkpoint in self.summary.keys():
                file.write("|"+checkpoint+"|`"+str(self.summary[checkpoint])+"`|\n")

                if not self.summary[checkpoint]:
                    failed += 1

            if failed > 0:
                file.write("## Failure\n\n")
                file.write("\n"+str(failed)+" checkpoints failed!\n")
            else:
                file.write("## Success\n\n")
                file.write("\n<span style=\"color:green\">All checkpoints succeeded!</span>\n")
