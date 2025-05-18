#!/bin/bash

# Check if arguments are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 <number_of_files> <size_in_MB>"
    echo "Example: $0 100 10"
    exit 1
fi

# Assign arguments to variables
num_files=$1
size_mb=$2

# Validate input
if ! [[ "$num_files" =~ ^[0-9]+$ ]]; then
    echo "Error: Number of files must be a positive integer"
    exit 1
fi

if ! [[ "$size_mb" =~ ^[0-9]+$ ]]; then
    echo "Error: Size must be a positive integer (in MB)"
    exit 1
fi

echo "Generating $num_files files, each with $size_mb MB of random data..."

# Create directory if it doesn't exist
mkdir -p random_files
# Generate files
for i in $(seq 1 $num_files); do
    filename="random_files/random_file_$i.bin"
    echo -ne "Generating file $i/$num_files\r"
    dd if=/dev/urandom of="$filename" bs=1M count="$size_mb" status=none
done

echo -e "\nCompleted! Generated $num_files files of $size_mb MB each in the 'random_files' directory."
echo "Total data generated: $((num_files * size_mb)) MB"
