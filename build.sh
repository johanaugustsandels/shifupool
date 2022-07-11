#!/usr/bin/env bash
set -euo pipefail

pushd /c++
meson subprojects download
meson builddir

pushd builddir
ninja

echo
echo "-------------------------------------------"
if [[ -f /c++/builddir/src/miningproblem ]]; then
  echo "OK"
else
  echo "wat"
fi