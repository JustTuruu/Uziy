#!/usr/bin/env bash
# Runs the app on a real phone against the backend on this Mac.
# A phone cannot use "localhost" (that is the phone itself), so the Mac's Wi-Fi address is passed as
# API_BASE_URL. Phone and Mac must be on the same Wi-Fi.
#   tool/run_device.sh                 # pick the device interactively
#   tool/run_device.sh -d <device-id>  # any extra flutter run flags pass through
set -euo pipefail
cd "$(dirname "$0")/.."

ip="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
if [[ -z "$ip" ]]; then
  echo "Mac-ийн Wi-Fi хаяг олдсонгүй. Wi-Fi-д холбогдсон эсэхээ шалгана уу." >&2
  exit 1
fi
url="http://$ip:8080"

if ! curl -s -m 3 -o /dev/null "$url/actuator/health"; then
  echo "Backend $url дээр хариу өгөхгүй байна. backend/ дотор './gradlew bootRun' ажиллуулна уу." >&2
  exit 1
fi

echo "API_BASE_URL=$url"
exec flutter run --dart-define=API_BASE_URL="$url" "$@"
