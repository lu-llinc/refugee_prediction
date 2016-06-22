#!/usr/bin/env bash

### Provisioning the virtual machine

# Update
sudo apt-get update

# Install anaconda
anaconda=Anaconda2-2.5.0-Linux-x86_64.sh
cd /vagrant

# If not exists, create folder downloads
if [ ! -d "$downloads" ]; then
	mkdir downloads
fi

cd downloads

if [ ! -f $anaconda ]; then
	echo "Downloading anaconda installer..."
    wget -q -o /dev/null - http://repo.continuum.io/archive/Anaconda2-2.5.0-Linux-x86_64.sh
    chmod +x $anaconda
fi

echo -e "\n\nInstalling Anaconda"
sudo ./$anaconda -b -p /opt/anaconda

# Back to vagrant home
cd /home/vagrant

# Install base packages
echo "Installing base packages..."
sudo aptitude install -y libgdal-dev 
sudo aptitude install -y libproj-dev
sudo apt-get install zlib1g-dev
sudo apt-get install -y libssl-dev # To run devtools
sudo apt-get -y build-dep libcurl4-gnutls-dev
sudo apt-get -y install libcurl4-gnutls-dev
sudo apt-get install -y git 
sudo apt-get install -y g++ 

sudo apt-get install zip
sudo apt-get install unzip
sudo apt-get install -y libxml2-dev 
sudo apt-get install -y libxslt1-dev

echo "Installing htop..."
sudo apt-get install -y htop
echo "Installing libjpeg-dev..."
sudo apt-get install -y libjpeg-dev 

echo "Configuring libjpeg..."
sudo ln -s /usr/lib/x86_64-linux-gnu/libjpeg.so /usr/lib/
sudo ln -s /usr/lib/x86_64-linux-gnu/libfreetype.so.6 /usr/lib/
sudo ln -s /usr/lib/x86_64-linux-gnu/libz.so /usr/lib/

# Update
sudo apt-get update <<-EOF
yes
EOF

echo "Installing R-base..."
# Add cran to list of sources (to get the last version of R)
sudo echo "deb http://cran.rstudio.com/bin/linux/ubuntu trusty/" >> /etc/apt/sources.list
# Add public keys
gpg --keyserver keyserver.ubuntu.com --recv-key E084DAB9
gpg -a --export E084DAB9 | sudo apt-key add -
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get install -y r-base r-base-dev

echo "Installing R packages..."
sudo R CMD BATCH /vagrant/InstallRpackages.R

echo "Installing rJava..."
sudo apt-get install -y r-cran-rjava

echo "Installing R-studio server..."
sudo apt-get install -y libjpeg62 
sudo apt-get install -y gdebi-core 
sudo apt-get install -y libapparmor1

serv=rstudio-server-0.99.892-amd64.deb
cd /vagrant/downloads

if [ ! -f $serv ]; then
	echo "Downloading Rstudio server ..."
	wget https://download2.rstudio.org/rstudio-server-0.99.892-amd64.deb
	chmod +x $serv
fi

# Install
sudo gdebi rstudio-server-0.99.892-amd64.deb 
sudo dpkg -i $serv

# Back to vagrant home
cd /home/vagrant

echo "Updating..."
sudo apt-get update

echo "Linking files ..."
sudo ln -s /vagrant/project_files /home/vagrant/

# Echo path to profile
echo "source /vagrant/export.sh" | /usr/bin/tee -a /home/vagrant/.bashrc
