#!/bin/bash

#=======================================================================#
# Copyright (C) 2020 - 2022 Dominik Willner <th33xitus@gmail.com>       #
#                                                                       #
# This file is part of KIAUH - Klipper Installation And Update Helper   #
# https://github.com/th33xitus/kiauh                                    #
#                                                                       #
# This file may be distributed under the terms of the GNU GPLv3 license #
#=======================================================================#

set -e

#===================================================#
#================== INSTALL FLUIDD =================#
#===================================================#

function install_fluidd(){
  ### exit early if moonraker not found
  if [ -z "$(moonraker_systemd)" ]; then
    local error="Moonraker service not found!\n Please install Moonraker first!"
    print_error "${error}" && return
  fi
  ### checking dependencies
  local dep=(nginx)
  dependency_check "${dep[@]}"
  ### check if moonraker is already installed
  system_check_webui
  ### ask user how to handle Haproxy, Lighttpd, Apache2 if found
  process_services_dialog
  ### process possible disruptive services
  process_disruptive_services

  status_msg "Initializing Fluidd installation ..."
  ### check for other enabled web interfaces
  unset SET_LISTEN_PORT
  detect_enabled_sites

  ### check if another site already listens to port 80
  fluidd_port_check

  ### ask user to install mjpg-streamer
  local install_mjpg_streamer
  if [ ! -f "${SYSTEMD}/webcamd.service" ]; then
    while true; do
      echo
      top_border
      echo -e "| Install MJGP-Streamer for webcam support?             |"
      bottom_border
      read -p "${cyan}###### Please select (Y/n):${white} " yn
      case "${yn}" in
        Y|y|Yes|yes|"")
          select_msg "Yes"
          install_mjpg_streamer="true"
          break;;
        N|n|No|no)
          select_msg "No"
          install_mjpg_streamer="false"
          break;;
        *)
          error_msg "Invalid command!";;
      esac
    done
  fi

  ### ask user to install the recommended webinterface macros
  install_fluidd_macros

  ### create /etc/nginx/conf.d/upstreams.conf
  set_upstream_nginx_cfg
  ### create /etc/nginx/sites-available/<interface config>
  set_nginx_cfg "fluidd"

  ### symlink nginx log
  symlink_webui_nginx_log "fluidd"

  ### install fluidd
  fluidd_setup

  ### add fluidd to the update manager in moonraker.conf
  patch_fluidd_update_manager

  ### install mjpg-streamer
  [ "${install_mjpg_streamer}" = "true" ] && install_mjpg-streamer

  fetch_webui_ports #WIP

  ### confirm message
  print_confirm "Fluidd has been set up!"
}

function install_fluidd_macros(){
  while true; do
    echo
    top_border
    echo -e "| It is recommended to have some important macros in    |"
    echo -e "| your printer configuration to have Fluidd fully       |"
    echo -e "| functional and working.                               |"
    blank_line
    echo -e "| The recommended macros for Fluidd can be found here:  |"
    echo -e "| https://docs.fluidd.xyz/configuration/initial_setup   |"
    blank_line
    echo -e "| If you already have these macros in your config file, |"
    echo -e "| skip this step and answer with 'no'.                  |"
    echo -e "| Otherwise you should consider to answer with 'yes' to |"
    echo -e "| add the recommended example macros to your config.    |"
    bottom_border
    read -p "${cyan}###### Add the recommended macros? (Y/n):${white} " yn
    case "${yn}" in
      Y|y|Yes|yes|"")
        select_msg "Yes"
        download_fluidd_macros
        break;;
      N|n|No|no)
        select_msg "No"
        break;;
      *)
        print_error "Invalid command!";;
    esac
  done
  return
}

function download_fluidd_macros(){
  log_info "executing: download_fluidd_macros"
  local fluidd_cfg="https://raw.githubusercontent.com/fluidd-core/FluiddPI/master/src/modules/fluidd/filesystem/home/pi/klipper_config/fluidd.cfg"
  local configs
  configs=$(find "${KLIPPER_CONFIG}" -type f -name "printer.cfg")
  if [ -n "${configs}" ]; then
    ### create a backup of the config folder
    backup_klipper_config_dir

    for config in ${configs}; do
      path=$(echo "${config}" | rev | cut -d"/" -f2- | rev)
      if [ ! -f "${path}/fluidd.cfg" ]; then
        status_msg "Downloading fluidd.cfg to ${path} ..."
        log_info "downloading fluidd.cfg to: ${path}"
        wget "${fluidd_cfg}" -O "${path}/fluidd.cfg"
        ### replace user 'pi' with current username to prevent issues in cases where the user is not called 'pi'
        log_info "modify fluidd.cfg"
        sed -i "/^path: \/home\/pi\/gcode_files/ s/\/home\/pi/\/home\/${USER}/" "${path}/fluidd.cfg"
        ### write the include to the very first line of the printer.cfg
        if ! grep -Eq "^[include fluidd.cfg]$" "${path}/printer.cfg"; then
          log_info "modify printer.cfg"
          sed -i "1 i [include fluidd.cfg]" "${path}/printer.cfg"
        fi

        ok_msg "Done!"
      fi
    done
  else
    log_error "execution stopped! reason: no printer.cfg found"
    return
  fi
}

function fluidd_setup(){
  local url
  url=$(get_fluidd_download_url)
  status_msg "Downloading Fluidd ..."
  if [ -d "${FLUIDD_DIR}" ]; then
    rm -rf "${FLUIDD_DIR}"
  fi
  mkdir "${FLUIDD_DIR}" && cd "${FLUIDD_DIR}"
  wget "${url}" && ok_msg "Download complete!"

  status_msg "Extracting archive ..."
  unzip -q -o ./*.zip && ok_msg "Done!"

  status_msg "Remove downloaded archive ..."
  rm -rf ./*.zip && ok_msg "Done!"
}

#===================================================#
#================== REMOVE FLUIDD ==================#
#===================================================#

function remove_fluidd_dir(){
  [ ! -d "${FLUIDD_DIR}" ] && return
  status_msg "Removing Fluidd directory ..."
  rm -rf "${FLUIDD_DIR}" && ok_msg "Directory removed!"
}

function remove_fluidd_config(){
  if [ -e "/etc/nginx/sites-available/fluidd" ]; then
    status_msg "Removing Fluidd configuration for Nginx ..."
    sudo rm "/etc/nginx/sites-available/fluidd" && ok_msg "File removed!"
  fi
  if [ -L "/etc/nginx/sites-enabled/fluidd" ]; then
    status_msg "Removing Fluidd Symlink for Nginx ..."
    sudo rm "/etc/nginx/sites-enabled/fluidd" && ok_msg "File removed!"
  fi
}

function remove_fluidd_logs(){
  local files
  files=$(find /var/log/nginx -name "fluidd*")
  if [ -n "${files}" ]; then
    for file in ${files}; do
      status_msg "Removing ${file} ..."
      sudo rm -f "${file}"
      ok_msg "${file} removed!"
    done
  fi
}

function remove_fluidd_log_symlinks(){
  local files
  files=$(find "${HOME}/klipper_logs" -name "fluidd*")
  if [ -n "${files}" ]; then
    for file in ${files}; do
      status_msg "Removing ${file} ..."
      rm -f "${file}"
      ok_msg "${file} removed!"
    done
  fi
}

function remove_fluidd(){
  remove_fluidd_dir
  remove_fluidd_config
  remove_fluidd_logs
  remove_fluidd_log_symlinks

  ### remove fluidd_port from ~/.kiauh.ini
  sed -i "/^fluidd_port=/d" "${INI_FILE}"

  print_confirm "Fluidd successfully removed!"
}

#===================================================#
#================== UPDATE FLUIDD ==================#
#===================================================#

function update_fluidd(){
  bb4u "fluidd"
  status_msg "Updating Fluidd ..."
  fluidd_setup
  match_nginx_configs
  symlink_webui_nginx_log "fluidd"
}

#===================================================#
#================== FLUIDD STATUS ==================#
#===================================================#

function fluidd_status(){
  local status
  local data_arr=("${FLUIDD_DIR}" "${NGINX_SA}/fluidd" "${NGINX_SE}/fluidd")

  ### count+1 for each found data-item from array
  local filecount=0
  for data in "${data_arr[@]}"; do
    [ -e "${data}" ] && filecount=$(("${filecount}" + 1))
  done

  if [ "${filecount}" == "${#data_arr[*]}" ]; then
    status="${green}Installed!${white}      "
  elif [ "${filecount}" == 0 ]; then
    status="${red}Not installed!${white}  "
  else
    status="${yellow}Incomplete!${white}     "
  fi
  echo "${status}"
}

function get_local_fluidd_version(){
  local version
  [ ! -f "${FLUIDD_DIR}/.version" ] && return
  version=$(head -n 1 "${FLUIDD_DIR}/.version")
  echo "${version}"
}

function get_remote_fluidd_version(){
  local version
  [[ ! $(dpkg-query -f'${Status}' --show curl 2>/dev/null) = *\ installed ]] && return
  version=$(get_fluidd_download_url | rev | cut -d"/" -f2 | rev)
  echo "${version}"
}

function compare_fluidd_versions(){
  unset FLUIDD_UPDATE_AVAIL
  local versions local_ver remote_ver
  local_ver="$(get_local_fluidd_version)"
  remote_ver="$(get_remote_fluidd_version)"
  if [ "${local_ver}" != "${remote_ver}" ]; then
    versions="${yellow}$(printf " %-14s" "${local_ver}")${white}"
    versions+="|${green}$(printf " %-13s" "${remote_ver}")${white}"
    # add fluidd to the update all array for the update all function in the updater
    FLUIDD_UPDATE_AVAIL="true" && update_arr+=(update_fluidd)
  else
    versions="${green}$(printf " %-14s" "${local_ver}")${white}"
    versions+="|${green}$(printf " %-13s" "${remote_ver}")${white}"
    FLUIDD_UPDATE_AVAIL="false"
  fi
  echo "${versions}"
}

#================================================#
#=================== HELPERS ====================#
#================================================#

function get_fluidd_download_url() {
  local latest_tag latest_url stable_tag stable_url url
  tags=$(curl -s "${FLUIDD_TAGS}" | grep "name" | cut -d'"' -f4)

  ### latest download url including pre-releases (alpha, beta, rc)
  latest_tag=$(echo "${tags}" | head -1)
  latest_url="https://github.com/fluidd-core/fluidd/releases/download/${latest_tag}/fluidd.zip"

  ### get stable fluidd download url
  stable_tag=$(echo "${tags}" | grep -E "^v([0-9]+\.?){3}$" | head -1)
  stable_url="https://github.com/fluidd-core/fluidd/releases/download/${stable_tag}/fluidd.zip"

  read_kiauh_ini
  if [ "${fluidd_install_unstable}" == "true" ]; then
    url="${latest_url}"
    echo "${url}"
  else
    url="${stable_url}"
    echo "${url}"
  fi
}

function fluidd_port_check(){
  if [ "${FLUIDD_ENABLED}" = "false" ]; then
    if [ "${SITE_ENABLED}" = "true" ]; then
      status_msg "Detected other enabled interfaces:"
      [ "${OCTOPRINT_ENABLED}" = "true" ] && echo "   ${cyan}● OctoPrint - Port: ${OCTOPRINT_PORT}${white}"
      [ "${MAINSAIL_ENABLED}" = "true" ] && echo "   ${cyan}● Mainsail - Port: ${MAINSAIL_PORT}${white}"
      if [ "${MAINSAIL_PORT}" = "80" ] || [ "${OCTOPRINT_PORT}" = "80" ]; then
        PORT_80_BLOCKED="true"
        select_fluidd_port
      fi
    else
      DEFAULT_PORT=$(grep listen "${SRCDIR}/kiauh/resources/klipper_webui_nginx.cfg" | head -1 | sed 's/^\s*//' | cut -d" " -f2 | cut -d";" -f1)
      SET_LISTEN_PORT=${DEFAULT_PORT}
    fi
    SET_NGINX_CFG="true"
  else
    SET_NGINX_CFG="false"
  fi
}

function select_fluidd_port(){
  if [ "${PORT_80_BLOCKED}" = "true" ]; then
    echo
    top_border
    echo -e "|                    ${red}!!!WARNING!!!${white}                      |"
    echo -e "| ${red}You need to choose a different port for Fluidd!${white}       |"
    echo -e "| ${red}The following web interface is listening at port 80:${white}  |"
    blank_line
    [ "${OCTOPRINT_PORT}" = "80" ] && echo "|  ● OctoPrint                                          |"
    [ "${MAINSAIL_PORT}" = "80" ] && echo "|  ● Mainsail                                           |"
    blank_line
    echo -e "| Make sure you don't choose a port which was already   |"
    echo -e "| assigned to one of the other webinterfaces and do ${red}NOT${white} |"
    echo -e "| use ports in the range of 4750 or above!              |"
    blank_line
    echo -e "| Be aware: there is ${red}NO${white} sanity check for the following  |"
    echo -e "| input. So make sure to choose a valid port!           |"
    bottom_border
    while true; do
      read -p "${cyan}Please enter a new Port:${white} " NEW_PORT
      if [ "${NEW_PORT}" != "${MAINSAIL_PORT}" ] && [ "${NEW_PORT}" != "${OCTOPRINT_PORT}" ]; then
        echo "Setting port ${NEW_PORT} for Fluidd!"
        SET_LISTEN_PORT=${NEW_PORT}
        break
      else
        echo "That port is already taken! Select a different one!"
      fi
    done
  fi
}

function patch_fluidd_update_manager(){
  local moonraker_configs
  moonraker_configs=$(find "$(get_klipper_cfg_dir)" -type f -name "moonraker.conf")
  for conf in ${moonraker_configs}; do
    status_msg "Adding Fluidd to update manager in file:\n       ${conf}"
    ### add new line to conf if it doesn't end with one
    [[ $(tail -c1 "${conf}" | wc -l) -eq 0 ]] && echo "" >> "${conf}"
    ### add Fluidds update manager section to moonraker.conf
    if grep -Eq "[update_manager fluidd]" "${conf}"; then
      /bin/sh -c "cat >> ${conf}" << MOONRAKER_CONF

[update_manager fluidd]
type: web
channel: stable
repo: fluidd-core/fluidd
path: ~/fluidd
MOONRAKER_CONF
    fi
  done
}