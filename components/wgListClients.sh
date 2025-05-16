#! /bin/bash

SCRIPT_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ENV_PATH="${SCRIPT_PATH}/.env"
UTILS_PATH="${SCRIPT_PATH}/utils"
source $ENV_PATH

UTIL_GET_IP_FROM_SUBNET="${UTILS_PATH}/getIpFromSubnet.sh"

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

IP_PREFIX=$("$UTIL_GET_IP_FROM_SUBNET" "$VPN_SUBNET")
CLIENTS_FILE_PATH="${WG_PATH}/${CONFIGS_DIR}/${CLIENTS_FILE}"
while read line; do
  id=$(awk -F ';' '{print $2}' <<< "$line")
  echo -e $(sed "s/client_id/client_ip/; s/;1$/;true/; s/;0$/;false/;  s/;${id};/;${IP_PREFIX}${id};/; s/;/ -\t- /g; s/#//" <(echo $line))
done < $CLIENTS_FILE_PATH
