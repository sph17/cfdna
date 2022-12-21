ARG SV_BASE_MINI_IMAGE=us.gcr.io/broad-dsde-methods/gatk-sv/sv-base-mini:2022-06-10-v0.23-beta-9c6fbf56
ARG R_VIRTUAL_ENV_IMAGE=us.gcr.io/broad-dsde-methods/gatk-sv/sv-base-virtual-env:2022-06-10-v0.23-beta-9c6fbf56
ARG PYTHON_VIRTUAL_ENV_IMAGE=us.gcr.io/broad-dsde-methods/gatk-sv/samtools-cloud-virtual-env:2022-06-10-v0.23-beta-9c6fbf56

ARG CONDA_INSTALL_DIR=/opt/conda
ARG CONDA_ENV_NAME="sv-base-vep"

############# get handle for sv-base-mini, for copying HTSLIB info
FROM $SV_BASE_MINI_IMAGE as sv_base_mini

############# get python environment and add to it
FROM $PYTHON_VIRTUAL_ENV_IMAGE as python_virtual_env

# install any build dependencies
ARG BUILD_DEPS="g++ make apt-transport-https ca-certificates wget libcurl4-openssl-dev bcftools samtools git-all"
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -qqy update --fix-missing && \
    apt-get -qqy install --no-install-recommends $BUILD_DEPS

# install conda packages
# 
ARG CONDA_PKGS="ensembl-vep"
RUN conda install -qy --freeze-installed -n $CONDA_ENV_NAME -c conda-forge -c bioconda -c anaconda $CONDA_PKGS
RUN conda install -qy --force-reinstall -n $CONDA_ENV_NAME -c conda-forge -c bioconda tabix=1.11

# clean unneeded stuff
RUN conda clean -ay --force-pkgs-dirs

# clone plugins
RUN apt -qqy update && \
    apt -qqy install git
RUN mkdir /home/git && \
     cd /home/git && \
     git clone https://github.com/konradjk/loftee.git
RUN cp -r /home/git/loftee /opt/plugins/loftee/
RUN rm -rf /home/git/
RUN mkdir /home/git && \
     cd /home/git && \
     git clone https://github.com/Ensembl/VEP_plugins.git
RUN cp -r /home/git/VEP_plugins /opt/plugins/
RUN rm -rf /home/git/