#!/bin/bash
set -e

TREE_FILE="tree.md"
RELEASES_DIR="releases"

# Start the tree
echo "# Releases Structure" > "$TREE_FILE"
echo "" >> "$TREE_FILE"
echo "\`\`\`" >> "$TREE_FILE"

# Find all directories that contain a release.json (these are repo roots)
find "$RELEASES_DIR" -type f -name "release.json" -printf "%h\n" | sort | while read -r repo_dir; do
    # Check if there is any asset file besides release.json
    asset_count=$(find "$repo_dir" -type f ! -name "release.json" | wc -l)
    if [ "$asset_count" -eq 0 ]; then
        continue  # skip empty or only-release.json folders
    fi

    # Extract owner and repo name from path (releases/owner/repo)
    owner=$(basename "$(dirname "$repo_dir")")
    repo_name=$(basename "$repo_dir")
    original_url="https://github.com/$owner/$repo_name"

    # Read tag from release.json
    tag=$(jq -r '.tag' "$repo_dir/release.json" 2>/dev/null || echo "unknown")

    # Print the repo line: ├── owner/repo [LINK][TAG]
    echo "├── $owner/$repo_name [$original_url] [$tag]" >> "$TREE_FILE"

    # List asset files (excluding release.json) with sizes and links
    find "$repo_dir" -type f ! -name "release.json" -printf "%f\n" | sort | while read -r asset; do
        asset_path="$repo_dir/$asset"
        # Get size in MB (rounded to 1 decimal) or KB if small
        size_bytes=$(stat -c%s "$asset_path" 2>/dev/null || stat -f%z "$asset_path" 2>/dev/null)
        if [ "$size_bytes" -lt 1048576 ]; then
            size_kb=$((size_bytes / 1024))
            size_display="${size_kb} KB"
        else
            size_mb=$(echo "scale=1; $size_bytes / 1048576" | bc)
            size_display="${size_mb} MB"
        fi

        # Raw GitHub URL (direct download) – works for public repos
        raw_url="https://raw.githubusercontent.com/$owner/$repo_name/main/$repo_dir/$asset"
        # But careful: the actual branch may not be main. We'll use the raw URL from GitHub's raw domain with full path.
        # Better: use GitHub's raw content API. But since the file is in the repo, we can use the raw.githubusercontent.com path.
        # The path should be: https://raw.githubusercontent.com/Ehs6n/ReleaseCollector/main/releases/owner/repo/asset
        # We'll construct based on the current repo's name (from env).
        current_repo="Ehs6n/ReleaseCollector"  # Replace with your repo's full name
        raw_link="https://raw.githubusercontent.com/$current_repo/main/$asset_path"

        echo "│   ├── $asset [Download]($raw_link) - <small>$size_display</small>" >> "$TREE_FILE"
    done
done

echo "\`\`\`" >> "$TREE_FILE"
