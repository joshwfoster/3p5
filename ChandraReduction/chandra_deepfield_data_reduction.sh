#!/bin/bash


obsid=$1
obstype=$2

echo "Data process for ObsID $obsid for $obstype"

source source_dirs.sh

if [ $obstype = "ccls" ]
then
    deepfield_data=$ccls_data
elif [ $obstype = "cdfs" ]
then
    deepfield_data=$cdfs_data
else
    echo "proper obstype not provided"
    exit
fi


#####################
# Initializing CIAO #
#####################

source $ciao_dir/bin/ciao.sh



##########################
# Download/Process ObsID #
##########################

cd $deepfield_data

if [ $obsid = "1431_000" ]; then
    download_chandra_obsid 1431
    splitobs 1431 1431
else
    download_chandra_obsid $obsid
fi

chandra_repro $obsid $obsid/repro check_vf_pha=yes

echo "finished running chandra_repro"


cd $deepfield_data/$obsid


# creating directories for output files
if [ ! -d output ]; then
	mkdir output
fi

if [ ! -d pfiles ]; then
	mkdir pfiles
fi

if [ ! -d spec ]; then
	mkdir spec
fi

if [ ! -d temp ]; then
	mkdir temp
fi

if [ ! -d bkg ]; then
	mkdir bkg
fi


cd $deepfield_data/$obsid/repro


# getting filenames for the data process
find_res=$(find . -type f -regex ".*_repro_evt2.fits")
evtfile=${find_res#./}
find_res=$(find . -type f -regex ".*_repro_fov1.fits")
fovfile=${find_res#./}
find_res=$(find . -type f -regex ".*asol1.fits")
asolfile=${find_res#./}


#####################
# Deflaring Process #
#####################

# extract light curve in 2.3-7, 9.5-12, and 0.3-3 keV bands
dmextract "${evtfile}[energy=2300:7000][bin time=::1000]" flare_2p3_7.lc op=ltc1
dmextract "${evtfile}[energy=9500:12000][bin time=::1000]" flare_9p5_12.lc op=ltc1
dmextract "${evtfile}[energy=300:3000][bin time=::1000]" flare_0p3_3.lc op=ltc1


# deflare the lightcurves
deflare flare_2p3_7.lc gti_2p3_7.fits method=clean scale=3
deflare flare_9p5_12.lc gti_9p5_12.fits method=clean scale=3
deflare flare_0p3_3.lc gti_0p3_3.fits method=clean scale=3


# filter the flare times
dmcopy "${evtfile}[@gti_2p3_7.fits]" evt_filt1.fits
dmcopy "evt_filt1.fits[@gti_9p5_12.fits]" evt_filt2.fits
dmcopy "evt_filt2.fits[@gti_0p3_3.fits]" filtered_events.fits


# remove intermediate files
rm evt_filt1.fits
rm evt_filt2.fits

punlearn ardlib

echo "lc_clean process finished"


###################################
# Creating ARF, RMF, and Spectrum #
###################################

skyfov filtered_events.fits ../temp/nomask_sky.fits
dmcopy "../temp/nomask_sky.fits[ccd_id=0,1,2,3]" ../temp/nomask_acis-i_sky.fits


# Extract the spectrum, create the ARF, create the RMF
specextract "filtered_events.fits[sky=region(../temp/nomask_acis-i_sky.fits)]" ../spec/nomask_fov2 binarfwmap=3


punlearn ardlib

echo "finished data processing"


###########################
# Background file process #
###########################

cd $deepfield_data/$obsid

ls $caldb_dir/data/chandra/acis/bkgrnd/*bgstow_* >> bkg/bkg_list.lis

dmmerge @bkg/bkg_list.lis bkg/all_bkg.fits
dmcopy "bkg/all_bkg.fits[status=0]" bkg/bkg_cleaned.fits

gainfile=$(dmkeypar repro/filtered_events.fits GAINFILE echo+)


acis_process_events infile=bkg/bkg_cleaned.fits outfile=bkg/bkg_newgain.fits acaofffile=NONE stop="none" doevtgrade=no apply_cti=yes apply_tgain=no calculate_pi=yes pix_adj=NONE gainfile=$caldb_dir/data/chandra/acis/det_gain/$gainfile eventdef="{s:ccd_id,s:node_id,i:expno,s:chip,s:tdet,f:det,f:sky,s:phas,l:pha,l:pha_ro,f:energy,l:pi,s:fltgrade,s:grade,x:status}"


reproject_events infile="bkg/bkg_newgain.fits[cols -time]" outfile=bkg/bkg_newgain_reproj.fits aspect=repro/$asolfile match=repro/filtered_events.fits random=0

dmextract "bkg/bkg_newgain_reproj.fits[sky=region(temp/nomask_acis-i_sky.fits)][bin PI]" bkg/bkg_spec.pi


punlearn ardlib

echo "finished background processing"