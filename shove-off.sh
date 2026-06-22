#!/usr/bin/env bash

# Install and basic configuration of packages on a fresh install of
# Ubuntu or Debian.
#
# This is meant to get the basics that may not be included on a default
# installation.
#
# AppImages will use an external script for extracting a Desktop and icon
# file for adding to the application launcher.

##########################################################################
# Script Configuration
##########################################################################

# Required packages for this script.
apt_packages_required=(
	apt-transport-https
	ca-certificates
	curl
	git
	jq
	wget
);

# Packages to install via apt
#
# Some packages need third party repos to be added prior to running apt
# install. These are noted below.
apt_packages=(
	dbeaver-ce # Third party repo
	dnsutils
	libnss3-tools # For certutil
	openssl
	onedrive
	php-cli
	php-xmlwriter
	poppler-utils
	sublime-text # third party repo
	sublime-merge # third party repo
	whois
);

# Choose external apps to download and install as an AppImage or other
# more manual way. A value of 1 will flag that the app should be
# downloaded and installed.
heidisql=1
mapillary_desktop=0
nvm=1
svgo=1
teams_for_linux=1

# Personal opt and bin paths. These will be where apps will be installed
# for the current user only. Do NOT include a trailing slash.
personal_opt="$HOME/.local/opt"
personal_bin="$HOME/.local/bin"

# A git directory for repos to be cloned to.
git_repo_dir="$HOME/gitrepos"

# Setup vars for Bash colors
green='\033[0;32m'
red='\033[0;31m'
reset='\033[0m'


##########################################################################
# Recommend importing or creating an SSH key
##########################################################################

echo
echo "You should setup your SSH key for cloning git repos. Do this before continuing!"

answer=""
while [ -z "$answer" ]; do
  read -r -p "Are you ready to continue? (Y/N): " answer
  case "${answer,,}" in
    y|yes)
      echo "Yes was selected. Here we go."
      ;;
    n|no)
      echo "No was selected. Exiting."
      exit 1
      ;;
    *)
      echo "Please enter Y or N."
      answer=""
      ;;
  esac
done


##########################################################################
# Install packages required for this script.
##########################################################################

sudo apt -y install "${apt_packages_required[@]}"


##########################################################################
# Setup temp files
##########################################################################

# Create a file in /tmp/ for working with files.
tmp_dir=$(mktemp -d);


##########################################################################
# Make directories since they likely do not exist yet.
##########################################################################

mkdir -p "${personal_opt}"
mkdir -p "${personal_bin}"
mkdir -p "${git_repo_dir}"


##########################################################################
# Check which user is running this script and their privs
##########################################################################

# Get the current user running this script.
user_to_check="${1:-$(whoami)}"

# Check if the script is being run as root
if [ "$user_to_check" = "root" ]; then
	echo -e "${red}Current user is $user_to_check. Re-run this script as your standard user. Exiting.${reset}";
	exit 1
fi

# Check if the current user is a sudoer. Also inits credential helper to
# prevent prompting for password to sudo later in the script.
echo "This script requires you to be a sudoer. You may be asked for your password."
if sudo -v; then

  echo -e "${green}You are a sudoer${reset}"

else

  echo -e "${red}Unable to elevate privs with sudo. Exiting.${reset}";
  exit 1

fi


##########################################################################
# Teams for Linux (unofficial) AppImage
#
# In the past, the deb version did not pick up audio inputs.
##########################################################################

if [ -z $teams_for_linux ]; then

	echo "Teams for Linux is configured to NOT install. Skipping.";

else

	# Get the latest download URL of the AppImage that is NOT for arm from the GH API.
	url=$(curl -s https://api.github.com/repos/IsmaelMartinez/teams-for-linux/releases/latest | jq -r '.assets[] | select(.name | endswith(".AppImage") and (contains("arm") | not)) | .browser_download_url')

	# Extract the filename from the URL.
	filename="${url##*/}"

	# Extract the app name from the filename.
	appname="${filename%.AppImage}" # Remove .AppImage
	appname="${appname%-[0-9]*}" # Remove version.

	# Set the installation path.
	install_dir="$personal_opt/${appname}"

	# Make the path where Teams for Linux will be installed.
	mkdir -p "$install_dir"

	echo "Downloading Teams for Linux from $url"

	# Get the redirected URL of the current version.
	curl -L "${url}" -o "${install_dir}/${filename}"
	chmod +x "${install_dir}/${filename}"

	# Create a symlink to the personal bin dir.
	ln -sf "${install_dir}/${filename}" "${personal_bin}/${appname}"

	# Make sure the tmp dir exists.
	if [ ! -d "${tmp_dir}" ]; then
		echo "${tmp_dir} does not exist. Something is wrong! Exiting."
		exit 1
	fi

	# Extract the AppImage in the tmp dir.
	cd "${tmp_dir}"
	"${install_dir}/${filename}" --appimage-extract

	# Move the extracted icon to the installation dir.
	cp "${tmp_dir}/squashfs-root/.DirIcon" "${install_dir}/${appname}.png"

	# Update the path to the icon in the .desktop file.
	sed -i "s|^Icon=.*|Icon=${install_dir}/${appname}.png|" "squashfs-root/${appname}.desktop"

	# Update Exec with the launcher script which was symlinked to earlier.
	sed -i "s|^Exec=.*|Exec=${personal_bin}/${appname} --no-sandbox|" "squashfs-root/${appname}.desktop"

	# Copy the .desktop file to the install dir and symlink for the Window Manager to find it.
	chmod +x "${tmp_dir}/squashfs-root/${appname}.desktop"
	cp "${tmp_dir}/squashfs-root/${appname}.desktop" "${install_dir}/"
	ln -sf "${install_dir}/${appname}.desktop" "${HOME}/.local/share/applications/${appname}.desktop"

	# Cleanup
	rm -rf "${tmp_dir}/squashfs-root"

fi


##########################################################################
# Mapillary Desktop Uploader
##########################################################################

if [ -z $mapillary_desktop ]; then

	echo "Mapillary Desktop is configured to NOT install. Skipping.";

else

	# Get the end URL that is redirected to for the latest version.
	url=$(curl -s -I -o /dev/null -w "%{url_effective}\n" -L "https://tools.mapillary.com/uploader/download/linux");

	# Remove everything after ? in the URL.
	path_only="${url%%\?*}"

	# Extract the filename from the URL.
	filename="${path_only##*/}"

	# Extract the app name from the filename.
	appname="${filename%.AppImage}" # Remove .AppImage
	appname="${appname%-[0-9]*}" # Remove version.

	# Set the installation path.
	install_dir="$personal_opt/${appname}"

	# Make the path where Mapillary will be installed.
	mkdir -p "$install_dir"

	# Download the latest AppImage
	curl -L "${url}" -o "${install_dir}/${filename}"
	chmod +x "${install_dir}/${filename}"

	# Create a symlink to the personal bin dir.
	ln -sf "${install_dir}/${filename}" "${personal_bin}/${appname}"

	# Make sure the tmp dir exists.
	if [ ! -d "${tmp_dir}" ]; then
		echo "${tmp_dir} does not exist. Something is wrong! Exiting."
		exit 1
	fi

	# Extract the AppImage in the tmp dir.
	cd "${tmp_dir}"
	"${install_dir}/${filename}" --appimage-extract

	# Move the extracted icon to the installation dir.
	cp "${tmp_dir}/squashfs-root/.DirIcon" "${install_dir}/${appname}.png"

	# Move the desktop file since Mapillary doesn't give it the same name as the AppImage.
	mv "${tmp_dir}/squashfs-root/mapillary-desktop-uploader.desktop" "${tmp_dir}/squashfs-root/${appname}.desktop"

	# Update the path to the icon in the .desktop file.
	sed -i "s|^Icon=.*|Icon=${install_dir}/${appname}.png|" "squashfs-root/${appname}.desktop"

	# Update Exec with the launcher script which was symlinked to earlier.
	sed -i "s|^Exec=.*|Exec=${personal_bin}/${appname} --no-sandbox|" "squashfs-root/${appname}.desktop"

	# Copy the .desktop file to the install dir and symlink for the Window Manager to find it.
	chmod +x "${tmp_dir}/squashfs-root/${appname}.desktop"
	cp "${tmp_dir}/squashfs-root/${appname}.desktop" "${install_dir}/"
	ln -sf "${install_dir}/${appname}.desktop" "${HOME}/.local/share/applications/${appname}.desktop"

	# Cleanup
	rm -rf "${tmp_dir}/squashfs-root"

fi


##########################################################################
# nvm (Node Version Manager)
##########################################################################

if [ -z $nvm ]; then

	echo "nvm is configured to NOT install. Skipping.";

else

	# Get the latest version/tag from GH API.
	latest_version=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r '.tag_name')

	# Run the install script for the latest version.
	curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${latest_version}/install.sh" | bash

	# Install the current LTS version of node.
	nvm install --lts

fi


##########################################################################
# SVGO
##########################################################################

if [ -z $svgo ]; then

	echo "svgo is configured to NOT install. Skipping.";

else

	# Try installing via apt (Debian) but try snap (Ubuntu) if not found.
	sudo apt install svgo || sudo snap install svgo

fi


##########################################################################
# DBeaver SQL Client
##########################################################################

dbeaver_in_package_list=false

# Loop over the package list.
for pkg in "${apt_packages[@]}"; do

    if [[ "$pkg" == "dbeaver-ce" ]]; then

        dbeaver_in_package_list=true
        break

    fi

done

# Only add the apt repo for DBeaver if it is in the list of packages to
# install.
if [ "$dbeaver_in_package_list" = true ]; then

	# Get the GPG key for the official repo.
	wget -q -O - https://dbeaver.io/debs/dbeaver.gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/dbeaver.gpg.key

	echo "deb [signed-by=/usr/share/keyrings/dbeaver.gpg.key] https://dbeaver.io/debs/dbeaver-ce /" | sudo tee /etc/apt/sources.list.d/dbeaver.list

fi


##########################################################################
# HeidiSQL
#
# libqt6pas6 is required. It should be available on versions of Ubuntu 26
# and Debian 13, but needs to be manually installed on earlier versions.
#
# If there are issues with dark theme, then try the QT6(?) version of the
# AppImage or whatever option there is. The deb version didn't work in the
# past but that was early in development of the Linux version.
##########################################################################

if [ -z $heidisql ]; then

	echo "HeidiSQL is configured to NOT install. Skipping.";

else

	# Get the latest download URL of amd64.deb version from the GH API.
	url=$(curl -s https://api.github.com/repos/HeidiSQL/HeidiSQL/releases/latest | jq -r '.assets[] | select(.name | endswith("amd64.deb")) | .browser_download_url')

	# Extract the filename from the URL.
	filename=${url##*/}

	echo "Downloading HeidiSQL from $url"

	# Get the redirected URL of the current version.
	curl -L "${url}" -o "${install_dir}/${filename}"
	# wget -o "${tmp_dir}/${filename}" "$url"

	# Install the package and cleanup/remove it once complete.
	sudo apt -y install "${tmp_dir}/${filename}" && rm "${tmp_dir}/${filename}"

fi


##########################################################################
# Sublime Text 4
#
# Add apt repository. Will need to add configs from OneDrive.
##########################################################################

sublime_in_package_list=false

# Loop over the package list.
for pkg in "${apt_packages[@]}"; do

    if [[ "$pkg" == "sublime-text" || "$pkg" == "sublime-merge"  ]]; then

        sublime_in_package_list=true
        break

    fi

done

# Only add the apt repo for Sublime Text and Sublime Merge if they are in
# the list of packages to install.
if [ "$sublime_in_package_list" = true ]; then

	echo "Adding Sublime Text 4 GPG key for the apt repo"
	wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | sudo tee /etc/apt/keyrings/sublimehq-pub.asc > /dev/null

	echo "Adding Sublime Text 4 apt repo"
	echo -e 'Types: deb\nURIs: https://download.sublimetext.com/\nSuites: apt/stable/\nSigned-By: /etc/apt/keyrings/sublimehq-pub.asc' | sudo tee /etc/apt/sources.list.d/sublime-text.sources

fi


##########################################################################
# Clone git repos
##########################################################################

# WPCLI Scripts
git clone git@github.com:JasonRaveling/wpcli-scripts.git "${git_repo_dir}/wpcli-scripts"

# Watch Sync
git clone git@github.com:JasonRaveling/watch-sync.git "${git_repo_dir}/watchsync"


##########################################################################
# Install apt packages
#
# Ensure that this is run after all third party apt repos have been added.
##########################################################################

echo "Ensure latest packages are installed. Doing apt upgrade..."
sudo apt update && sudo apt -y upgrade

echo "Installing apt packages...";
sudo apt -y install "${apt_packages[@]}";


##########################################################################
# Final cleanup
##########################################################################

echo 'Cleaning up temp files...'
cd && rm -rf "${tmp_dir}"
exit 0;

