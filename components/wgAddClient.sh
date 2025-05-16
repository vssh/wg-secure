#! /bin/bash

SCRIPT_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ENV_PATH="${SCRIPT_PATH}/.env"
source $ENV_PATH
UTILS_PATH="${SCRIPT_PATH}/utils"
TEMPLATES_PATH="${SCRIPT_PATH}/templates"
UPDATE_POSTUP_SCRIPT="${SCRIPT_PATH}/wgUpdatePostupScript.sh"
NEW_LINE=$'\n'
CLIENTS_LINE_BEGIN="LastId="
ALLOWED_IPS_KEY="AllowedIPs = "
CIDR_ENDING="\/32"

UTIL_GET_IP_FROM_SUBNET="${UTILS_PATH}/getIpFromSubnet.sh"

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

CLIENT_NAME=$1

if [ -z "$CLIENT_NAME" ]; then
  echo "you must give a client name"
  exit 1;
fi

CLIENT_ACCESS=$2
if  [[ $CLIENT_ACCESS == "" ]]; then
  CLIENT_ACCESS=$CLIENT_ACCESS_DEFAULT
fi

CUSTOM_ACCESS_INDEX=-1
if [[ $CLIENT_ACCESS != $CLIENT_ACCESS_FULL && $CLIENT_ACCESS != $CLIENT_ACCESS_INTRANET && $CLIENT_ACCESS != $CLIENT_ACCESS_INTERNET  ]]; then
  customAccessIndexMin=0
  for ((num = $customAccessIndexMin; num < $CLIENT_ACCESS_CUSTOM_TYPES; num++))
  do
    if [[ $CLIENT_ACCESS == "$CLIENT_ACCESS_CUSTOM$num" ]]; then
      CUSTOM_ACCESS_INDEX=$num
    fi
  done

  if  [[ $CUSTOM_ACCESS_INDEX == -1 ]]; then
    customAccessIndexMax=$((CLIENT_ACCESS_CUSTOM_TYPES-1))
    if [[ $CLIENT_ACCESS_CUSTOM_TYPES < 1 ]]; then 
      echo "client access must be \"$CLIENT_ACCESS_FULL\", \"$CLIENT_ACCESS_INTRANET\" or \"$CLIENT_ACCESS_INTERNET\""
    elif [[ $customAccessIndexMax == 0 ]]; then
      echo "client access must be \"$CLIENT_ACCESS_FULL\", \"$CLIENT_ACCESS_INTRANET\", \"$CLIENT_ACCESS_INTERNET\"  or \"$CLIENT_ACCESS_CUSTOM$customAccessIndexMin\""
    else
      echo "client access must be \"$CLIENT_ACCESS_FULL\", \"$CLIENT_ACCESS_INTRANET\", \"$CLIENT_ACCESS_INTERNET\"  or \"$CLIENT_ACCESS_CUSTOM$customAccessIndexMin\" - \"$CLIENT_ACCESS_CUSTOM$customAccessIndexMax\""
    fi
    exit 1;
  fi
fi

CLIENT_DNS=$3
if [[ $CLIENT_DNS == "" ]]; then
  CLIENT_DNS=$CLIENT_DNS_DEFAULT
elif [[ $CLIENT_DNS != 0 && $CLIENT_DNS != 1 ]]; then
  echo "client dns must be 0 or 1"
  exit 1;
fi

function getIpsForCustomAccess() {
  local arr=""
  customAccessVar="CLIENT_CUSTOM_IP_PORT_$CUSTOM_ACCESS_INDEX"
  customAccessString=${!customAccessVar}
  local lines=(${customAccessString//;/ })
  for line in "${lines[@]}"; do
    local ips=(${line//#/ })
    arr="${arr}${ips[0]}, "
  done

  echo $(sed 's/, $//' <<< "$arr")
}

function getServerAllowedIps() {
  if [[ $CLIENT_ACCESS == $CLIENT_ACCESS_FULL || $CLIENT_ACCESS == $CLIENT_ACCESS_INTERNET ]]; then
    echo "0.0.0.0/0, ::0/0"
  elif [[ $CLIENT_ACCESS == $CLIENT_ACCESS_INTRANET ]]; then
    echo "${SERVER_LOCAL_CIDR}"
  elif [[ $CLIENT_ACCESS =~ ^$CLIENT_ACCESS_CUSTOM.* ]]; then
    echo $(getIpsForCustomAccess)
  fi
}

CLIENTS_FILE_PATH="${WG_PATH}/${CONFIGS_DIR}/${CLIENTS_FILE}"
function getClientNames() {
  while read client; do
    if [[ $client != \#* ]]; then
      echo $(awk -v FS=';' '{print $1}' <<< $client)
    fi
  done < $CLIENTS_FILE_PATH
}

function getClientIds() {
  while read client; do
    if [[ $client != \#* ]]; then
      echo $(awk -v FS=';' '{print $2}' <<< $client)
    fi
  done < $CLIENTS_FILE_PATH
}

while read name; do
  if [[ $CLIENT_NAME == $name ]]; then
    echo "this client name already exists"
    exit 1;
  fi
done < <(getClientNames)

CLIENT_CONFIG_PATH="${WG_PATH}/${CONFIGS_DIR}/${CLIENT_NAME}.conf"
if [ -f "$CLIENT_CONFIG_PATH" ]; then
  echo "this client already exists"
  exit 1;
fi

CLIENT_ID=0
for i in $(seq 2 254); do
  found=false
  while read id; do
  if [ $i -eq $((id)) ]; then
    found=true
    break
  fi
  done < <(getClientIds)

  if [ "$found" = false ]; then
    CLIENT_ID=$i
    break
  fi
done

if [ $CLIENT_ID -eq 0 ]; then
  echo "ip space if full, too many clients"
  exit 1;
fi

SERVER_PUBLIC_KEY="$(cat $WG_PATH/${PUBLIC_KEY_FILE})"

if [ -z "$SERVER_PUBLIC_KEY" ]; then
  echo "please run init script first"
  exit 1;
fi

CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo $CLIENT_PRIVATE_KEY | wg pubkey)
PRESHARED_KEY=$(wg genkey)
CLIENT_ADDRESS=$("${UTIL_GET_IP_FROM_SUBNET}" "${VPN_SUBNET}" " ${CLIENT_ID}")
CLIENT_ADDRESS="${CLIENT_ADDRESS}/32"
ENDPOINT="${DOMAIN}:${PUBLIC_PORT}"

CLIENT_TEMPLATE=$(cat "${TEMPLATES_PATH}/${CLIENT_TEMPLATE_FILE}")
if [[ $CLIENT_DNS == 0 ]]; then
  CLIENT_TEMPLATE=$(sed '/^DNS = /d' <<< "$CLIENT_TEMPLATE")
fi
CLIENT_TEMPLATE="${CLIENT_TEMPLATE/'[[PRESHARED_KEY]]'/${PRESHARED_KEY}}"
CLIENT_TEMPLATE="${CLIENT_TEMPLATE/'[[CLIENT_PRIVATE_KEY]]'/${CLIENT_PRIVATE_KEY}}"
CLIENT_TEMPLATE="${CLIENT_TEMPLATE/'[[SERVER_PUBLIC_KEY]]'/${SERVER_PUBLIC_KEY}}"
CLIENT_TEMPLATE="${CLIENT_TEMPLATE/'[[DNS]]'/${DNS}}"
CLIENT_TEMPLATE="${CLIENT_TEMPLATE/'[[CLIENT_ADDRESS]]'/${CLIENT_ADDRESS}}"
CLIENT_TEMPLATE="${CLIENT_TEMPLATE/'[[ENDPOINT]]'/${ENDPOINT}}"
CLIENT_TEMPLATE="${CLIENT_TEMPLATE/'[[SERVER_ALLOWED_IPS]]'/$(getServerAllowedIps)}"
# echo "$CLIENT_TEMPLATE"

SERVER_PEER_TEMPLATE=$(cat "${TEMPLATES_PATH}/${SERVER_PEER_TEMPLATE_FILE}")
SERVER_PEER_TEMPLATE="${SERVER_PEER_SEPARATOR_BEGIN}\n${SERVER_PEER_TEMPLATE}\n${SERVER_PEER_SEPARATOR_END}"
SERVER_PEER_TEMPLATE="${SERVER_PEER_TEMPLATE/'[[PRESHARED_KEY]]'/${PRESHARED_KEY}}"
SERVER_PEER_TEMPLATE="${SERVER_PEER_TEMPLATE/'[[CLIENT_NAME]]'/${CLIENT_NAME}}"
SERVER_PEER_TEMPLATE="${SERVER_PEER_TEMPLATE/'[[CLIENT_NAME]]'/${CLIENT_NAME}}"
SERVER_PEER_TEMPLATE="${SERVER_PEER_TEMPLATE/'[[CLIENT_PUBLIC_KEY]]'/${CLIENT_PUBLIC_KEY}}"
SERVER_PEER_TEMPLATE="${SERVER_PEER_TEMPLATE/'[[CLIENT_ALLOWED_IPS]]'/${CLIENT_ADDRESS}}"
# echo -e "$SERVER_PEER_TEMPLATE"

CLIENTS_LIST_ENTRY="${CLIENT_NAME};${CLIENT_ID};${CLIENT_ACCESS};${CLIENT_DNS}"

echo "$CLIENT_TEMPLATE" > "$CLIENT_CONFIG_PATH"
chmod go= "$CLIENT_CONFIG_PATH"
echo -e "$SERVER_PEER_TEMPLATE" >> "${WG_PATH}/${INTERFACE_NAME}.conf"
chmod go= "${WG_PATH}/${INTERFACE_NAME}.conf"
echo "$CLIENTS_LIST_ENTRY" >> "$CLIENTS_FILE_PATH"
chmod go= "$CLIENTS_FILE_PATH"

source $UPDATE_POSTUP_SCRIPT

systemctl restart "wg-quick@${INTERFACE_NAME}"
