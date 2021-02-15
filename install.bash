#!/usr/bin/env bash

package_status() {
  dpkg-query --show --showformat='${db:Status-Abbrev}\n' "$1"
}
require_package() {
  STATUS=$( package_status "$1" )
  if [[ "$STATUS" -eq 'un' ]]; then
    if [[ ! "$STATUS" -eq 'ii' ]]; then
      echo "ERROR: package $1 is in unclean state."
      exit 1
    fi
    apt install --yes "$1" || exit 1
  fi
}
list_packages() {
  dpkg-query --show --showformat='${Package} '
}

if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: You need to be ROOT (sudo can be used)."
  exit 1
fi
if [[ $(systemctl is-active zram-config.service) == "active" ]]; then
  echo "ERROR: zram-config service is still running. Please run \"sudo /usr/local/share/zram-config/uninstall.bash\" to uninstall zram-config before running this."
  exit 1
fi
if [[ -f /usr/local/sbin/zram-config ]]; then
  echo "ERROR: zram-config is already installed. Please run \"sudo /usr/local/share/zram-config/uninstall.bash\" to uninstall zram-config before running this."
  exit 1
fi

echo "Installing needed packages (gcc, make, libattr1-dev)"
PKGS_START=$( list_packages )
require_package "gcc"
require_package "make"
require_package "libattr1-dev"
PKGS_END=$( list_packages )
PKGS_DIFF=$( echo $PKGS_START $PKGS_END | tr ' ' '\n' | sort | uniq -u | tr '\n' ' ' )

echo "Building overlayfs-tools"
cd overlayfs-tools || exit 1
make
cd ..

echo "Removing temporarily installed packages"
[[ ! -z "$PKGS_DIFF" ]] && apt remove --purge --yes $PKGS_DIFF

echo "Installing zram-config files"
install -m 755 zram-config /usr/local/sbin/
install -m 644 zram-config.service /etc/systemd/system/zram-config.service
install -m 644 ztab /etc/ztab
mkdir -p /usr/local/share/zram-config/log
install -m 644 uninstall.bash /usr/local/share/zram-config/uninstall.bash
install -m 644 zram-config.logrotate /etc/logrotate.d/zram-config
mkdir -p /usr/local/lib/zram-config/
install -m 755 overlayfs-tools/overlay /usr/local/lib/zram-config/overlay

echo "Starting zram-config.service"
systemctl daemon-reload
systemctl enable --now zram-config.service

echo "#####   zram-config is now installed and running   #####"
echo "#####     edit /etc/ztab to configure options      #####"
