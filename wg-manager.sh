#! /bin/bash

SCRIPT_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
COMPONENT_PATH="$SCRIPT_PATH/components"
LIST_PATH="$COMPONENT_PATH/wgListClients.sh"
SHOW_PATH="$COMPONENT_PATH/wgClientShow.sh"
INIT_PATH="$COMPONENT_PATH/wgInit.sh"
ADD_PATH="$COMPONENT_PATH/wgAddClient.sh"
REMOVE_PATH="$COMPONENT_PATH/wgRemoveClient.sh"
UPDATE_POSTUP_PATH="$COMPONENT_PATH/wgUpdatePostupScript.sh"

help()
{
  scriptName="wg-manager"
  # Display Help
  echo "Usage instructions:"
  echo
  echo "For first time users, create the env file first, then initialize with:"
  echo "$scriptName init"
  echo
  echo "To list existing clients:"
  echo "$scriptName list"
  echo
  echo "To show a particular clint's config:"
  echo "$scriptName show [-q|--qr-code] clientName"
  echo "clientName can be checked with the list command"
  echo "options:"
  echo "-q|--qr-code 	display the config as a qr code"
  echo
  echo "To add a new client:"
  echo "$scriptName add [-a|--access accessType] [-d|--dns 0|1] clientName"
  echo "Add a new client with the name clientName"
  echo "options:"
  echo "-a|--access 	give the access type of the new client (should be one of the types defined in env file)"
  echo "		if access type is not defined, default access type from env file is used"
  echo "-d|--dns 	define if the client should forward the dns queries (0 for false, 1 for true)"
  echo "		if no dns value is given, the default from env file is used"
  echo
  echo "To remove an existing client:"
  echo "$scriptName remove clientName"
  echo "Remove a client with name clientName"
  echo
  echo "To manually regenerate the firewall (postup) script:"
  echo "$scriptName update-firewall"
  echo
}

case $1 in

  list)
    if [ $# != 1 ]; then
      echo "list does not take any other arguments"
      exit 1;
    fi
    source $LIST_PATH
  ;;

  init)
    if [ $# != 1 ]; then
      echo "init does not take any other arguments"
      exit 1;
    fi
    source $INIT_PATH
  ;;

  show)
    qrCode=0
    OPTS=$(getopt -o q --long qr-code -- "$@")
    if [ $? -ne 0 ]; then
      echo "Failed to parse options" >&2
      exit 1
    fi
    eval set -- "$OPTS"
    while true; do
      case $1 in
        -q | --qr-code)
          qrCode=1
          shift
        ;;
        --)
          shift
          break
        ;;
      esac
    done
    if [ $# != 2 ]; then
      echo "show should have exactly 1 client name"
      exit 1;
    fi
    source $SHOW_PATH $2 $qrCode
  ;;

  add)
    access=""
    dns=""
    OPTS=$(getopt -o a:d: --long access:dns: -- "$@")
    if [ $? -ne 0 ]; then
      echo "Failed to parse options" >&2
      exit 1
    fi
    eval set -- "$OPTS"
    while true; do
      case $1 in
        -a | --access)
          access=$2
          shift 2
        ;;
        -d | --dns)
          dns=$2
          shift 2
        ;;
        --)
          shift
          break
        ;;
      esac
    done
    if [ $# != 2 ]; then
      echo "add should have exactly 1 client name"
      exit 1;
    fi
    source $ADD_PATH $2 $access $dns
  ;;

  remove)
    if [ $# != 2 ]; then
      echo "remove takes exactly 1 client name"
      exit 1;
    fi
    source $REMOVE_PATH $2
  ;;

  update-firewall)
    if [ $# != 1 ]; then
      echo "update-firewall does not take any other arguments"
      exit 1;
    fi
    source $UPDATE_POSTUP_PATH
  ;;

  *)
    help
  ;;
esac
