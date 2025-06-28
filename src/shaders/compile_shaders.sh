rm -rf jai
mkdir jai

for filename in *.glsl; do
    if [ -f "$filename" ]; then
      ./sokol-shdc -i "$filename" -o "./jai/${filename/.glsl/.jai}" -l glsl430:glsl300es:metal_macos -f sokol_jai
    fi
done
