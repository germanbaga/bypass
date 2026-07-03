#!/bin/bash

# Colores para la interfaz
RED='\033[1;31m'
GRN='\033[1;32m'
BLU='\033[1;34m'
YEL='\033[1;33m'
NC='\033[0m'

error_exit() { echo -e "${RED}ERROR: $1${NC}" >&2; exit 1; }
warn() { echo -e "${YEL}ADVERTENCIA: $1${NC}"; }
success() { echo -e "${GRN}✓ $1${NC}"; }
info() { echo -e "${BLU}ℹ $1${NC}"; }

info "Iniciando análisis avanzado del sistema..."

SYSTEM_PATH=""
DATA_PATH=""

# 1. Detección robusta basada en la estructura real de macOS
for vol in /Volumes/*; do
    if [ -d "$vol" ] && [ "$vol" != "/Volumes/Recovery" ] && [ "$vol" != "/Volumes/VM" ]; then
        if [ -d "$vol/private/var/db/dslocal/nodes/Default" ]; then
            DATA_PATH="$vol"
        fi
        if [ -d "$vol/System/Library" ]; then
            SYSTEM_PATH="$vol"
        fi
    fi
done

if [ -z "$DATA_PATH" ] && [ -z "$SYSTEM_PATH" ]; then
    error_exit "No se detectó ninguna instalación válida de macOS. ¿Estás en el Terminal de Recuperación?"
fi

# Ajuste para sistemas con volumen único o contenedores unificados
if [ -n "$SYSTEM_PATH" ] && [ -z "$DATA_PATH" ]; then
    DATA_PATH="$SYSTEM_PATH"
elif [ -z "$SYSTEM_PATH" ] && [ -n "$DATA_PATH" ]; then
    SYSTEM_PATH="$DATA_PATH"
fi

dscl_path="$DATA_PATH/private/var/db/dslocal/nodes/Default"

# Localizar archivo hosts correctamente
hosts_file="$SYSTEM_PATH/private/etc/hosts"
if [ ! -f "$hosts_file" ] && [ -f "$SYSTEM_PATH/etc/hosts" ]; then
    hosts_file="$SYSTEM_PATH/etc/hosts"
fi

# 2. Filtro de seguridad mejorado
check_previous_run() {
    local ya_hecho=0
    if dscl -f "$dscl_path" localhost -read "/Local/Default/Users/Mac" &>/dev/null; then
        ya_hecho=$((ya_hecho + 1))
    fi
    if [ -f "$hosts_file" ] && grep -q "deviceenrollment.apple.com" "$hosts_file"; then
        ya_hecho=$((ya_hecho + 1))
    fi
    
    if [ $ya_hecho -gt 0 ]; then
        echo ""
        warn "El bypass ya parece estar aplicado o iniciado ($ya_hecho indicadores detectados)."
        info "Cancelando ejecución para proteger los datos existentes. Saliendo..."
        exit 0
    fi
}

# 3. Asignación dinámica de ID de usuario (UID)
find_available_uid() {
    local uid=501
    while [ $uid -lt 600 ]; do
        if ! dscl -f "$dscl_path" localhost -search /Local/Default/Users UniqueID $uid 2>/dev/null | grep -q "UniqueID"; then
            echo $uid
            return 0
        fi
        uid=$((uid + 1))
    done
    echo "501"
}

check_previous_run

echo ""
info "Sistema apto detectado. Aplicando parches en:"
for i in {3..1}; do
    echo -ne "${YEL}$i... ${NC}"
    sleep 1
done
echo -e "\n"

# Credenciales por defecto
realName="Mac"
username="Mac"
passw="1234"

info "Creando usuario administrador local ($username)..."
available_uid=$(find_available_uid)

# Creación de la estructura del usuario en la base de datos local de macOS
dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" 2>/dev/null
dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UserShell "/bin/zsh"
dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" RealName "$realName"
dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UniqueID "$available_uid"
dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" PrimaryGroupID "20"

user_home="$DATA_PATH/Users/$username"
mkdir -p "$user_home" 2>/dev/null

dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" NFSHomeDirectory "/Users/$username"
dscl -f "$dscl_path" localhost -passwd "/Local/Default/Users/$username" "$passw"
dscl -f "$dscl_path" localhost -append "/Local/Default/Groups/admin" GroupMembership "$username"

# 4. Bloqueo de servidores MDM ampliado (Incluye nuevos dominios de Apple)
info "Aplicando restricciones en el archivo hosts de destino..."
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

# 5. Limpieza profunda de ConfigurationProfiles y banderas de activación
info "Removiendo registros persistentes de gestión remota..."
config_path="$SYSTEM_PATH/private/var/db/ConfigurationProfiles"
if [ ! -d "$config_path" ]; then
    config_path="$SYSTEM_PATH/var/db/ConfigurationProfiles"
fi

mkdir -p "$config_path/Settings" 2>/dev/null

# Forzamos la simulación de que el asistente inicial ya terminó
touch "$DATA_PATH/private/var/db/.AppleSetupDone" 2>/dev/null

# Eliminamos cualquier registro previo que la Mac haya descargado de los servidores de Apple
rm -rf "$config_path/Settings/.cloudConfigHasActivationRecord" 2>/dev/null
rm -rf "$config_path/Settings/.cloudConfigRecordFound" 2>/dev/null
rm -rf "$config_path/.cloudConfigHasActivationRecord" 2>/dev/null
rm -rf "$config_path/.cloudConfigRecordFound" 2>/dev/null

# Engañamos al sistema indicando que no se encontraron perfiles MDM para este número de serie
touch "$config_path/Settings/.cloudConfigProfileInstalled" 2>/dev/null
touch "$config_path/Settings/.cloudConfigRecordNotFound" 2>/dev/null

echo ""
success "¡Bypass Optimizado Completado con Éxito!"
echo -e "${GRN}Acceso configurado -> Usuario: Mac | Clave: 1234${NC}"
echo ""

info "Reiniciando el equipo en 3 segundos..."
sleep 3
reboot
