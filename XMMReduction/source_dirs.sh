#!/bin/bash

# Establish all directories used

# Initial directory, which is where the python code is stored
cdir=$(pwd)

# Directory where the data will be downloaded and stored
xmmdata=

# Location of the HEADAS software
HEADAS=

# Location of the XMM-SAS software and the XMM-ESAS sub-package
XMMSAS=

# CalDB directory, containing additional files required for processing
CALDBPATH=

# Path to the Current Calibration Files (CCF) if you are using cifbuild
CCFPATH=

# Path to CIAO software (required if RunWavdetect==1)
CIAOPATH=

# Path to pre-stored CCFs
# Here we put in directory assuming the GitHub was cloned
CCFDIR=../../../data/CIFs
