# Dockerfile for Running BitNet-b1.58-2B-4T on ARM

I tested building and running the Dockerfile using a MacBook Pro M4 Max running [Rancher Desktop](https://rancherdesktop.io/). I wasn't able to convert to TL1 for a Tensor-optimized look-up table so I used I2_S (Integer 2-bit Symmetric).

You might need to increase the resources available to Rancher Desktop (or Docker Desktop) to see a decent amount of performance. I was seeing ~20-30 token/s. I used QEMU emulation. I haven't yet tested using the Apple Virtualization framework.

I put together the steps to get this working on ARM from [Bjan Bowen's Blog](https://www.bijanbowen.com/bitnet-b1-58-on-raspberry-pi-4b/).

### Clone
```bash
git clone https://github.com/ajsween/bitnet-b1-58-arm-docker.git
```
### Build
```bash
cd bitnet-b1-58-arm-docker
docker build -t bitnet-b1.58-2b-4t-arm:latest .
```
### Run
```bash
docker run -it --rm bitnet-b1.58-2b-4t-arm:latest
```
### bash Commands I based the Dockerfile on:
```bash
apt update && apt install -y \
  python3-pip python3-dev cmake build-essential \
  git software-properties-common wget

wget -O - https://apt.llvm.org/llvm.sh | bash -s 18

git clone --recursive https://github.com/microsoft/BitNet.git
cd BitNet
pip install -r requirements.txt

python utils/codegen_tl1.py \
  --model bitnet_b1_58-3B \
  --BM 160,320,320 \
  --BK 64,128,64 \
  --bm 32,64,32

export CC=clang-18 CXX=clang++-18
rm -rf build && mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
cd ..

huggingface-cli download microsoft/BitNet-b1.58-2B-4T-gguf \
  --local-dir models/BitNet-b1.58-2B-4T

python run_inference.py \
  -m models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf \
  -p "Hello from BitNet on Pi4!" -cnv

python run_inference.py \
  -m models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf \
  -p "Hello from BitNet running on ARM in a container on a Apple M4 Max!" \
  -cnv -t 4 -c 2048
  ```

  ### References
  - [Rancher Desktop](https://rancherdesktop.io/)
  - [Bijan Bowen Blog](https://www.bijanbowen.com/bitnet-b1-58-on-raspberry-pi-4b/)
  - [Github: microsoft/BitNet](https://github.com/microsoft/BitNet)
  - [DeepWiki: BitNet.cpp](https://deepwiki.com/microsoft/BitNet/1-bitnet.cpp-overview)
  - [Ars Technica: Microsoft’s “1‑bit” AI model runs on a CPU only, while matching larger systems](https://arstechnica.com/ai/2025/04/microsoft-researchers-create-super%e2%80%91efficient-ai-that-uses-up-to-96-less-energy/)
  - [BitNet Demo](https://bitnet-demo.azurewebsites.net/)
  - [BitNet Tutorial](https://github.com/viraatdas/BitNet-Tutorial/blob/main/01_bitnet_quantization_types__i2_s__tl1__tl2__.md)
