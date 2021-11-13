#!/bin/bash
### set some messages
warn_msg() {
  echo -e "${red}<!!!!> $1${default}"
}
status_msg() {
  echo
  echo -e "${yellow}###### $1${default}"
}
ok_msg() {
  echo -e "${green}>>>>>> $1${default}"
}
title_msg() {
  echo -e "${cyan}$1${default}"
}
get_date() {
  current_date=$(date +"%y%m%d-%H%M")
}
print_unkown_cmd() {
  ERROR_MSG="Invalid command!"
}

#######################################
# description Display an error or a confirmation
# Globals:
#   CONFIRM_MSG
#   ERROR_MSG
#   KIAUH_TITLE
#   KIAUH_WHIPTAIL_NORMAL_WIDTH
#   KIAUH_WHIPTAIL_SINGLE_LINE_HEIGHT
# Arguments:
#  None
#######################################
print_msg() {
  if [[ $ERROR_MSG != "" ]]; then
    whiptail --title "$KIAUH_TITLE" --msgbox "$ERROR_MSG" \
      "$KIAUH_WHIPTAIL_SINGLE_LINE_HEIGHT" "$KIAUH_WHIPTAIL_NORMAL_WIDTH"
  fi
  # TODO Maybe confirm_msg can be yesno box
  if [ "$CONFIRM_MSG" != "" ]; then
    whiptail --title "$KIAUH_TITLE" --msgbox "$CONFIRM_MSG" \
      "$KIAUH_WHIPTAIL_SINGLE_LINE_HEIGHT" "$KIAUH_WHIPTAIL_NORMAL_WIDTH"
  fi
}

clear_msg() {
  unset CONFIRM_MSG
  unset ERROR_MSG
}

function main() {
  ### Gettext Configuration
  alias GETTEXT='gettext "KIAUH"'

  #clear
  # TODO set -e cause whiptail to force an exit because it use stderr, need a workaround here
  # set -e
  ### set color variables
  green=$(echo -en "\e[92m")

  yellow=$(echo -en "\e[93m")

  red=$(echo -en "\e[91m")

  cyan=$(echo -en "\e[96m")

  default=$(echo -en "\e[39m")

  ### sourcing all additional scripts
  SRCDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"

  for script in "${SRCDIR}/kiauh/scripts/constants/"*.sh; do . $script; done

  for script in "${SRCDIR}/kiauh/scripts/"*.sh; do . $script; done

  for script in "${SRCDIR}/kiauh/scripts/ui/"*.sh; do . $script; done

  check_euid

  init_ini

  kiauh_status

  main_menu

}

main "$@"
