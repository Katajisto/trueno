#!/bin/bash

cd src/shaders/
./compile_shaders.sh
cd ..
cd ..
/home/katajisto/bin/jai/bin/jai-linux -x64 first.jai
/home/katajisto/bin/jai/bin/jai-linux first.jai - wasm
