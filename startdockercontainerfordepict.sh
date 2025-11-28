cd ~/jdcs/claude2/depict

# Start container with the working image
docker run -it --rm \
  -v $(pwd):/workspace \
  -p 8000:8000 \
  --name depict-work \
  jsavage/depict-builder:ubuntu22.04-nightly-2024-05-01 \
  bash