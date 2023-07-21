# Purpose, Description

This is the repository of a testing suite for the IOW ESM framework.
It does not perform UnitTests but rather full integration tests that may take some time.


# Authors
    
* SK      (sven.karsten@io-warnemuende.de)


# Versions

## 1.00.00 (latest release)

| date        | author(s)   | link                                                                            |
|---          |---          |---                                                                              |
| 2023-07-21  | SK          | [1.00.00](https://git.io-warnemuende.de/iow_esm/tester/src/branch/1.00.00) |   

<details>

### changes

* initial release
    

### dependencies

* python3, jupyterbook
  

### known issues

* if you want to run test.sh from a screen,
  you have to export the TERM environment variable to something reasonable, e.g.
  `export TERM=xterm-256color`
  otherwise ssh asks for hitting Enter all the time


### tested with

* tested from the IOW server phy-10 and a local VM with OpenSUSE
* tests are running on HLRN machines
* if setups are available, tests may also run on Haumea and IOW servers
  
</details>

<details>
<summary><b><i>older versions</i></b></summary>

</details>


# Usage

Where and what to test can be set in the test configuration file, see e.g. `test_config.example`.
You can create your own configuration file as a simple text file with bash syntax.
The configuration file will be sourced when the test is running.

In order to run a test, execute in a bash terminal
``` bash
./test.sh <test_config-file>
``` 

The results of a test are summarized in a jupyter book that you can find under
`report/_build/docs/intro.html`.
Just open it in a browser of your choice.

With `report/publish.sh` the test result may also be published to github repository with enavled github pages.
This is currently existing under https://sven-karsten.github.io/iow_esm.test/intro.html.