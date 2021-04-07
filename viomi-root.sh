#!/bin/bash

function main() {
  [ -d "$HOME/.ssh" ] || (echo "~/.ssh does not exist, trying to create it."; mkdir -p "$HOME/.ssh" || exit)
  echo -n >> "$HOME/.ssh/config" || (echo "Cannot edit ~/.ssh/config."; exit)
  [ -e "$HOME/.ssh/id_rsa.pub" ] || (echo "You don't seem to have an ssh key, generating one."; ssh-keygen || exit)
  for tool in sha256sum ssh; do
    which $tool > /dev/null || (echo "Please install $tool."; exit)
  done
  
  # TODO attempt to continue where we left off in case of failures
  cat <<EOT
Starting viomi rooting procedure. Please make sure of the following before starting:
1. Your robot connects to your wifi when booted and your computer is connected to the same network.
2. It is powered off
3. You have a working micro-USB cable plugged into the robot and ready to plug into your computer.

Press [Enter] to continue
EOT
  read

  echo "We'll now try to connect to the ADB shell. Please connect the USB cable to your computer."
  echo "If you hear the Robot voice ('kaichi'), wait another two seconds and unplug and reconnect the cable."
  echo "If nothing happens try replugging the USB cable. This may take 10 or more attempts."
  fix_adb_shell
  echo "Shell fixed..."
  persist_adb_shell

  echo "Please replug the USB cable again. Do not unplug once you hear the sound."
  wait_for_adb_shell
  echo "Shell is present."
  
  # TODO: figure out when the robot is connected to wifi
  echo -n "Waiting a bit to allow the robot to connect to wifi..."
  for i in $(seq 10); do
    echo -n '.'; sleep 1;
  done
  echo

  ip=$(get_robot_ip)
  echo "Robot IP is $ip"
  install_dropbear "$ip"
  echo "SSH was installed."
  
  # Give dropbear a bit time to start, before we try to connect in the next step.
  sleep 2

  echo 'Please change the root password now. The default one is typically "@3I#sc$RD%xm^2S&".'
  ssh vacuum "passwd"

  echo "Restoring robot services."
  restore_robot_services

  read -p "Would you like to install Valetudo (open-source cloudless vacuum robot UI)? (y/n) " -n 1 -r
  if [[ ! $REPLY =~ ^[Yy]$ ]]
  then
      return
  fi
  install_valetudo "$ip"
}

function fix_adb_shell() {
  cat >adb_shell <<"EOF"
#!/bin/sh
export ENV='/etc/adb_profile'
exec /bin/sh "$@"
EOF
  chmod +x adb_shell
  while true; do
    adb push -a adb_shell /bin/adb_shell | grep -v "no devices/emulators found" && break
  done
}

function persist_adb_shell() {
  while true; do
    adb shell rm /etc/rc.d/S90robotManager | grep -v "no devices/emulators found" && break
  done
}

function wait_for_adb_shell() {
  while true; do
    adb shell echo shell_is_ready | grep -v "no devices/emulators found" | grep "shell_is_ready" && break
  done
}

function install_dropbear() {
  ip=$1
  filename=dropbear_2015.71-2_sunxi.ipk
  wget "https://itooktheredpill.irgendwo.org/static/2020/$filename" -O $filename
  echo "6d21911b91505fd781dc2c2ad1920dfbb72132d7adb614cc5d2fb1cc5e29c8de  $filename" > dropbear.sha256
  sha256sum -c dropbear.sha256 || exit
  adb push $filename /tmp
  adb shell opkg install /tmp/$filename
  adb push ~/.ssh/id_rsa.pub /etc/dropbear/authorized_keys
  adb shell chmod 0600 /etc/dropbear/authorized_keys
  adb shell "sed -i \"/PasswordAuth/ s/'on'/'off'/\" /etc/config/dropbear"
  adb shell /etc/init.d/dropbear start
  echo "Setting local ssh alias vacuum to root@$ip."
  echo "You can use 'ssh vacuum' to connect to the robot from now on."
  cat >> "$HOME/.ssh/config" <<EOF
Host vacuum
  Hostname $ip
  User root
EOF
}

function restore_robot_services() {
  ssh vacuum "cd /etc/rc.d; ln -s ../init.d/robotManager S90robotManager"
  echo "Your device is now rooted."
  # And to celebrate:
  ssh vacuum "tinyplayer /usr/share/audio/english/sound_test_ready.mp3"
}

function install_valetudo() {
  ip=$1
  wget "https://github.com/Hypfer/Valetudo/releases/download/2021.03.0/valetudo-armv7" -O valetudo
  chmod +x valetudo
  echo "1c3e91b944fcbf80bb7508df3900059d851198a47fcd0abf6a439f1fda0086c4  valetudo" > valetudo.sha256
  sha256sum -c valetudo.sha256 || exit
  scp valetudo vacuum:/mnt/UDISK/
  ssh vacuum "cat >/etc/init.d/valetudo" <<EOF
#!/bin/sh /etc/rc.common
START=97
STOP=99

USE_PROCD=1
PROG=/mnt/UDISK/valetudo
OOM_ADJ=-17

start_service() {
  procd_open_instance
  procd_set_param env VALETUDO_CONFIG_PATH=/mnt/UDISK/valetudo_config.json
  procd_set_param oom_adj \$OOM_ADJ
  procd_set_param command \$PROG
  procd_set_param stdout 1 # forward stdout of the command to logd
  procd_set_param stderr 1 # same for stderr
  procd_close_instance
}

shutdown() {
  echo shutdown
}
EOF
  ssh vacuum <<\EOF
sed -i 's/110.43.0.8./127.00.00.1/g' /usr/bin/miio_client
for domain in "" de. ea. in. pv. ru. sg. st. tw. us.; do
  echo "127.0.0.1 ${domain}ot.io.mi.com ${domain}ott.io.mi.com" >> /etc/hosts
done;
chmod +x /etc/init.d/valetudo;
cd /etc/rc.d/;
ln -s ../init.d/valetudo S97valetudo;
reboot
EOF
echo "Robot is restarting, you should be able to reach Valetudo at http://$ip once restarted"
}

function get_robot_ip() {
  adb shell ifconfig wlan0 | awk '/inet addr/{print substr($2,6)}'
}

mkdir -p /tmp/viomi-root
pushd /tmp/viomi-root

[ -z "$1" ] && main || $@
