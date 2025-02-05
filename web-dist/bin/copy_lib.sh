#!/bin/bash

LIB_DIR="$HOME/target/web-server/lib"

find "$LIB_DIR" -type l | while read -r symlink; do

    origin_file=$(readlink "$symlink")

    if [[ -f "$origin_file" ]]; then
        echo "Replacing symlink: $symlink -> $origin_file"

        rm "$symlink"

        cp "$origin_file" "$symlink"
    else
        echo "Skipping $symlink (no valid origin file found)"
    fi
done
