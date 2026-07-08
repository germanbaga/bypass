#!/bin/bash

RED='\033[1;31m'
GRN='\033[1;32m'
BLU='\033[1;34m'
YEL='\033[1;33m'
NC='\033[0m'

error_exit() { echo -e "${RED}ERROR: $1${NC}" >&2; exit 1; }
warn() { echo -e "${YEL}WARNING: $1${NC}"; }
success() { echo -e "${GRN}✓ $1${NC}"; }
info() { echo -e "${BLU}ℹ $1${NC}"; }

find_available_uid() {
	local dscl_path="$1"
	local uid=501
	while [ $uid -lt 600 ]; do
		if ! dscl -f "$dscl_path" localhost -search /Local/Default/Users UniqueID $uid 2>/dev/null | grep -q "UniqueID"; then
			echo $uid
			return 0
		fi
		uid=$((uid + 1))
	done
	echo "501"
	return 1
}

detect_volumes() {
	local system_vol=""
	local data_vol=""
	info "Detecting system volumes..." >&2
	for vol in /Volumes/*; do
		if [ -d "$vol" ] && [ "$vol" != "/Volumes/Recovery" ] && [ "$vol" != "/Volumes/VM" ]; then
			vol_name="${vol##*/}"
			if [[ ! "$vol_name" =~ "Data"$ ]] && [ -d "$vol/System" ]; then
				system_vol="$vol_name"
				break
			fi
		fi
	done
	if [ -z "$system_vol" ]; then
		for vol in /Volumes/*; do
			if [ -d "$vol/System" ]; then
				system_vol="${vol##*/}"
				break
			fi
		done
	fi
	if [ -d "/Volumes/Data" ]; then
		data_vol="Data"
	elif [ -n "$system_vol" ] && [ -d "/Volumes/$system_vol - Data" ]; then
		data_vol="$system_vol - Data"
	else
		for vol in /Volumes/*Data; do
			if [ -d "$vol" ]; then
				data_vol="${vol##*/}"
				break
			fi
		done
	fi
	if [ -z "$system_vol" ] || [ -z "$data_vol" ]; then
		error_exit "Could not detect volumes. Ensure your disk is unencrypted and mounted."
	fi
	echo "$system_vol|$data_vol"
}

volume_info=$(detect_volumes)
system_volume=$(echo "$volume_info" | cut -d'|' -f1)
data_volume=$(echo "$volume_info" | cut -d'|' -f2)

echo ""
success "System Volume: $system_volume"
success "Data Volume: $data_volume"
echo ""

if [ "$data_volume" != "Data" ]; then
	diskutil rename "$data_volume" "Data" 2>/dev/null && data_volume="Data"
fi

system_path="/Volumes/$system_volume"
data_path="/Volumes/$data_volume"
dscl_path="$data_path/private/var/db/dslocal/nodes/Default"

realName="Mac"
username="Mac"
passw="1234"

info "Creating User: $username"
available_uid=$(find_available_uid "$dscl_path")

dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" 2>/dev/null
dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UserShell "/bin/zsh"
dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" RealName "$realName"
dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UniqueID "$available_uid"
dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" PrimaryGroupID "20"

user_home="$data_path/Users/$username"
mkdir -p "$user_home" 2>/dev/null
dscl -f "$dscl_path
