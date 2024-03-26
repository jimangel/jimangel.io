#!/bin/bash

# Function to convert title to lowercase and replace spaces with hyphens
function format_title() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-'
}

# Check if the required arguments are provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 \"POST TITLE\" YYYY-MM-DD"
    exit 1
fi

title="$1"
date="$2"

# Format the title
formatted_title=$(format_title "$title")

# Create the folder structure
folder_path="content/posts/$date-$formatted_title"
mkdir -p "$folder_path"

# Create the index.md file inside the folder
touch "$folder_path/index.md"

echo "Folder and file created successfully:"
echo "$folder_path/index.md"