#!/bin/bash

# Establish all directories used

# Initial directory, which is where the python code is stored
cdir=$(pwd)

# Directory where the data will be downloaded and stored
xmmdata=/clusterfs/heptheory/dessert/Reanalysis3p5/test-github

# Location of the HEADAS software
HEADAS=/clusterfs/heptheory/fosterjw/heasoft-6.28/x86_64-pc-linux-gnu-libc2.17

# Location of the XMM-SAS software and the XMM-ESAS sub-package
XMMSAS=/clusterfs/heptheory/dessert/code/xmmsas_20141104_1833

# CalDB directory, containing additional files required for processing
CALDBPATH=/clusterfs/heptheory/dessert/xmm-decay/esas_caldb

# Path to the Current Calibration Files (CCF) if you are using cifbuild
CCFPATH=/clusterfs/heptheory/dessert/code/XMM_Full_CCF_09142022

# Path to CIAO software (required if RunWavdetect==1)
CIAOPATH=/clusterfs/heptheory/dessert/code/ciao-4.13

# Path to pre-stored CCFs
# Here we put in directory assuming the GitHub was cloned
CCFDIR=../../../data/CIFs