#!/bin/bash

#SBATCH --job-name=test
#SBATCH --time=06:00:00
#SBATCH --account=pc_heptheory
#SBATCH --partition=lr5
#SBATCH --qos=lr_normal
#SBATCH --mail-type=BEGIN,END
#SBATCH --mail-user=yjpark99@berkeley.edu


source source_dirs.sh
echo $cdirs

filename=$cdirs/../data/PerseusChandra_obsIDs.txt
while IFS= read -r line || [ -n "$line" ];
do
    echo $line
    bash chandra_perseus_data_reduction.sh $line
done < $filename


python Perseus_Data.py --load_dir=$perseus_data --list_dir=$cdirs/../data/ --save_dir=$result_dir