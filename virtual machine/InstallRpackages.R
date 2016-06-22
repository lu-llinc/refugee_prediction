# Install R packages
rm(list=ls())

# WD
DIRECT <- "/vagrant/"

# Read table
reqs <- read.table(paste0(DIRECT,"R_requirements.txt"), header=F, stringsAsFactors=F)[,1]

# Install packages
install.packages(reqs, repos='http://cran.xl-mirror.nl/')
