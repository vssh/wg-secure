#! /bin/bash

SCRIPT_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ENV_PATH="${SCRIPT_PATH}/../.env"
source $ENV_PATH

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1;
fi

read -r -p "This will clear the interface and all client configs. Please confirm you want to continue by typing \"yes\": " response
response=${response,,} # tolower
echo    # (optional) move to a new line
if [[ $response != "yes" ]]
then
    echo "could not confirm, exiting"
    exit 0;
fi

systemctl stop "wg-quick@${INTERFACE_NAME}"
systemctl disable "wg-quick@${INTERFACE_NAME}"

CONFIG_PATH="${WG_PATH}/${INTERFACE_NAME}.conf"
PRIVATE_KEY_PATH="${WG_PATH}/${PRIVATE_KEY_FILE}"
PUBLIC_KEY_PATH="${WG_PATH}/${PUBLIC_KEY_FILE}"
POSTUP_PATH="${WG_PATH}/${POSTUP_FILE}"
POSTDOWN_PATH="${WG_PATH}/${POSTDOWN_FILE}"

rm -r "${WG_PATH}/${CONFIGS_DIR}"
rm $CONFIG_PATH
rm $PRIVATE_KEY_PATH
rm $PUBLIC_KEY_PATH
rm $POSTUP_PATH
rm $POSTDOWN_PATH
