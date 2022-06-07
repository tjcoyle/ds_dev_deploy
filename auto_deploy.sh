#!/bin/bash

ENV_TYPE=dev
PROJECT_SLUG=$1
CMS_BUILD_IP=173.255.208.122
PACKAGE_PATTERN=downstream-cms-${PROJECT_SLUG}*.deb
PACKAGE_DIR=./dist
ALERT_FROM_ADDRESS=noreply@downstreamlabs.com
ALERT_TO_ADDRESS=thomas.coyle@downstream.com
SCRIPT_ROOT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

log_msg () {

  printf "$(date +'%Y-%m-%d %T')\t${1}\n"
}

main () {

  log_msg "Run started for project: ${PROJECT_SLUG}"

  log_msg "Script root is located at: ${SCRIPT_ROOT}"

  # Grab last package name deployed,  if any
  if [[ -f "${SCRIPT_ROOT}/.dev.${PROJECT_SLUG}.last" ]]; then
    LAST_PACKAGE=$(cat "${SCRIPT_ROOT}/.dev.${PROJECT_SLUG}.last")
  fi

  # Look for a newer(st) package on build machine
  NEWEST_PACKAGE=$(ssh "downstream@${CMS_BUILD_IP}" "cd ${PACKAGE_DIR}; ls -Art ${PACKAGE_PATTERN} | tail -1")

  log_msg "Last package was ${LAST_PACKAGE}"
  log_msg "Latest available package is ${NEWEST_PACKAGE}"

  if [[ "${NEWEST_PACKAGE}" != "${LAST_PACKAGE}" ]]; then

    log_msg "Latest package ${NEWEST_PACKAGE} differs from last package ${LAST_PACKAGE}, downloading now..."

    scp downstream@${CMS_BUILD_IP}:${PACKAGE_DIR}/${NEWEST_PACKAGE} # . || log_message "Fatal error downloading package ${NEWEST_PACKAGE}, exiting now." && exit 1

    log_msg "Package successfully downloaded, installing now..."

    apt install -y ./${NEWEST_PACKAGE} || exit 1

    echo "${NEWEST_PACKAGE}" > "${SCRIPT_ROOT}/.dev.${PROJECT_SLUG}.last"

    # certbot has been lingering, handling that here for now
    if pgrep -x "certbot" >> /dev/null
    then
      log_msg "Certbot is running, going to kill it now."
      killall -9 certbot
    fi

    sudo certbot --agree-tos --non-interactive --nginx --reinstall --redirect -d ${ENV_TYPE}.${PROJECT_SLUG}.downstreamlabs.com

    echo "Package ${NEWEST_PACKAGE} was just successfully deployed." | mailx \
	-r ${ALERT_FROM_ADDRESS} \
        -s "Deployed: ${NEWEST_PACKAGE}" \
        ${ALERT_TO_ADDRESS}

    log_msg "Deployment completed successfully"
  else
    log_msg "Skipping, no need to install."
  fi

  log_msg "Run complete"

}

main
