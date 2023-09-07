# 3p5
**For analysis of X-Ray datasets in search of the 3.5 keV Line**

[![arXiv](https://img.shields.io/badge/arXiv-2309.xxxxx%20-green.svg)](https://arxiv.org/abs/2309.xxxxx)

3p5 is a repository containing the data reduction code, data analysis code, and data products used in [2309.xxxxx](https://arxiv.org/abs/2309.xxxxx), so that the results in that work are completely reproducible.
That work re-analyzed six datasets previously suggested to show evidence for the 3.5 keV line, and found no robust evidence for the line in any of the datasets.

## Authors

-  Chris Dessert; cd2458 at nyu dot edu
-  Joshua W. Foster; jwfoster at mit dot edu
-  Yujin Park; yjpark99 at berkeley dot edu
-  Benjamin R. Safdi; brsafdi at berkeley dot edu

## Dependencies

The XMM-Newton data reduction code is a combination of bash and Python. The code requires installation of the [XMM-SAS](https://xmm-tools.cosmos.esa.int/external/xmm_user_support/documentation/sas_usg/USG/), [HEADAS](https://heasarc.nasa.gov/lheasoft/), and [CIAO](https://cxc.cfa.harvard.edu/ciao4.14/) softwares. In addition the python modules [numpy](http://www.numpy.org/), [astropy](http://www.astropy.org/), [h5py](https://www.h5py.org/), [beautifulsoup4](https://pypi.org/project/beautifulsoup4/), and [pandas](https://pandas.pydata.org/) are required.

The Chandra data reduction code has similar required installation of the [CIAO](https://cxc.cfa.harvard.edu/ciao4.14/), and the python modules [numpy](http://www.numpy.org/), [astropy](http://www.astropy.org/), and [h5py](https://www.h5py.org/).

## Processing XMM-Newton Data

In [2309.xxxxx](https://arxiv.org/abs/2309.xxxxx) we process a several XMM-Newton datasets. In `XMMReduction` we provide the code to reduce this data.

To use the code, first establish the directories where the `SAS`, `HEADAS`, and `CIAO` tools are installed and the output data should be written in `source_dirs.sh`. Then to process all exposures associated with an observation with ID `obsID`, use

```
./dl2dat.sh $obsID $RunWavdetect
```

where `$RunWavdetect` is `0` or `1` depending on if the point source masking is done using the `CIAO` tool `wavdetect` or the `SAS` tool `cheese`. In our analyses we use `wavdetect` for all reductions except for that of M31. The code will then process the observation and output data in `h5py` format.

The list of observation IDs processed can be found in the `data` folder, in text files with names `<target>_obsIDs.txt`, where `<target>` takes values `Perseus`, `Coma`, `Centaurus`, `Ophiuchus`, and `M31`. The CCFs are also required, and stored in `data/CCFs`. The directory in `source_dirs.sh` is set to find these files assuming this GitHub is cloned, but you may need to change this directory if you edit the directory structure.

## Processing Chandra Data

We provide the code used for Chandra data processing in `ChandraReduction`.

To use the code, first establish the directories where `CIAO` and `CALDB` are installed and the output files should be written in `source_dirs.sh`. Then use,

```
bash perseus_process.sh
```

for the data process of all observation IDs for Perseus and 

```
bash deepfield_process.sh
```

for the data process of all observation IDs for Chandra Deep Field South (CDFS) and Chandra-COSMOS Legacy Survey (CCLS), which are saved in separate files.

The list of observation IDs can be found in `data` folder, with same format described above where `<target>` is `PerseusChandra`, `CDFS`, and `CCLS`.
