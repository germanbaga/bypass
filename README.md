# V1
curl -L https://raw.githubusercontent.com/germanbaga/bypass/refs/heads/main/bypass.sh -o bypass-mdm.sh && chmod +x ./bypass-mdm.sh && ./bypass-mdm.sh
# V2
curl -L https://raw.githubusercontent.com/germanbaga/bypass/refs/heads/main/bypassv2.sh -o bypassv2.sh && chmod +x ./bypassv2.sh && ./bypassv2.sh
# Actualizacion v3
- Se cambió la redirección de dominios de 0.0.0.0 a 127.0.0.1 (localhost) para un mejor manejo de sockets en versiones recientes de macOS.
- Se amplió la lista de dominios bloqueados incluyendo albert.apple.com y axm-adm-mdm.apple.com para evitar la activación secundaria.
- Se mejoró la limpieza profunda de ConfigurationProfiles, eliminando registros de activación tanto en la ruta del sistema como en la de datos.
- Se añadió la exclusión explícita del volumen /Volumes/VM en el escaneo de discos para evitar falsos positivos en el modo Recovery.
- Se optimizó el temporizador de cuenta regresiva inicial a 3 segundos para acelerar el proceso.
  
curl -L https://raw.githubusercontent.com/germanbaga/bypass/refs/heads/main/bypassv3.sh -o bypassv3.sh && chmod +x ./bypassv3.sh && ./bypassv3.sh

cd /tmp && curl -L https://raw.githubusercontent.com/germanbaga/bypass/refs/heads/main/bypassv3.sh -o bypassv3.sh && chmod +x ./bypassv3.sh && ./bypassv3.sh
