import os
import pathlib
root = "."

toc = []

for path, subdirs, files in os.walk(root):
    if "_build" in path:
        continue

    for name in files:
        if name == "intro.md":
            continue
        if ".md" in name or ".rst" in name:
            print(name)
            currentFile = str(pathlib.PurePath(path, name))
            toc.append(currentFile)

f = open('_toc.yml', 'w')

header = """format: jb-book
root: intro.md
parts:
"""

f.write(header)

Chapter = ""

for element in toc:
    filename = os.path.basename(element)
    chapter = element.split("/")[0]
    if chapter != Chapter:
        Chapter = chapter
        f.write(f"- caption: {Chapter}\n")
        f.write("  chapters:\n")
    f.write(f"  - file: {element}\n")

f.close() 