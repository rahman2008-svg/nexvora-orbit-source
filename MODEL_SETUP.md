# Models
Default: Qwen3 1.7B int4 (~1.1 GB download). Devices with < 4 GB RAM are steered to LFM2.5 350M (`recommendedModelId`).
Models are never bundled in the APK; they download on first setup or can be sideloaded from a folder (Settings → Language model).
Default source is upstream Eva's release assets; set `ORBIT_MODEL_BASE` to use your own release built by `android-release.yml`.
Offline ASR: sherpa-onnx streaming Zipformer (English, ~57 MB). Embeddings for documents: nomic-embed v2.
