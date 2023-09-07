#!/bin/bash



obsid=$1

echo "chandra process for obsID ${obsid}"

source source_dirs.sh


#####################
# Initializing CIAO #
#####################

source $ciao_dir/bin/ciao.sh


##########################
# Download/Process ObsID #
##########################

cd $perseus_data

download_chandra_obsid ${obsid}

chandra_repro $perseus_data/$obsid $perseus_data/$obsid/repro check_vf_pha=yes

echo "chandra data reprocessed"


cd $perseus_data/$obsid/repro


# finding the files needed

find_res=$(find . -type f -regex '.*_repro_evt2.fits')
evtfile=${find_res#./}
find_res=$(find . -type f -regex '.*_repro_fov1.fits')
fovfile=${find_res#./}
find_res=$(find . -type f -regex '.*asol1.fits')
asolfile=${find_res#./}



########################
# Point Source Masking #
########################

# create image

fluximage $evtfile binsize=1 bands=broad outroot=wav


# make psf map

mkpsfmap wav_broad_thresh.img outfile=psfmap.fits energy=1.5 ecf=0.9

echo "made psf map file"


# find the sources using wavdetect command

punlearn wavdetect
pset wavdetect infile=wav_broad_thresh.img
pset wavdetect psffile=psfmap.fits

pset wavdetect outfile=wav_src.fits
pset wavdetect scellfile=wav_scell.fits
pset wavdetect imagefile=wav_imgfile.fits
pset wavdetect defnbkgfile=wav_nbkg.fits
pset wavdetect clobber=no

wavdetect

echo "sources found and list made"

# remove sources

dmcopy "${evtfile}[exclude sky=region(wav_src.fits)]" masked_result.fits


########################################
# Creating ARF, RMF, and spectrum file #
########################################

cd $perseus_data/$obsid

if [ ! -d spec ]; then
	mkdir spec
fi

skyfov "repro/masked_result.fits" spec/masked_sky.fits
dmcopy "spec/masked_sky.fits[ccd_id=0,1,2,3]" spec/masked_acis-i_sky.fits

specextract "repro/masked_result.fits[sky=region(spec/masked_acis-i_sky.fits)]" spec/specextract_result binarfwmap=3

###########################
# Background file process #
###########################

if [ ! -d bkg ]; then
	mkdir bkg
fi


blanksky evtfile="repro/$evtfile" outfile="bkg/blank_sky.fits"

dmextract "bkg/blank_sky.fits[ccd_id=0][bin PI]" bkg/acis-i_bkg0.pi
dmextract "bkg/blank_sky.fits[ccd_id=1][bin PI]" bkg/acis-i_bkg1.pi
dmextract "bkg/blank_sky.fits[ccd_id=2][bin PI]" bkg/acis-i_bkg2.pi
dmextract "bkg/blank_sky.fits[ccd_id=3][bin PI]" bkg/acis-i_bkg3.pi