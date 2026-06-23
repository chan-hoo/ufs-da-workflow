#PBS -S /bin/bash
#PBS -A nral0032
#PBS -N gdas_build
#PBS -o gdas_build.log
#PBS -j oe
#PBS -q main
#PBS -l walltime=00:45:00
#PBS -l select=1:ncpus=8:mpiprocs=8
#PBS -l place=vscatter

export BUILD_JOBS="8"
cd {{ JEDI_BUILD_DIR }}
./build.sh -f -t derecho
