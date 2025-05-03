# docker build -t bitnet-b1.58-2b-4t-arm:latest .
# docker run -it --rm bitnet-b1.58-2b-4t-arm:latest

# Build stage
FROM python:3.9-slim AS builder

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install build dependencies
RUN apt-get update && apt-get install -y \
    python3-pip \
    python3-dev \
    cmake \
    build-essential \
    git \
    software-properties-common \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install LLVM
RUN wget -O - https://apt.llvm.org/llvm.sh | bash -s 18

# Clone the BitNet repository
WORKDIR /build
RUN git clone --recursive https://github.com/microsoft/BitNet.git

# Install Python dependencies
RUN pip install --no-cache-dir -r /build/BitNet/requirements.txt

# Build BitNet
WORKDIR /build/BitNet
RUN pip install --no-cache-dir -r requirements.txt \
    && python utils/codegen_tl1.py \
        --model bitnet_b1_58-3B \
        --BM 160,320,320 \
        --BK 64,128,64 \
        --bm 32,64,32 \
    && export CC=clang-18 CXX=clang++-18 \
    && mkdir -p build && cd build \
    && cmake .. -DCMAKE_BUILD_TYPE=Release \
    && make -j$(nproc)

# Download the model
RUN huggingface-cli download microsoft/BitNet-b1.58-2B-4T-gguf \
    --local-dir /build/BitNet/models/BitNet-b1.58-2B-4T

# Convert the model to GGUF format and sets up env. Probably not needed.
RUN python setup_env.py -md /build/BitNet/models/BitNet-b1.58-2B-4T -q i2_s

# Final stage
FROM python:3.9-slim

# Set environment variables. All but the last two are not used as they don't expand in the CMD step.
ENV MODEL_PATH=/app/models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf
ENV NUM_TOKENS=1024
ENV NUM_THREADS=4
ENV CONTEXT_SIZE=4096
ENV PROMPT="Hello from BitNet!"
ENV PYTHONUNBUFFERED=1
ENV LD_LIBRARY_PATH=/usr/local/lib

# Copy from builder stage
WORKDIR /app
COPY --from=builder /build/BitNet /app

# Install Python dependencies (only runtime)
RUN <<EOF
pip install --no-cache-dir -r /app/requirements.txt
cp /app/build/3rdparty/llama.cpp/ggml/src/libggml.so /usr/local/lib
cp /app/build/3rdparty/llama.cpp/src/libllama.so /usr/local/lib
EOF

# Set working directory
WORKDIR /app

# Set entrypoint for more flexibility
ENTRYPOINT ["python", "./run_inference.py"]

# Default command arguments
CMD ["-m", "/app/models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf", "-n", "1024", "-cnv", "-t", "4", "-c", "4096", "-p", "Hello from BitNet!"]