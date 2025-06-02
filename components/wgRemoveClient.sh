#! /bin/bash

SCRIPT_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ENV_PATH="${SCRIPT_PATH}/../.env"
UTILS_PATH="${SCRIPT_PATH}/utils"
source $ENV_PATH
UPDATE_POSTUP_SCRIPT="${SCRIPT_PATH}/wgUpdatePostupScript.sh"
UTIL_REMOVE_LINES_FROM_FILE="${UTILS_PATH}/removeLinesFromFile.sh"

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

CLIENT_NAME=$1
if [ -z "$CLIENT_NAME" ]; then
  echo "please provide a client name" >> /dev/stderr
  exit 1;
fi

CLIENTS_FILE_PATH="${WG_PATH}/${CONFIGS_DIR}/${CLIENTS_FILE}"
CLIENT_LIST_POSITION=$(awk "/^${CLIENT_NAME};/{ print NR; exit }" "${CLIENTS_FILE_PATH}")

CLIENT_CONFIG_PATH="${WG_PATH}/${CONFIGS_DIR}/${CLIENT_NAME}.conf"
SERVER_CONFIG_PATH="${WG_PATH}/${INTERFACE_NAME}.conf"

if [ -f "$CLIENT_CONFIG_PATH" ]; then
  rm "${CLIENT_CONFIG_PATH}"
else
  echo "this client config file does not exist" >> /dev/stderr
fi

BEGIN_LINE="${SERVER_PEER_SEPARATOR_BEGIN/'[[CLIENT_NAME]]'/${CLIENT_NAME}}"
END_LINE="${SERVER_PEER_SEPARATOR_END/'[[CLIENT_NAME]]'/${CLIENT_NAME}}"

BEGIN_NUM=$(awk "/$BEGIN_LINE/{ print NR; exit }" "${SERVER_CONFIG_PATH}")
END_NUM=$(awk "/$END_LINE/{ print NR; exit }" "${SERVER_CONFIG_PATH}")

if [[ $((BEGIN_NUM)) -lt 1 || $((END_NUM)) -lt 1 ]]; then
  echo "peer config not found" >> /dev/stderr
else
  $UTIL_REMOVE_LINES_FROM_FILE $SERVER_CONFIG_PATH $BEGIN_NUM $END_NUM
fi

if [[ $((CLIENT_LIST_POSITION)) -lt 1 ]]; then
  echo "client list entry not found" >> /dev/stderr
else
  $UTIL_REMOVE_LINES_FROM_FILE $CLIENTS_FILE_PATH $CLIENT_LIST_POSITION
fi

echo "client \"$CLIENT_NAME\" removed from configuration"

source $UPDATE_POSTUP_SCRIPT

systemctl restart "wg-quick@${INTERFACE_NAME}"
