#!/bin/bash


source source_dirs.sh

filename=$cdirs/../data/CDFS_obsIDs.txt

while IFS= read -r line || [ -n "$line" ];
do
    echo $line
    bash chandra_deepfield_data_reduction.sh $line cdfs
done < $filename

filename=$cdirs/../data/CCLS_obsIDs.txt

while IFS= read -r line || [ -n "$line" ];
do
    echo $line
    bash chandra_deepfield_data_reduction.sh $line ccls
done < $filename


python DeepField_Data.py --cdfs_dir=$cdfs_data --ccls_dir=$ccls_data --list_dir=$cdirs/../data/ --save_dir=$result_dir