#! /bin/bash

SCRIPT_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ENV_PATH="${SCRIPT_PATH}/../.env"
UTILS_PATH="${SCRIPT_PATH}/utils"
TEMPLATES_PATH="${SCRIPT_PATH}/templates"
UPDATE_POSTUP_SCRIPT="${SCRIPT_PATH}/wgUpdatePostupScript.sh"
source $ENV_PATH
NEW_LINE=$'\n'

UTIL_GET_IP_FROM_SUBNET="${UTILS_PATH}/getIpFromSubnet.sh"

if [ ! -f $ENV_PATH ]; then
  echo "please create the env file" >> /dev/stderr
  exit 1;
fi

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1;
fi

if [ -z $INTERFACE_NAME ]; then
  echo "please provide interface name" >> /dev/stderr
  exit 1;
fi

CONFIG_PATH="${WG_PATH}/${INTERFACE_NAME}.conf"
PRIVATE_KEY_PATH="${WG_PATH}/${PRIVATE_KEY_FILE}"
PUBLIC_KEY_PATH="${WG_PATH}/${PUBLIC_KEY_FILE}"
POSTUP_PATH="${WG_PATH}/${POSTUP_FILE}"
POSTDOWN_PATH="${WG_PATH}/${POSTDOWN_FILE}"

if [ -f $CONFIG_PATH ]; then
  echo "config already exists" >> /dev/stderr
  exit 1;
fi

if [ -f $PRIVATE_KEY_PATH ]; then
  echo "private key already exists" >> /dev/stderr
  exit 1;
fi

if [ -f $PUBLIC_KEY_PATH ]; then
  echo "public key already exists" >> /dev/stderr
  exit 1;
fi

if [ -f $POSTUP_PATH ]; then
  echo "postup script already exists" >> /dev/stderr
  exit 1;
fi

if [ -f $POSTDOWN_PATH ]; then
  echo "postdown script already exists" >> /dev/stderr
  exit 1;
fi

customAccessIndexMin=0
if [[ $CLIENT_ACCESS_DEFAULT != $CLIENT_ACCESS_FULL && $CLIENT_ACCESS_DEFAULT != $CLIENT_ACCESS_INTRANET && $CLIENT_ACCESS_DEFAULT != $CLIENT_ACCESS_INTERNET  ]]; then
  customeAccessValid=0
  for ((num = $customAccessIndexMin; num < $CLIENT_ACCESS_CUSTOM_TYPES; num++))
  do
    if [[ $CLIENT_ACCESS_DEFAULT == "$CLIENT_ACCESS_CUSTOM$num" ]]; then
      $customeAccessValid=1
    fi
  done

  if  [[ $customeAccessValid == 0 ]]; then
    customAccessIndexMax=$((CLIENT_ACCESS_CUSTOM_TYPES-1))
    echo "CLIENT_ACCESS_DEFAULT must be \"$CLIENT_ACCESS_FULL\", \"$CLIENT_ACCESS_INTRANET\", \"$CLIENT_ACCESS_INTERNET\"  or \"$CLIENT_ACCESS_CUSTOM$customAccessIndexMin\" - \"$CLIENT_ACCESS_CUSTOM$customAccessIndexMax\"" >> /dev/stderr
    exit 1;
  fi
fi

for ((num = $customAccessIndexMin; num < $CLIENT_ACCESS_CUSTOM_TYPES; num++))
do
  customAccessVar="CLIENT_CUSTOM_IP_PORT_$num"
  customAccessString=${!customAccessVar}
  if [[ -z $customAccessString ]]; then
    echo "$customAccessVar must be defined in env file" >> /dev/stderr
    exit 1;
  fi
done

SERVER_PRIVATE_KEY=$(wg genkey)
SERVER_PUBLIC_KEY=$(echo $SERVER_PRIVATE_KEY | wg pubkey)
SERVER_ADDRESS=$("$UTIL_GET_IP_FROM_SUBNET" "$VPN_SUBNET" "1")
SERVER_ADDRESS="${SERVER_ADDRESS}/32"

SERVER_INTERFACE=$(cat "${TEMPLATES_PATH}/${SERVER_INTERFACE_TEMPLATE_FILE}")
SERVER_INTERFACE="${SERVER_INTERFACE/'[[SERVER_PRIVATE_KEY]]'/${SERVER_PRIVATE_KEY}}"
SERVER_INTERFACE="${SERVER_INTERFACE/'[[SERVER_PORT]]'/${SERVER_PORT}}"
SERVER_INTERFACE="${SERVER_INTERFACE/'[[SERVER_ADDRESS]]'/${SERVER_ADDRESS}}"
SERVER_INTERFACE="${SERVER_INTERFACE/'[[POSTUP_PATH]]'/${POSTUP_PATH}}"
SERVER_INTERFACE="${SERVER_INTERFACE/'[[POSTDOWN_PATH]]'/${POSTDOWN_PATH}}"
# echo "$SERVER_INTERFACE"

WG_LAN_CIDR=$("$UTIL_GET_IP_FROM_SUBNET" "$VPN_SUBNET" "0")
WG_LAN_CIDR="${WG_LAN_CIDR}/24"

POSTUP_CONTENT=$(cat "${TEMPLATES_PATH}/${POSTUP_TEMPLATE_FILE}")
POSTUP_CONTENT="${POSTUP_CONTENT/'[[INTERFACE_NAME]]'/${INTERFACE_NAME}}"
POSTUP_CONTENT="${POSTUP_CONTENT/'[[WIREGUARD_LAN]]'/${WG_LAN_CIDR}}"
POSTUP_CONTENT="${POSTUP_CONTENT/'[[NETWORK_INTERFACE]]'/${NETWORK_INTERFACE}}"
# echo "$POSTUP_CONTENT"

POSTDOWN_CONTENT=$(cat "${TEMPLATES_PATH}/${POSTDOWN_TEMPLATE_FILE}")
POSTDOWN_CONTENT="${POSTDOWN_CONTENT/'[[INTERFACE_NAME]]'/${INTERFACE_NAME}}"
POSTDOWN_CONTENT="${POSTDOWN_CONTENT/'[[WIREGUARD_LAN]]'/${WG_LAN_CIDR}}"
POSTDOWN_CONTENT="${POSTDOWN_CONTENT/'[[NETWORK_INTERFACE]]'/${NETWORK_INTERFACE}}"
# echo "$POSTDOWN_CONTENT"

CLIENTS_CONTENT="# client_name;client_id;client_access;client_dns_passthrough"

mkdir -p "${WG_PATH}/${CONFIGS_DIR}"
echo "CLIENTS_CONTENT" > "${WG_PATH}/${CONFIGS_DIR}/${CLIENTS_FILE}"
chmod -R go= "${WG_PATH}/${CONFIGS_DIR}"
echo "$SERVER_PRIVATE_KEY" > "${WG_PATH}/${PRIVATE_KEY_FILE}"
chmod go= "${WG_PATH}/${PRIVATE_KEY_FILE}"
echo "$SERVER_PUBLIC_KEY" > "${WG_PATH}/${PUBLIC_KEY_FILE}"
echo "$POSTUP_CONTENT" > "${WG_PATH}/${POSTUP_FILE}"
chmod 744 "${WG_PATH}/${POSTUP_FILE}"
echo "$POSTDOWN_CONTENT" > "${WG_PATH}/${POSTDOWN_FILE}"
chmod 744 "${WG_PATH}/${POSTDOWN_FILE}"
echo "$SERVER_INTERFACE" > "${WG_PATH}/${INTERFACE_NAME}.conf"
chmod go= "${WG_PATH}/${INTERFACE_NAME}.conf"

source $UPDATE_POSTUP_SCRIPT

systemctl enable "wg-quick@${INTERFACE_NAME}"
systemctl start "wg-quick@${INTERFACE_NAME}"
