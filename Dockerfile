FROM ubuntu:20.04

# https://github.com/anibali/docker-torch/blob/master/no-cuda/Dockerfile
# Use Tini as the init process with PID 1
ADD https://github.com/krallin/tini/releases/download/v0.10.0/tini /tini
RUN chmod +x /tini
ENTRYPOINT ["/tini", "--"]

RUN apt-get update 

# Install dependencies for OpenBLAS, and Torch
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential git gfortran \
    # python3.8 as default on Ubuntu 20.04
    python3-numpy python3-nose python3-pandas \
    python3 python3-setuptools python3-dev \
    python3-h5py \
    pep8 python3-pip python3-wheel \
    python3-sphinx \
    # for python libs
    curl wget unzip libreadline-dev libjpeg-dev libpng-dev ncurses-dev \
    imagemagick gnuplot gnuplot-x11 libssl-dev libzmq3-dev graphviz \
    # OpenBLAS
    swig libopenblas-base \
    # HDF5
    libhdf5-dev \
    # cmake
    build-essential cmake libboost-system-dev libboost-thread-dev \
    libboost-program-options-dev libboost-test-dev libeigen3-dev \
    zlib1g-dev libbz2-dev liblzma-dev libboost-all-dev && \
    pip install --upgrade pip && \
    pip install --upgrade setuptools 

# Clone viet-asr, NeMo and libs for installing ctc_decoders
WORKDIR /home/root/speech2text
RUN git clone https://github.com/NVIDIA/NeMo.git --branch r1.5.0
RUN git config --global http.postBuffer 1048576000 && git clone https://github.com/dangvansam98/viet-asr.git

# Create simlink
RUN ln -s /usr/bin/python3.8 /usr/bin/python

# Installation of ctc_decoders
WORKDIR /home/root/speech2text/NeMo/scripts/asr_language_modeling/ngram_lm/
# https://github.com/NVIDIA/NeMo/blob/main/scripts/asr_language_modeling/ngram_lm/install_beamsearch_decoders.sh
# libraries are installed above
RUN git clone https://github.com/NVIDIA/OpenSeq2Seq -b ctc-decoders
RUN mv OpenSeq2Seq/decoders .
RUN rm -rf OpenSeq2Seq

# copy of install_beamsearch_decoders.sh
WORKDIR /home/root/speech2text/NeMo/scripts/asr_language_modeling/ngram_lm/decoders
RUN git clone https://github.com/kpu/kenlm.git 
RUN wget http://www.openfst.org/twiki/pub/FST/FstDownload/openfst-1.6.3.tar.gz
RUN tar -xzvf openfst-1.6.3.tar.gz
RUN git clone https://github.com/progschj/ThreadPool.git

WORKDIR /home/root/speech2text/NeMo/scripts/asr_language_modeling/ngram_lm/decoders/kenlm
RUN mkdir build
WORKDIR /home/root/speech2text/NeMo/scripts/asr_language_modeling/ngram_lm/decoders/kenlm/build
RUN cmake ..
RUN make -j1

WORKDIR /home/root/speech2text/NeMo/scripts/asr_language_modeling/ngram_lm/decoders/
# python setup.py doesn't work properly in docker
RUN pip install --upgrade setuptools==65.0.2 && pip install .
# _swig_decoders missing error while importing ctc_decoders
#RUN cp build/lib.linux-x86_64-3.8/_swig_decoders.cpython-38-x86_64-linux-gnu.so .
RUN python ctc_decoders_test.py

WORKDIR /home/root/speech2text/viet-asr
# seems like it works with v1.5.1, also it installs all needed packages
# but we still have to use the locally cloned repo in viet-asr
RUN pip install nemo_toolkit[all]==1.5.1
RUN sed -i "s/placement=nemo.core.DeviceType.GPU,/placement=nemo.core.DeviceType.CPU,/g" infer.py
RUN sed -i "s/lm_path=\"NeMo/lm_path=\"nemo/g" infer.py
RUN pip uninstall --yes librosa && pip install loguru pyctcdecode
RUN pip install librosa==0.9.2 numba==0.56.2


RUN python infer.py audio_samples
COPY app.py-queue /home/root/speech2text/viet-asr/app.py
COPY ./index.html /home/root/speech2text/viet-asr/templates/index.html
RUN pip install paho-mqtt
CMD ["python", "./app.py"]
