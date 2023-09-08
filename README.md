# 3p5
**For analysis of X-Ray datasets in search of the 3.5 keV Line**

[![arXiv](https://img.shields.io/badge/arXiv-2309.03254%20-green.svg)](https://arxiv.org/abs/2309.03254)

3p5 is a repository containing the data reduction code, data analysis code, and data products used in [2309.03254](https://arxiv.org/abs/2309.03254), so that the results in that work are completely reproducible.
That work re-analyzed six datasets previously suggested to show evidence for the 3.5 keV line, and found no robust evidence for the line in any of the datasets.

## Authors

-  Chris Dessert; cd2458 at nyu dot edu
-  Joshua W. Foster; jwfoster at mit dot edu
-  Yujin Park; yjpark99 at berkeley dot edu
-  Benjamin R. Safdi; brsafdi at berkeley dot edu

## Dependencies

The XMM-Newton data reduction code is a combination of bash and Python. The code requires installation of the [XMM-SAS](https://xmm-tools.cosmos.esa.int/external/xmm_user_support/documentation/sas_usg/USG/), [HEADAS](https://heasarc.nasa.gov/lheasoft/), and [CIAO](https://cxc.cfa.harvard.edu/ciao4.14/) softwares. In addition the python modules [numpy](http://www.numpy.org/), [astropy](http://www.astropy.org/), [h5py](https://www.h5py.org/), [beautifulsoup4](https://pypi.org/project/beautifulsoup4/), and [pandas](https://pandas.pydata.org/) are required.

The Chandra data reduction code similarly requires installation of [CIAO](https://cxc.cfa.harvard.edu/ciao4.14/), and `numpy`, `astropy`, and `h5py`.

The data analysis code requires `Jupyter` along with python modules `matplotlib`, `numpy`, `scipy`, `iminuit`, `h5py`, 

## Processing XMM-Newton Data

In [2309.03254](https://arxiv.org/abs/2309.03254) we process several XMM-Newton datasets. In `XMMReduction` we provide the code to reduce this data.

To use the code, first establish the directories where the `SAS`, `HEADAS`, and `CIAO` tools are installed and the output data should be written in `source_dirs.sh`. Then to process all exposures associated with an observation with ID `obsID`, use

```
./dl2dat.sh $obsID $RunWavdetect
```

where `$RunWavdetect` is `0` or `1` depending on if the point source masking is done using the `CIAO` tool `wavdetect` or the `SAS` tool `cheese`. In our analyses we use `wavdetect` for all reductions except for that of M31. The code will then process the observation and output data in `h5py` format.

The list of observation IDs processed can be found in the `data` folder, in text files with names `<target>_obsIDs.txt`, where `<target>` takes values `Perseus`, `Coma`, `Centaurus`, `Ophiuchus`, and `M31`. The CCFs are also required, and stored in `data/CCFs`. The directory in `source_dirs.sh` is set to find these files assuming this GitHub is cloned, but you may need to change this directory if you edit the directory structure.

## Processing Chandra Data

We also process several Chandra datasets. We provide the code used for Chandra data processing in `ChandraReduction`.

To use the code, first establish the directories where `CIAO` and `CALDB` are installed and the output files should be written in `source_dirs.sh`. Then run

```
bash perseus_process.sh
```

to process all `Perseus` observations and 

```
bash deepfield_process.sh
```

to process all observations of `Chandra Deep Field South (CDFS)` and `Chandra-COSMOS Legacy Survey (CCLS)`, which are saved in separate files.

The list of observation IDs can again be found in the `data` folder, where `<target>` now takes values `PerseusChandra`, `CDFS`, and `CCLS`.

## Analyzing XMM-Newton Cluster Data

We provide the relevant code and files used for the analysis of the Perseus data in `XMM_Cluster_Analysis`. The Perseus observation we analyze in the main text is available at `Data/ReducedData/Perseus_Data.h5`, and all necessary files to create spectral model components are available in `Data/ModelComponents`. The code used for analysis is available in `jupyter` notebooks, numbered in the order they must be run. The notebooks themselves are well-documented; here we briefly describe their usage and purpose.

1. `1_Make_Fit_Dictionary.ipynb` creates a parameter file that describes the null model components, which is saved in the `Fitting` folder.
2. `2_Initial_Fit.ipynb` performs an initial fit of the model to the data, prior to any line dropping.
3. `3_Component_Drop.ipynb` performs the line drop tests, then the continuum component drop tests, and saves the final model with only important components.
4. `4_Make_Signal_Dictionary.ipynb` adds the putative signal line to the model created in the previous step.
5. `5_Profiled_Analysis.ipynb` computes the profile likelihood as a function of the signal line flux, which is shown in Fig. 6 (above).
