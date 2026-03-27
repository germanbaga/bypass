#!/bin/bash

# Define color codes
RED='\033[1;31m'
GRN='\033[1;32m'
BLU='\033[1;34m'
YEL='\033[1;33m'
PUR='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

# Error handling function
error_exit() {
	echo -e "${RED}ERROR: $1${NC}" >&2
	exit 1
}

# Warning function
warn() {
	echo -e "${YEL}WARNING: $1${NC}"
}

# Success function
success() {
	echo -e "${GRN}✓ $1${NC}"
}

# Info function
info() {
	echo -e "${BLU}ℹ $1${NC}"
}

# Validation function for username
validate_username() {
	local username="$1"
	if [ -z "$username" ]; then
		echo "Username cannot be empty"
		return 1
	fi
	if [ ${#username} -gt 31 ]; then
		echo "Username too long (max 31 characters)"
		return 1
	fi
	if ! [[ "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
		echo "Username can only contain letters, numbers, underscore, and hyphen"
		return 1
	fi
	if ! [[ "$username" =~ ^[a-zA-Z_] ]]; then
		echo "Username must start with a letter or underscore"
		return 1
	fi
	return 0
}

# Validation function for password
validate_password() {
	local password="$1"
	if [ -z "$password" ]; then
		echo "Password cannot be empty"
		return 1
	fi
	return 0
}

# Check if user already exists
check_user_exists() {
	local dscl_path="$1"
	local username="$2"
	if dscl -f "$dscl_path" localhost -read "/Local/Default/Users/$username" 2>/dev/null; then
		return 0
	else
		return 1
	fi
}

# Find available UID
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

# Function to detect system volumes
detect_volumes() {
	local system_vol=""
	local data_vol=""
	info "Detecting system volumes..." >&2
	for vol in /Volumes/*; do
		if [ -d "$vol" ]; then
			vol_name=$(basename "$vol")
			if [[ ! "$vol_name" =~ "Data"$ ]] && [[ ! "$vol_name" =~ "Recovery" ]] && [ -d "$vol/System" ]; then
				system_vol="$vol_name"
				break
			fi
		fi
	done
	if [ -z "$system_vol" ]; then
		for vol in /Volumes/*; do
			if [ -d "$vol/System" ]; then
				system_vol=$(basename "$vol")
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
				data_vol=$(basename "$vol")
				break
			fi
		done
	fi
	if [ -z "$system_vol" ] || [ -z "$data_vol" ]; then
		error_exit "Could not detect volumes. Ensure you are in Recovery mode."
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

PS3='Please enter your choice: '
options=("Bypass MDM" "Reboot & Exit")
select opt in "${options[@]}"; do
	case $opt in
	"Bypass MDM")
		if [ "$data_volume" != "Data" ]; then
			diskutil rename "$data_volume" "Data" 2>/dev/null && data_volume="Data"
		fi

		system_path="/Volumes/$system_volume"
		data_path="/Volumes/$data_volume"
		dscl_path="$data_path/private/var/db/dslocal/nodes/Default"

		# Configuracion Automática Mac / 1234
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
		dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" NFSHomeDirectory "/Users/$username"
		dscl -f "$dscl_path" localhost -passwd "/Local/Default/Users/$username" "$passw"
		dscl -f "$dscl_path" localhost -append "/Local/Default/Groups/admin" GroupMembership "$username"

		# Block MDM
		hosts_file="$system_path/etc/hosts"
		echo "0.0.0.0 deviceenrollment.apple.com" >>"$hosts_file"
		echo "0.0.0.0 mdmenrollment.apple.com" >>"$hosts_file"
		echo "0.0.0.0 ipprofiles.apple.com" >>"$hosts_file"

		# Cleanup & Bypass Markers
		config_path="$system_path/var/db/ConfigurationProfiles/Settings"
		mkdir -p "$config_path" 2>/dev/null
		touch "$data_path/private/var/db/.AppleSetupDone" 2>/dev/null
		rm -rf "$config_path/.cloudConfigHasActivationRecord" 2>/dev/null
		rm -rf "$config_path/.cloudConfigRecordFound" 2>/dev/null
		touch "$config_path/.cloudConfigProfileInstalled" 2>/dev/null
		touch "$config_path/.cloudConfigRecordNotFound" 2>/dev/null

		success "MDM Bypass Completed!"
		echo "Login with username: Mac and password: 1234"
		break
		;;
	"Reboot & Exit")
		reboot
		break
		;;
	*)
		echo "Invalid option"
		;;
	esac
done