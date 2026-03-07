#!/usr/bin/env bash

set -euo pipefail

hook_name="${1:?expected hook name}"
shift || true

exec flo ui claude-hook "$hook_name" "$@"
