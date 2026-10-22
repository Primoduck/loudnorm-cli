#!/usr/bin/env bash

set -euo pipefail

# Set a few colors
RED='\e[31m'; GRN='\e[32m'; NC='\e[0m'; YLW='\e[33m'

# Check that only one argument is given. If not, exit.
if [[ "$#" -lt 1 || "$#" -gt 1 ]]; then
    echo -e "Usage: loud [${GRN}FILE${NC}]"
    exit 1
fi

# Check if ffmpeg and jq are installed
if ! command -v ffmpeg &>/dev/null; then
    echo -e "${YLW}ffmpeg${NC} not installed!"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo -e "${YLW}jq${NC} not installed!"
    exit 1
fi

# Set file path variable
file="$1"

# Create the output file name (ex. file_normalized.mp4)
out_file="${file%.*}_normalized.${file##*.}"

# Check if file is either .mp4 or .mkv, and that it is a file
if [[ "$file" == *.mp4 || "$file" == *.mkv ]]; then
    if [[ -f "$file" ]]; then
        echo -e "${GRN}Analyzing Audio...${NC}\n"
    else
        echo "Not a valid file (mp4 or mkv)"
        exit 1
    fi
else
    echo "Not a valid file (mp4 or mkv)"
    exit 1
fi

# Run first pass on the file to get values
first_pass=$(ffmpeg -i "$file" \
-hide_banner \
-filter_complex \
[0:a]loudnorm=I=-16:TP=-1.0:LRA=10:print_format=json \
-f null - 2>&1 | sed -n '/^{/,/^}/p')

# store first pass values in respective vars for input in second pass
input_i=$(jq -r '.input_i' <<< "$first_pass")
input_tp=$(jq -r '.input_tp' <<< "$first_pass")
input_lra=$(jq -r '.input_lra' <<< "$first_pass")
input_thresh=$(jq -r '.input_thresh' <<< "$first_pass")
offset=$(jq -r '.target_offset' <<< "$first_pass")

# Print results summary with suggestion values
echo -e "---------------------------------------------\n"
echo -e "Overall Loudness: ${YLW}$input_i${NC}"
echo -e "Target ${GRN}-16${NC} (-25 quiet, -10 loud)"
echo -e "Loudness Range[8-14]: ${YLW}$input_lra${NC}"
echo -e "Target ${GRN}11${NC} (8-15 good range, 15+ wide range)\n"
echo -e "---------------------------------------------\n"

# Prompt user to apply audio normalization to file
read -e -p "Increase overall loudness? [y/N] " user_input
echo ""

# Check if user input is valid
if [[ "$user_input" != "Y" && "$user_input" != "y" ]]; then
    echo -e "Exiting..."
    exit 1
fi

# Check if output file already exists
if [[ -e "$out_file" ]]; then
    echo -e "File already exists - $out_file"
    exit 1
fi

# Run second pass using first pass results
echo -e "${GRN}Normalizing Audio...${NC}\n"
ffmpeg -i "$file" \
-hide_banner \
-filter_complex \
[0:a]loudnorm=I=-16:TP=-1.0:LRA=10:measured_I="$input_i":measured_TP="$input_tp":measured_LRA="$input_lra":measured_thresh="$input_thresh":offset="$offset":linear=true \
-c:v copy -ar 48000 \
"$out_file" \
&> /dev/null

echo -e "File created: ${GRN}$out_file${NC}"
