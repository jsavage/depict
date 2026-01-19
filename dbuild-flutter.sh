echo "[dbuild-flutter.sh] about to run ./docker-flutter.sh build linux"
./docker-flutter.sh build linux
echo "[dbuild-flutter.sh]] about to run ./scripts/copy_depict_ffi.sh"
./scripts/copy_depict_ffi.sh
echo "[dbuild-flutter.sh] about to run./docker-flutter.sh build linux"
./docker-flutter.sh build linux
echo "[dbuild-flutter.sh] Finished"
