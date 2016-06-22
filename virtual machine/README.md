## README

This vagrantbox sets up a virtual environment containing anaconda and Rstudio. Both python an Rstudio can be run from within a browser outside of the virtual environment.

## Setting up the vagrantbox

	1. Install [virtualbox](https://www.virtualbox.org/wiki/Downloads)
	2. Install [vagrant](https://www.vagrantup.com/docs/installation/)

See https://docs.vagrantup.com/v2/ for documentation on vagrant.

The vagrant repository contains several files:

	1. **Vagrantfile** --> The vagrant configuration (amount of ram, cpus to use etc.)
	2. **provision.sh** --> Bash file with all programs to install
	3. **R_requirements.txt** --> contains a list of R packages to be installed
	4. **InstallRpackages.R** --> Code to install R packages
	5. **export.sh** --> Bash file that exports environment/PATH variables. Due to the nature of vagrant VMs, it is called every time the VM starts up

Navigate to the folder where you downloaded the box via terminal and run 'vagrant up' to start up the machine. When it is fully provisioned / booted (this could take some time if the box is starting up for the first time), you can enter the environment by entering "vagrant ssh". 

### BASIC COMMANDS

vagrant up 
	- Sets up the Virtual Machine (VM)

vagrant ssh
	- Boots into the VM (need to vagrant up first)

vagrant suspend
	- VM is temporarily suspended. Machine state is written to hard drive.

vagrant halt
	- VM is shut down.

vagrant destroy
	- Destroys VM

## Starting and accessing Ipython Notebook & Rstudio server from outside the VM

The Vagrantfile forwards both port 8889 (Ipython notebook) and 8787 (Rstudio server). You can check whether they are running by running:
	- sudo netstat -lnptu | grep ':<PORT>', e.g. sudo netstat -lnptu | grep ':8888'

### Starting ipython

NOTE: Start ipython notebook using ip address '0.0.0.0', like so:
	- ipython notebook --ip='0.0.0.0'
	
In your browser, navigate to: http://127.0.0.1:8888

### Starting Rstudio

Rstudio server will start as a service. If you need to start it up manually, do 'sudo rstudio-server start' (or '... stop' to stop it / '... start' to start) while in the vagrant box. Then, navigate to: http://127.0.0.1:8787 in your browser.



