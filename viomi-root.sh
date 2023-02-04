#!/bin/bash

function main() {
  [ -d "$HOME/.ssh" ] || { echo "~/.ssh does not exist, trying to create it."; mkdir -p "$HOME/.ssh" || exit; }
  echo -n >> "$HOME/.ssh/config" || { echo "Cannot edit ~/.ssh/config."; exit; }
  while [ ! -e "$HOME/.ssh/id_rsa.pub" ]; do
    echo "You don't seem to have an ssh key, generating one.";
    ssh-keygen -f "$HOME/.ssh/id_rsa" || exit;
  done
  for tool in adb awk sha256sum ssh wget; do
    which $tool > /dev/null || (echo "Please install $tool."; exit)
  done

  cat <<EOT
Starting viomi rooting procedure. Please make sure of the following before starting:
1. Your robot connects to your wifi when booted and your computer is connected to the same network.
2. It is powered off
3. You have a working micro-USB cable plugged into the robot and ready to plug into your computer.

Press [Enter] to continue
EOT
  read

  echo "Checking if SSH is already configured and working"
  if ssh -o ConnectTimeout=5 -q vacuum exit
  then
      read -p "It appear that ssh has already been configured, would you like to skip adb connection and ssh activation? (y/n) " -n 1 -r
      if [[ ! $REPLY =~ ^[Nn]$ ]]
      then
        echo "SSH configuration skipped";
      else
        echo "Rerunning ssh installation"
        connect_adb_and_install_dropbear
      fi
  else
    echo "SSH not configured"
    connect_adb_and_install_dropbear
  fi

  if [ -z "$NEW_V8" ]; then
    if ssh vacuum "test -f /etc/rc.d/S90robotManager"
    then
      echo "Robot service already restored, skipping"
    else
      echo "Restoring robot services."
      restore_robot_services
    fi
  fi
  
  date_reset_workaround

  read -p "Would you like to install Valetudo (open-source cloudless vacuum robot UI)? (y/n) " -n 1 -r
  if [[ ! $REPLY =~ ^[Yy]$ ]]
  then
      return
  fi
  install_valetudo
}

function connect_adb_and_install_dropbear() {
  if [ -z "$NEW_V8" ]; then
    echo "We'll now try to connect to the ADB shell. Please connect the USB cable to your computer."
    echo "If you hear the Robot voice ('kaichi'), wait another two seconds and unplug and reconnect the cable."
    echo "If nothing happens try replugging the USB cable. This may take 10 or more attempts."
  else
    cat <<EOT
We'll now try to connect to the ADB shell for new viomi-v8 models (experimental).
* Long press the power key for at least 10 seconds to power off the device
* Keep USB connected to the robot, but not to the PC
* Press the "Home" key and do not release it.
* Connect the USB to the PC
* Click power key for about 10-11 times
* Release both keys
* Robot should boot into FEL mode, and start the ADB.
  The robot confirms by saying "device connected", "setup completed".
  If it says "turning on", try again.
EOT
    read -p 'Press ENTER once ADB setup is completed.'
  fi

  fix_adb_shell
  echo "Shell fixed..."
  
  if [ -z "$NEW_V8" ]; then
    persist_adb_shell

    echo "Please replug the USB cable again. Do not unplug once you hear the sound."
  fi
  wait_for_adb_shell
  echo "Shell is present."

  # TODO: figure out when the robot is connected to wifi
  echo -n "Waiting a bit to allow the robot to connect to wifi..."
  for i in $(seq 10); do
    echo -n '.'; sleep 1;
  done
  echo

  ip=$(get_robot_ip)
  [ -z "$ip" ] && {
    echo "Could not determine robot IP. Was its WIFI properly configured?"
    echo "Skipping dropbear installation, to continue run the following manually:"
    echo "  $0 install_dropbear ROBOT_IP_ADDRESS"
    echo "  $0 restore_robot_services"
    echo "  $0 install_valetudo"
    exit
  }

  echo "Robot IP is $ip"
  install_dropbear "$ip"
  echo "SSH was installed."
}

function adb_loop() {
   if [ -z "$NEW_V8" ]; then
    while true; do
      adb $@ | grep -v "no devices/emulators found" && break
    done
  else
    # newer viomi-v8 revisions don’t kill the adb script, so we don’t need a loop
    adb $@
  fi
}

function fix_adb_shell() {
  cat >adb_shell <<"EOF"
#!/bin/sh
export ENV='/etc/adb_profile'
exec /bin/sh "$@"
EOF
  chmod +x adb_shell
  adb_loop push -a adb_shell /bin/adb_shell
}

function persist_adb_shell() {
  adb_loop shell rm /etc/rc.d/S90robotManager
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
  # Give dropbear a bit time to start, before we try to connect in the next step.
  # TODO replace this with a while loop, testing ssh connection with "ssh -q vacuum exit"
  echo "Waiting 5 seconds for ssh server dropbear to start"
  sleep 5

  echo 'Please change the root password now. The default one is typically "@3I#sc$RD%xm^2S&".'
  # TODO find a way to check if the password was already changed, maybe by checking root entry in cat /etc/shadow
  ssh vacuum "passwd"
}

function restore_robot_services() {
  ssh vacuum "cd /etc/rc.d; ln -s ../init.d/robotManager S90robotManager"
  echo "Your device is now rooted."
  # And to celebrate:
  ssh vacuum "tinyplayer /usr/share/audio/english/sound_test_ready.mp3"
}

function date_reset_workaround() {
  # Some process seems to reset datetime after boot. Workaround per:
  # https://github.com/rumpeltux/viomi-rooting/issues/41
  ssh vacuum "cat > /usr/sbin/date; chmod +x /usr/sbin/date" <<"EOF"
/bin/date -u -s "$2"
sleep 2
/bin/date -u -s "$2"
sleep 2
/bin/date -u -s "$2"
EOF
}

function install_valetudo() {
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
#Get the ip of the robot from the ssh config file
ip=$(ssh -G vacuum | awk '$1 == "hostname" { print $2 }')
echo "Robot is restarting, you should be able to reach Valetudo at http://$ip once restarted"
}

function get_robot_ip() {
  adb shell ifconfig wlan0 | awk '/inet addr/{print substr($2,6)}'
}

mkdir -p /tmp/viomi-root
pushd /tmp/viomi-root

[ -z "$1" ] && main || $@
