FROM ubuntu:24.04
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PATH /opt/conda/bin:$PATH

ENV SYCL_DEVICE_FILTER=level_zero
ENV SYCL_PROGRAM_COMPILE_OPTIONS="-ze-opt-large-register-file"
ENV ENABLE_L0_PROFILING=1

RUN apt update --fix-missing && \
    apt install -y wget curl cmake python3-pip python3-dev gnupg bzip2 ca-certificates git


RUN wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor | tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null
RUN echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | tee /etc/apt/sources.list.d/oneAPI.list
# Install Intel oneAPI base toolkit and required packages
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update  \
     && apt install -y intel-basekit intel-mkl intel-opencl-icd intel-mkl intel-oneapi-compiler-dpcpp-cpp intel-oneapi-dev-utilities \
     && apt clean \
     && rm -rf /var/lib/apt/lists/*

RUN ln -s /opt/intel/oneapi/compiler/2025.0/lib/libsycl.so.8 /opt/intel/oneapi/compiler/2025.0/lib/libsycl.so.7
RUN ln -s /opt/intel/oneapi/mkl/2025.0/lib/libmkl_sycl_blas.so.5 /opt/intel/oneapi/mkl/2025.0/lib/libmkl_sycl_blas.so.4
RUN ldconfig

SHELL ["/bin/bash", "-c"]

RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh && \
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    conda create -n llm-cpp python=3.11
RUN echo "conda activate llm-cpp" >> ~/.bashrc
RUN pip install --no-cache-dir --root-user-action=ignore --pre --upgrade ipex-llm[cpp] && \
    init-ollama

# Set environment variables
ENV OLLAMA_NUM_GPU=999
ENV no_proxy=localhost,127.0.0.1
ENV ZES_ENABLE_SYSMAN=1
ENV SYCL_CACHE_PERSISTENT=1
ENV SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1
ENV ONEAPI_DEVICE_SELECTOR=level_zero:0

RUN echo "source /opt/intel/oneapi/setvars.sh" >> ~/.bashrc

# Expose default Ollama port
EXPOSE 11434

CMD ["/bin/bash", "-c", "source /opt/intel/oneapi/setvars.sh && /ollama serve"]