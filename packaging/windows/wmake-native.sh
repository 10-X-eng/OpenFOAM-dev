#!/usr/bin/env bash
set -eo pipefail
export PATH=/usr/bin:$PATH
script=$(cygpath -u "${BASH_SOURCE[0]}")
source "$(dirname "$script")/environment.sh"
args=()
for arg in "$@"; do
    case "$arg" in
        [[:alpha:]]:*) args+=("$(cygpath -u "$arg")") ;;
        *) args+=("$arg") ;;
    esac
done
exec "$WM_DIR/wmake" "${args[@]}"
