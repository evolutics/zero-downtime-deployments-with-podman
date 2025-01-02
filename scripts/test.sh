#!/bin/bash

set -o errexit -o nounset -o pipefail

main() {
  local -r script_folder="$(dirname "$(readlink --canonicalize "$0")")"
  cd "$(dirname "${script_folder}")"

  travel-kit

  scripts/demo.sh docker caddy
  scripts/demo.sh podman caddy
  scripts/demo.sh docker haproxy
  scripts/demo.sh podman haproxy
}

main "$@"
