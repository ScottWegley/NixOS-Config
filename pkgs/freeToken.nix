{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  pythonOlder,
  setuptools,
  wheel,
  torch,
  cudaPackages,
  autoAddDriverRunpath,
  addOpenGLRunpath,
  makeWrapper, # Needed to wrap the binary
  numpy,
  einops,
  fastapi,
  flashlib,
  gguf,
  huggingface_hub,
  msgpack,
  modelscope,
  openai,
  partial-json-parser,
  prompt_toolkit,
  pydantic,
  pyzmq,
  safetensors,
  tqdm,
  transformers,
  triton,
  uvicorn,
  apache-tvm-ffi,
}:
buildPythonPackage rec {
  pname = "freetoken";
  version = "0.1.0";

  pyproject = true;

  src = fetchFromGitHub {
    owner = "FlashML-org";
    repo = "FreeToken";
    rev = "v${version}";
    hash = ""; # Replace with correct SRI hash
  };

  disabled = pythonOlder "3.10";

  build-system = [
    setuptools
    wheel
  ];

  # These are added to PATH at runtime by buildPythonPackage's wrapper
  buildInputs = [
    cudaPackages.cuda_nvcc # Makes nvcc available at runtime for JIT
    cudaPackages.cuda_cudart # CUDA runtime libraries
    cudaPackages.cuda_cccl # CUDA standard library headers (if needed)
    autoAddDriverRunpath # Ensures NVIDIA driver libs are found
    addOpenGLRunpath
  ];

  nativeBuildInputs = [
    makeWrapper # For the explicit wrapper
    cudaPackages.cuda_nvcc # Also needed at build time to compile extensions
    cudaPackages.cuda_cudart
    cudaPackages.cuda_cccl
  ];

  dependencies = [
    apache-tvm-ffi
    einops
    fastapi
    flashlib
    gguf
    huggingface_hub
    msgpack
    modelscope
    numpy
    openai
    partial-json-parser
    prompt_toolkit
    pydantic
    pyzmq
    safetensors
    torch
    tqdm
    transformers
    triton
    uvicorn
  ];

  optional-dependencies = {
    accel = [];
    dev = ["pytest>=6.0"];
  };

  CUDA_HOME = "${cudaPackages.cuda_nvcc}";
  TORCH_CUDA_ARCH_LIST = "8.0;8.6;8.9;9.0;9.0a"; # RTX 5090 is sm_120, adjust if needed

  env = {
    CUDA_HOME = "${cudaPackages.cuda_nvcc}";
  };

  # Explicitly wrap the 'ft' binary to ensure nvcc is in PATH
  postInstall = ''
    wrapProgram $out/bin/ft \
      --prefix PATH : ${lib.makeBinPath [cudaPackages.cuda_nvcc python]}
  '';

  pythonImportsCheck = ["freetoken"];

  meta = with lib; {
    description = "Local MoE-offload LLM inference runtime";
    homepage = "https://github.com/FlashML-org/FreeToken";
    license = licenses.asl20;
    platforms = ["x86_64-linux"];
    badPlatforms = ["aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
  };
}
