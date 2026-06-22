#!/bin/bash

# Ensure an AppImage path was provided
if [ -z "$1" ]; then
    echo "Usage: $0 /path/to/application.AppImage"
    exit 1
fi

# Get the absolute path of the AppImage
appimage_path=$(readlink -f "$1")

if [ ! -f "$appimage_path" ]; then
    echo "Error: File not found at $appimage_path"
    exit 1
fi

# Ensure the AppImage is executable
chmod +x "$appimage_path"

# Create a temporary directory for extraction
temp_dir=$(mktemp -d)
cd "$temp_dir" || exit 1

echo "Extracting AppImage..."
# Extract the contents. >/dev/null keeps the terminal output clean.
"$appimage_path" --appimage-extract > /dev/null 2>&1

if [ ! -d "squashfs-root" ]; then
    echo "Error: Failed to extract AppImage. Ensure FUSE is installed or the file is valid."
    rm -rf "$temp_dir"
    exit 1
fi

# Find the primary .desktop file
desktop_file=$(find squashfs-root -maxdepth 1 -name "*.desktop" | head -n 1)

if [ -z "$desktop_file" ]; then
    echo "Error: No .desktop file found inside the AppImage."
    rm -rf "$temp_dir"
    exit 1
fi

# Extract the target icon name defined in the .desktop file
icon_name=$(grep -E "^Icon=" "$desktop_file" | cut -d'=' -f2 | tail -n 1)

# Ensure the local user directories exist
mkdir -p ~/.local/share/applications/
mkdir -p ~/.local/share/icons/

# Locate and install the icon
if [ -n "$icon_name" ]; then
    # Search for an icon matching the name, or fallback to the standard .DirIcon symlink
    ICON_FILE=$(find squashfs-root -maxdepth 1 \( -name "$icon_name.*" -o -name "$icon_name" \) | head -n 1)
    
    if [ -z "$ICON_FILE" ] && [ -f "squashfs-root/.DirIcon" ]; then
        ICON_FILE="squashfs-root/.DirIcon"
    fi

    if [ -n "$ICON_FILE" ]; then
        # Use cp -L to resolve and copy the actual file if it's a symlink
        cp -L "$ICON_FILE" ~/.local/share/icons/"$icon_name.png" 2>/dev/null || cp -L "$ICON_FILE" ~/.local/share/icons/
        echo "Installed icon: $icon_name"
    else
        echo "Warning: Icon '$icon_name' was specified but could not be found."
    fi
else
    echo "Warning: No Icon specified in the .desktop file."
fi

# Process and install the .desktop file
desktop_basename=$(basename "$desktop_file")
target_desktop=~/.local/share/applications/"$desktop_basename"

# Patch the Exec line to point to the absolute path of your AppImage
sed -E "s|^Exec=.*|Exec=\"$appimage_path\" %U|" "$desktop_file" > "$target_desktop"

# Ensure the newly created .desktop file is executable
chmod +x "$target_desktop"
echo "Installed .desktop file: $target_desktop"

# Clean up the temporary workspace
cd ~ || exit
rm -rf "$temp_dir"

# Refresh the system's application launcher database
if command -v update-desktop-database > /dev/null; then
    update-desktop-database ~/.local/share/applications/
fi

echo "Integration complete! The application should now appear in your application launcher."

