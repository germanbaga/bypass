#!/bin/bash

# Define color codes
RED='\033[1;31m'
GRN='\033[1;32m'
BLU='\033[1;34m'
YEL='\033[1;33m'
NC='\033[0m'

error_exit() { echo -e "${RED}ERROR: $1${NC}" >&2; exit 1; }
warn() { echo -e "${YEL}WARNING: $1${NC}"; }
success() { echo -e "${GRN}✓ $1${NC}"; }
info() { echo -e "${BLU}ℹ $1${NC}"; }

# Find available UID (Recibe la ruta explícitamente)
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

# Renombrado de volumen si es necesario
if [ "$data_volume" != "Data" ]; then
	diskutil rename "$data_volume" "Data" 2>/dev/null && data_volume="Data"
fi

system_path="/Volumes/$system_volume"
data_path="/Volumes/$data_volume"
dscl_path="$data_path/private/var/db/dslocal/nodes/Default"

# Configuración Automática Mac / 1234
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

# --- MEJORAS DE LA V3 (BLOQUEO AMPLIADO) ---
info "Configuring hosts file..."
hosts_file="$system_path/etc/hosts"
dominios_mdm=(
    "deviceenrollment.apple.com"
    "mdmenrollment.apple.com"
    "ipprofiles.apple.com"
    "albert.apple.com"
    "axm-adm-mdm.apple.com"
)

for domain in "${dominios_mdm[@]}"; do
    if ! grep -q "$domain" "$hosts_file" 2>/dev/null; then
        echo "127.0.0.1 $domain" >> "$hosts_file"
    fi
done

# --- MEJORAS DE LA V3 (LIMPIEZA PROFUNDA DE CONFIGURATION PROFILES) ---
info "Cleaning up MDM activation records..."
config_path="$system_path/var/db/ConfigurationProfiles/Settings"
mkdir -p "$config_path" 2>/dev/null

# Forzar marcas de activación completada y bloqueo de registros viejos
touch "$data_path/private/var/db/.AppleSetupDone" 2>/dev/null
rm -rf "$config_path/.cloudConfigHasActivationRecord" 2>/dev/null
rm -rf "$config_path/.cloudConfigRecordFound" 2>/dev/null
rm -rf "$system_path/var/db/ConfigurationProfiles/.cloudConfigHasActivationRecord" 2>/dev/null
rm -rf "$system_path/var/db/ConfigurationProfiles/.cloudConfigRecordFound" 2>/dev/null

touch "$config_path/.cloudConfigProfileInstalled" 2>/dev/null
touch "$config_path/.cloudConfigRecordNotFound" 2>/dev/null

echo ""
success "MDM Bypass Process Finished!"
echo "Login credentials -> username: Mac | password: 1234"
echo "Check terminal lines above for any errors."
