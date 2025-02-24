#! /bin/bash

SCRIPT_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ENV_PATH="${SCRIPT_PATH}/.env"
source $ENV_PATH

CLIENT_NAME=$1
AS_QR=$2

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

if [ -z "$CLIENT_NAME" ]; then
  echo "please provide a client name"
  exit 1;
fi


CLIENT_CONFIG_PATH="${WG_PATH}/${CONFIGS_DIR}/${CLIENT_NAME}.conf"

if [ ! -f "$CLIENT_CONFIG_PATH" ]; then
  echo "this client config file does not exist"
  exit 1;
fi

if [[ "$AS_QR" == "1" || "$AS_QR" == "true" ]]; then
  qrencode -t ansiutf8 "$(cat ${CLIENT_CONFIG_PATH})"
  exit 0;
fi

cat ${CLIENT_CONFIG_PATH}
