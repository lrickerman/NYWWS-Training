# NYWWS--GENEXUS FILE TRANSFER
# Genexus .bam File Transfer to GCP
### Introduction

The NYWWS.sh script transfers the processed bam files (*.merged.bam.ptrim.bam) to the NYWWS GCP at Syracuse for analysis.

The process includes the following:
1. SSH connection to the local Genexus instrument
2. Searching the instrument for the most recent processed bam files
3. Copying these files into /tmp/nywws/
4. Renaming the files according to the ID specified when the Genexus run was initiated (i.e. the sample ID)
5. Uploading the processed bam files under the sample ID name
6. Logging all data into a genexus.log file



### Dependencies

* SSH key (private and public)
* Instrument IP address
* [Python3.8+](https://www.python.org/downloads/)
* [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
* [Bash 4.0+](https://www.gnu.org/software/bash/) - NOTE: if running macOS with Bash v3, [Conda](https://docs.conda.io/en/latest/miniconda.html) environment with Bash v4 or higher is required


