#!/bin/bash

###############################################################################
# ProcessXMM.sh
###############################################################################
#
# Script to download a given XMM observation and convert this to a data file
# NB: This script only processes those observations considered in this work. 
# For a more generic script, see https://github.com/nickrodd/XMM-DM
#
# To call this script for an observation with ID=obsID use
# ./ProcessXMM.sh $obsID $RunWavdetect
# where RunWavdetect=0 for SAS cheese and RunWavdetect=1 for CIAO wavdetect
# Before calling, all directories must be set in set_dirs.sh
#
###############################################################################


# Import directories which must be set before running
source source_dirs.sh


# The data processing involves the following steps:
# 1. Initialize the required software
# 2. Download and unpack the data
# 3. Create instrument summary files (status of XMM during observation)
# 4. Retrieve the exposure names (that label the events and other files)
# 5. Create filtered event files
# 6. Check for anomalous states
# 7. Point source identification
# 8. Create the spectra and QPB
# 9. Process data into numpy files and delete unneeded data


##########################
# 1. Initialize Software #
##########################

# Read observation ID in from command line
# NB: all obsIDs are 10 digits, don't forget the 0 at the start if present
obsID=$1
RunWavdetect=$2
echo 'Reading in observation ID '$obsID
echo 'Will run Wavdetect: '$RunWavdetect

echo 'Starting the data processing'
echo -e '\nStep 1: initializing the required software'

# Initialize the HEADAS software
. $HEADAS/headas-init.sh

# Initialize the XMM-SAS software and XMM-ESAS sub-package
. $XMMSAS/setsas.sh > /dev/null # suppress launch notifications

# Define CalDB directory, contains additional files that are required for the 
# processing of both spectra and images
export CALDB=$CALDBPATH

# Source two directories that don't yet exist, but are used for data processing
export SAS_CCF=$xmmdata/$obsID/analysis/ccf.cif
export SAS_ODF=$xmmdata/$obsID/odf

# Source the CCFs
export SAS_CCFPATH=$CCFPATH

# Turn on batch scripting capability
# Without this, everything is stored in a parameter file in the home directory
# If you have multiple jobs running, they will all use the same file
export HEADASPFILES="$xmmdata/$obsID/PFILES/;$HEADAS/syspfiles"
export PFILES=$HEADASPFILES

# NB: the above variables are used internally by various tools below, not just
# explicitly in the bash script, so it is important to export them

# Note the following repeatedly used abbreviations:
# - SAS: Science Analysis System 
# - CCF: Current Calibration File
# - ODF: Observation Data File
# - CIF: Calibration Index File
# - PPS: Processing Pipeline Subsystem


###########################
# 2. Download/Unpack data #
###########################

# Move to the directory to download the data into
cd $xmmdata

echo -e '\nStep 2: downloading and unpacking the data'
curl -s -o files$obsID.tar "http://nxsa.esac.esa.int/nxsa-sl/servlet/data-action-aio?obsno=$obsID" > /dev/null 

# After downloading the data, there are many many nested tar files that need to
# be unpacked. As there is a large number of files do not write out the output
tar -xvf files$obsID.tar > /dev/null
rm -f files$obsID.tar

# At this point we have two directories:
# 1. $obsID/odf: observational data files (currently all in a tar) 
# 2. $obsID/pps: Processing Pipeline Subsystem (PPS) files, already untared
# pps directory usually contains > 1000 files, contains the Scientific 
# Validation Report in PDF and PostScript formats, as well as the .ASC 
# Pipeline Report file which includes such basic information as the target 
# name, PI name, and other basic observatin information.

echo 'Now the data has been downloaded, all subsequent outputs will be written to summary.txt'

# Check if uncompressing failed, "-d" check if directory exists
# If not manually set up the directories (occurs for e.g. 0653860101)
if [ ! -d "$obsID/odf" ]; then
    mkdir $obsID && mkdir $obsID/odf && mkdir $obsID/pps
    echo 'Continuing log for ID '$obsID > $obsID/summary.txt
    echo 'files'$obsID'.tar did not untar correctly.' >> $obsID/summary.txt
    mv *_$obsID* $obsID/odf/ && mv *MANIFEST* $obsID/odf/
else
    echo 'Continuing log for ID '$obsID > $obsID/summary.txt
fi

# Unpack compressed files within the directories 
# First in the observation data file directory
cd $obsID 
cd odf 
tar -zxvf $obsID.tar.gz > ../untar_output.txt 2>&1
# Have now unpacked the following (REV is revolution when data was taken):
# ${REV}_${OBSID}_SCX00000SUM.SAS - ASCII observation summary file
# ${REV}_${OBSID}_SCX00000TCS.FIT - Spacecraft Time correlation file
# ${REV}_${OBSID}_SCX00000ATS.FIT - Spacecraft Attitude file
# ${REV}_${OBSID}_SCX00000ROS.FIT - Spacecraft Reconstructed Orbit File
# ${REV}_${OBSID}_SCX00000RAS.FIT - Raw Attitude File 
tar -xvf *.TAR > ../untar_output.txt 2>&1
# This step unpacks several hundred FIT files, including (ENUM=exposure number)
# ${REV}_${OBSID}_OMS${ENUM}00WDX.FIT - Exposure priority window file
# ${REV}_${OBSID}_OMS${ENUM}00THX.FIT - Exposure tracking history file
# ${REV}_${OBSID}_OMS${ENUM}00IMI.FIT - Exposure image file
# There are many other outputs, e.g. DII (diagnostic images), D1H/D2H (CCD 
# readout settings), OFX (offset files), DLI (discarded lines data), RFX
# (reference frame data), PEH (periodic housekeeping), and several others

# Secondly in the pipeline processing subsystem directory, unzip .FTZ files
# No new files appear
cd ../pps
rename .FTZ .FIT.gz *.FTZ > ../untar_output.txt 2>&1
gunzip -f *.FIT.gz > ../untar_output.txt 2>&1

# Copy the PPS summary file and the PPS MSG file to the obsID directory
cp *PPSMSG*.ASC ../pps_run_message.ASC
cp *PPSSUM*.HTM ../pps_summary.HTM
cd ..

# We now make directories that will be relevant later
mkdir analysis # to store CCF
mkdir PFILES # to save HEADAS PFILES
# Only need these if we initialize CIAO
if [ "$RunWavdetect" -eq "1" ]; then
    mkdir PFILES_CIAO # to save CIAO PFILES separately from HEADAS
    mkdir ASCDS_TMP # CIAO temp directory
    mkdir ASCDS_WORK_PATH # CIAO temp directory
fi
cd analysis

#########################
# 3. Instrument Summary #
#########################

# Use SAS tools to determine the status of the instrument during the obsID
# e.g. flag parts of the detector that were not functioning, these will be cut
# from the data at the next step

echo -e '\nStep 3: making the ccf and odf instrument summary files' >> ./summary.txt

# Run the commands and write all details into their output files
# NB: from hereon we will also output all of the commands executed
cp $CCFDIR/${obsID}_2014-11-04.cif $SAS_CCF
# Create /odf/${REV}_${OBSID}_SCX00000SUM.SAS, the detailed summary file
echo 'odfingest odfdir=$SAS_ODF outdir=$SAS_ODF > ../odfingest_output.txt 2>&1' >> ../summary.txt
odfingest odfdir=$SAS_ODF outdir=$SAS_ODF > ../odfingest_output.txt 2>&1

# Ensure the ODF file is correctly read using the following command
# This command was provided by the helpdesk
# Again note SAS_ODF is used internally by the commands below
cd ../odf
export SAS_ODF=$(readlink -f *SUM.SAS)


########################
# 4. Detector Prefixes #
########################

# The instrument has three cameras comprising the European Photon Imaging Camera 
# (EPIC) two are MOS (Metal Oxide Semi-conductor) CCD arrays and one pn-CCD 
# array. Per observation, each camera will have taken some set of exposures, 
# labeled <det><prefix>; <det> is mos or pn, and prefix is of the form 
# [S,U][0-9][0-9][0-9] for pn or [1-2][S,U][0-9][0-9][0-9] for mos
# The S or U designates whether the exposure is scheduled or unscheduled
# This has no bearing on the validity of the data
# The last three numbers notate the exposure
# For mos, the [1-2] designates which mos camera
# These prefixes will be passed in as parameters to various commands

echo -e '\nStep 4: Determine the detector prefixes' >> ../summary.txt

# Create files mos_exposures.txt and pn_exposures.txt
# that contain the science exposures for the observation
python $cdir/get_science_exposures.py --xmmdata $xmmdata --obsID $obsID

# Get array of the mos prefixes
if [ ! -f ../mos_exposures.txt ]; then
    mosprefixes=''
else
    mosprefixes=$(<../mos_exposures.txt)
fi

echo 'MOS prefixes: '$mosprefixes >> ../summary.txt

######################
# 5. Filtered Events #
######################

# Process the data to remove bad periods

echo -e '\nStep 5: Filtering event files for the MOS camera' >> ../summary.txt

# emchain generates an event list for each exposure
# However emchain does not need to be run for each mos exposure
# In each case the output is stored in odf
echo 'emchain > ../emchain_output.txt 2>&1' >> ../summary.txt
emchain > ../emchain_output.txt 2>&1

# Check that emchain completed successfully
# There are sometimes errors where the TCX file is nearly empty and the emchain cannot complete
# If so the file should be rerun using the TCS timing information
if grep -q "TooFewTimeCorrelationDataPoints" ../emchain_output.txt; then
    echo 'TCX file is almost empty. Rerunning with the TCS file.'
    echo 'TCX file is almost empty. Rerunning with the TCS file.' >> ../summary.txt
    export SAS_TIMECORR=TCS
    echo 'emchain > ../emchain_output.txt 2>&1' >> ../summary.txt
    emchain > ../emchain_output.txt 2>&1
fi

# mos-filter then filters the event list generated for good time intervals
# Produces fits files in odf/ including list of time intervals, and importantly
# *-clean.fits – The filtered photon event files
echo 'mos-filter > ../mos-filter_output.txt 2>&1' >> ../summary.txt
mos-filter > ../mos-filter_output.txt 2>&1

# Check if the processing was successful
mosexpclean=''
for pref in $mosprefixes; do
    if [ ! -f 'mos'$pref'-clean.fits' ]; then
        echo 'mos'$pref'-clean.fits was not created successfully.' >> ../summary.txt
    else
        mosexpclean=$mosexpclean' '$pref
    fi
done
mosprefixes=$mosexpclean


#######################
# 6. Anomalous states #
#######################

# The above process does not check for anomalous states in the data
# This only impacts data below 1 keV, but if the hardness is 0 the CCD is 
# unusable. This occurs if e.g. a camera was hit by a micrometeorite
# Note this only impacts the MOS cameras

echo -e '\nStep 6: Checking for anomalous states' >> ../summary.txt

# Get str of the line numbers where an anomalous CCD is listed
# Only mos CCDs are anomalous at this time
# Briefly, the syntax below is -F is for searching for special characters (like *)
# and -n gives the line number. Lines ending in " ****" have hardness 0
# The prefix then cuts the returned list to give only the line numbers
# (specifically it returns everything before : in that line)
anomalous_lines=`grep -Fn " ****" ../mos-filter_output.txt | cut -f1 -d:`


##################################
# 7. Point source identification #
##################################

# Search for and identify point sources using ciao
# This is later used by mos-spectra since we edit *-clean.fits directly

# Add Env.pm to @INC so that *-spectra,*-back run
# We can't add before because then emchain fails!
PERL5LIB=$PERL5LIB:/global/software/sl-7.x86_64/modules/langs/perl/5.36.0/lib/5.36.0

echo -e '\nStep 7: Searching for point sources and create appropriate mask' >> ../summary.txt

if [ "$RunWavdetect" -eq "1" ]; then
    echo -e '\nRunning wavdetect with CIAO...' >> ../summary.txt
    # Source ciao
    source $CIAOPATH/bin/ciao.bash
    # ciao changed $CALDB, so we turn it back into the SAS one
    export CALDB=$CALDBPATH
    # ciao also changed $PFILES, so we have to change it back and forth whenever we use wavdetect...
    export CIAOPFILES="$xmmdata/$obsID/PFILES_CIAO;$CIAOPATH/contrib/param:$CIAOPATH/param"
    export PFILES=$HEADASPFILES # need it for headas right now
    export ASCDS_TMP="$xmmdata/$obsID/ASCDS_TMP"
    export ASCDS_WORK_PATH="$xmmdata/$obsID/ASCDS_WORK_PATH"

    for pref in $mosprefixes; do

        # The below is nearly copied from the mos-spectra runs in next step
        # Here we run this to create the maps for source detection in the 0.4-7 keV range
        echo 'Creating maps to do source detection on for mos'$pref >> ../summary.txt
        # First need to determine which CCDs are anomalous
        # mos has 7 CCDs, 1 means the CCD is usable
        # Assume no anomalous states
        mosccds="1 1 1 1 1 1 1"
        # Find the line where the prefix's info is listed
        prefix_line=`grep -Fxn "$pref" ../mos-filter_output.txt | cut -f1 -d:`

        for line in $anomalous_lines; do
            # Do some math based on the formatting of '../mos-filter_output.txt'
            CCD_num=`expr $line - $prefix_line + 1`
            # The if statement ensures that only anomalous CCDs corresponding to $prefix are found
            if [ $CCD_num -lt 8 ] && [ $CCD_num -gt 0 ]; then
                # If a CCD is anomalous, change its position in the str to be 0
                sedarg=s/[0-9]/0/$CCD_num
                mosccds=`echo $mosccds | sed $sedarg`
            fi
        done

        # Make sure at least one outer CCD was collecting data
        # Outer CCDs are necessary to determine the QPB (first index is central CCD)
        if [ "$mosccds" != "1 0 0 0 0 0 0" ]; then
            # Record the CCD states into individual variables for readability
            set -- $mosccds
            ccd1=$1
            ccd2=$2
            ccd3=$3
            ccd4=$4
            ccd5=$5
            ccd6=$6
            ccd7=$7

            # Record the CCDs selected for analysis into an external file
            echo 'The CCDs selected for mos'$pref' are '$mosccds >> ../summary.txt

            # Create the source spectra, RMFs, and ARFs
            echo 'Creating source spectra and images' >> ../summary.txt

            # Run with mask 0 because we use wavdetect for PS identification
            echo 'mos-spectra prefix='$pref' caldb=$CALDB mask=0 elow=400 ehigh=7000 ccd1='$ccd1' ccd2='$ccd2' ccd3='$ccd3' ccd4='$ccd4' ccd5='$ccd5' ccd6='$ccd6' ccd7='$ccd7' > ../mos'$pref'-spectra_output.txt 2>&1' >> ../summary.txt
            mos-spectra prefix=$pref caldb=$CALDB mask=0 elow=400 ehigh=7000 ccd1=$ccd1 ccd2=$ccd2 ccd3=$ccd3 ccd4=$ccd4 ccd5=$ccd5 ccd6=$ccd6 ccd7=$ccd7 > ../mos$pref-spectra_400_7000_output.txt 2>&1

            # Detect Sources and read into file
            export PFILES=$CIAOPFILES # Temporarily change $PFILES for CIAO
            objimfile=mos${pref}-obj-im-400-7000.fits
            wavdetect infile=$objimfile expfile=mos${pref}-exp-im-400-7000.fits psffile="" scales="4 8 16 32 64" outfile=mos${pref}_src.fits scellfile=mos${pref}_scell.fits imagefile=mos${pref}_imgfile.fits defnbkgfile=mos${pref}_nbgd.fits regfile=mos${pref}_wavdetect.reg sigthresh="1e-6" clobber=yes > ../mos$pref-wavdetect_output.txt 2>&1
            sed -i '/,0.000018,0.000018,90.000000)/d' mos${pref}_wavdetect.reg 
            export PFILES=$HEADASPFILES # Revert $PFILES

            rm mos${pref}_detXY_sources.reg
            while read regtxt; do

                ecoordconv imageset=$objimfile srcexp="(X,Y) IN ${regtxt}" > ecoordconv_output.txt
                DETX=`awk -F ' ' -v row=6 -v col=3 'NR==row{print $col}' ecoordconv_output.txt`
                DETY=`awk -F ' ' -v row=6 -v col=4 'NR==row{print $col}' ecoordconv_output.txt`
                Xrad=`echo $regtxt | cut -d "," -f 3`
                Yrad=`echo $regtxt | cut -d "," -f 4`
                Ang=`echo $regtxt | cut -d "," -f 5`
                regselection='&&!'"((DETX,DETY) IN ELLIPSE(${DETX},${DETY},${Xrad},${Yrad},${Ang})"
                echo -n $regselection >> mos${pref}_detXY_sources.reg

            done < mos${pref}_wavdetect.reg

            # Delete files from mos-spectra so that the later runs will rerun
            # mos-spectra will not overwrite
            rm mos${pref}-obj.pi
            rm mos${pref}-1obj.pi
            rm mos${pref}-2obj.pi
            rm mos${pref}-3obj.pi
            rm mos${pref}-4obj.pi
            rm mos${pref}-5obj.pi
            rm mos${pref}-6obj.pi
            rm mos${pref}-7obj.pi
            rm mos${pref}-corn.fits
            rm mos${pref}-obj-im.fits
            rm mos${pref}-obj-im-sp-det.fits
            rm mos${pref}-exp-im.fits
            rm mos${pref}.rmf
            rm mos${pref}.arf

        fi

    done
else
    echo -e '\nRunning cheese with ESAS...' >> ../summary.txt
    # Run cheese to identify point sources, and create a *-cheese.fits mask file
    # This is later used by mos-spectra by setting mask=1
    
    # Run cheese once for each prefix
    # prefixm only takes 2 arguments
    # But sometimes there are more than 3 exposures, so must do this loop
    # The output is the masks placed into odf/, the most relevant are the "cheese.fits" files

    for pref in $mosprefixes; do
        echo 'cheese prefixm='$pref' prefixp='\"\"' scale=0.25 rate=1.0 dist=40.0 clobber=1 elow=3000 ehigh=4000 > ../cheese_mos'${pref}'_output.txt 2>&1' >> ../summary.txt
        cheese prefixm=$pref prefixp="" scale=0.25 rate=1.0 dist=40.0 clobber=1 elow=400 ehigh=7000 > ../cheese_mos${pref}_output.txt 2>&1
        # Sometimes cheese fails, but works upon rerunning, so check and rerun if need
        if [ ! -f 'mos'$pref'-cheese.fits' ]; then
            echo "Cheese failed, trying again" >> ../summary.txt
            cheese prefixm=$pref prefixp="" scale=0.25 rate=1.0 dist=40.0 clobber=1 elow=400 ehigh=7000 > ../cheese_mos${pref}_output.txt 2>&1
        fi
        if [ ! -f 'mos'$pref'-cheese.fits' ]; then
            echo "Cheese failed, trying again" >> ../summary.txt
            cheese prefixm=$pref prefixp="" scale=0.25 rate=1.0 dist=40.0 clobber=1 elow=400 ehigh=7000 > ../cheese_mos${pref}_output.txt 2>&1
        fi
    done
fi

#############################
# 8. Create Spectra and QPB #
#############################

# Create the spectra and image files for the data.

echo -e '\nStep 8: Create Spectra and QPB' >> ../summary.txt

# For the MOS camera the following outputs are created in odf
# Each prefix has a series of mos${prefix} files. These include mos${prefix}-[1-7]
# which are files for the individual CCD cameras, which we won't use
# Then there are files for the full observation, either spatial maps for the full
# energy range or energy maps for the full observation.

# The key files we will use are:
# - mos${prefix}-obj.pi: observation data binned in energy
# - mos${prefix}.arf: the Auxiliary Response File (ARF)
# - mos${prefix}.rmf: the Redistribution Matrix File (RMF)
# - mos${prefix}-back.pi: the Quiescent Particle Background (QPB)
# NB: we can get the effective area as a function of output channel from the ARF 
# file, which includes vignetting in each energy bin!
# The RMF encodes the effective energy resolution, as it explains how to map
# from input channel to output channel, and is thus a matrix

for pref in $mosprefixes; do

    # First set up to run the below code depending on previous PS method:
    if [ "$RunWavdetect" -eq "1" ]; then
        # Don't mask sources, exclude region instead
        mask=0
        regionfile=mos${pref}_detXY_sources.reg
    else
        # Mask sources, reg.txt does not exist so no exclusion region used
        mask=1
        regionfile=reg.txt
    fi

    echo 'Creating spectra and images for mos'$prefix >> ../summary.txt
    # First need to determine which CCDs are anomalous
    # mos has 7 CCDs, 1 means the CCD is usable
    # Assume no anomalous states
    mosccds="1 1 1 1 1 1 1"
    # Find the line where the prefix's info is listed
    prefix_line=`grep -Fxn "$pref" ../mos-filter_output.txt | cut -f1 -d:`

    for line in $anomalous_lines; do
        # Do some math based on the formatting of '../mos-filter_output.txt'
        CCD_num=`expr $line - $prefix_line + 1`
        # The if statement ensures that only anomalous CCDs corresponding to $pref are found
        if [ $CCD_num -lt 8 ] && [ $CCD_num -gt 0 ]; then
            # If a CCD is anomalous, change its position in the str to be 0
            sedarg=s/[0-9]/0/$CCD_num
            mosccds=`echo $mosccds | sed $sedarg`
        fi
    done

    # Make sure at least one outer CCD was collecting data
    # Outer CCDs are necessary to determine the QPB (first index is central CCD)
    if [ "$mosccds" != "1 0 0 0 0 0 0" ]; then
        # Record the CCD states into individual variables for readability
        set -- $mosccds
        ccd1=$1
        ccd2=$2
        ccd3=$3
        ccd4=$4
        ccd5=$5
        ccd6=$6
        ccd7=$7

        # Record the CCDs selected for analysis into an external file
        echo 'The CCDs selected for mos'$pref' are '$mosccds >> ../summary.txt

        # Create the source spectra, RMFs, and ARFs
        echo 'Creating source spectra and images' >> ../summary.txt
        
        # Run mos-spectra with choices $mask and $regionfile as above
        echo 'mos-spectra prefix='$pref' caldb=$CALDB mask='$mask' elow=0 ehigh=0 ccd1='$ccd1' ccd2='$ccd2' ccd3='$ccd3' ccd4='$ccd4' ccd5='$ccd5' ccd6='$ccd6' ccd7='$ccd7' region='$regionfile' > ../mos'$pref'-spectra_output.txt 2>&1' >> ../summary.txt
            mos-spectra prefix=$pref caldb=$CALDB mask=$mask elow=0 ehigh=0 ccd1=$ccd1 ccd2=$ccd2 ccd3=$ccd3 ccd4=$ccd4 ccd5=$ccd5 ccd6=$ccd6 ccd7=$ccd7 region=$regionfile > ../mos$pref-spectra_output.txt 2>&1

        # Check if there are insufficient events to estimate the background
        if grep -q 'Illegal division by zero' '../mos'$pref'-spectra_output.txt'; then
            echo 'There was insufficient corner data to estimate the QPB background for mos'$pref
            echo 'There was insufficient corner data to estimate the QPB background for mos'$pref >> ../summary.txt
        else 
            # Create the Quiescent Particle Background (QPB) file
            echo 'mos_back prefix='$pref' caldb=$CALDB diag=0 elow=0 ehigh=0 ccd1='$ccd1' ccd2='$ccd2' ccd3='$ccd3' ccd4='$ccd4' ccd5='$ccd5' ccd6='$ccd6' ccd7='$ccd7' > ../mos'$pref'_back_output.txt 2>&1' >> ../summary.txt
            mos_back prefix=$pref caldb=$CALDB diag=0 elow=0 ehigh=0 ccd1=$ccd1 ccd2=$ccd2 ccd3=$ccd3 ccd4=$ccd4 ccd5=$ccd5 ccd6=$ccd6 ccd7=$ccd7 > ../mos${pref}_back_output.txt 2>&1
        fi

        echo 'Finished mos'$pref >> ../summary.txt
    else
        # Record that this prefix is not usuable for further analysis
        echo 'Finished mos'$pref >> ../summary.txt
        echo 'All CCDs were anomalous for 'mos$pref >> ../summary.txt
    fi
done

#######################
# 9. Process & Delete #
#######################

# Process the raw output into python files in the $obsID directory, and delete
# the remaining files afterwards

echo -e '\nStep 9: Process the output data and delete intermediate files' >> ../summary.txt

for pref in $mosprefixes; do
    pref=mos$pref

    # Check if requisite files are present
    if [ ! -f $pref'-obj.pi' ]; then
        echo $pref'-obj.pi does not exist, data cannot be processed.' >> ../summary.txt
        continue
    fi

    if [ ! -f $pref'.arf' ]; then
        echo $pref'.arf does not exist, data cannot be processed.' >> ../summary.txt
        continue
    fi

    if [ ! -f $pref'.rmf' ]; then
        echo $pref'.rmf does not exist, data cannot be processed.' >> ../summary.txt
        continue
    fi

    if [ ! -f $pref'-back.pi' ]; then
        echo $pref'-back.pi does not exist, data cannot be processed.' >> ../summary.txt
        continue
    fi 
    
    echo 'python '$cdir'/spc2dat.py --xmmdata '$xmmdata' --obsID '$obsID' --prefix '$pref >> ../summary.txt 
    python $cdir/spc2dat.py --xmmdata $xmmdata --obsID $obsID --prefix $pref
done

# Check if python output successfully written, otherwise failed
if ls ./*_processed.h5 1> /dev/null 2>&1; then
    echo 'At least one hdf5 output created' >> ./summary.txt
else
    echo 'No python output created' >> ./summary.txt
    echo 'Processing failed!' >> ./summary.txt
    echo 'No python output created'
    echo 'Processing failed!'
    exit 1
fi

# Check which files were not successfully created
for pref in $mosprefixes; do
    pref=mos$pref
    if [ ! -f $pref'_processed.h5' ]; then
        echo $pref'_processed.h5 was not successfully created' >> ./summary.txt
        echo $pref'_processed.h5 was not successfully created'
    fi
done

# Done!
echo -e '\nComplete!' >> ./summary.txt
echo 'Complete!'
