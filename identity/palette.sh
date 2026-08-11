#!/usr/bin/env bash
# SevenOS palette — canonical source lives in core/design/palette.sh
# This file exists for backward compatibility with scripts that source identity/palette.sh

_PALETTE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_PALETTE_DIR/../core/design/palette.sh"
