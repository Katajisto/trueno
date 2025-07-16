#!/bin/bash
set -e
cd src/shaders/
./compile_shaders.sh
cd ..
cd ..
jai-linux -x64 first.jai
./first
