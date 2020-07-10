#!/bin/bash

function main() {
  # TODO check prerequisites: .ssh directory with id_rsa.pub file, sha256sum, ssh
  
  # TODO attempt to continue where we left off in case of failures
  echo <<EOT
Starting viomi rooting procedure. Please make sure of the following before starting:
1. Your robot connects to your wifi when booted and your computer is connected to the same network.
2. It is powered off
3. You have a working micro-USB cable plugged into the robot and ready to plug into your computer.

Press [Enter] to continue
EOT
  read

  echo "We'll now try to connect to the ADB shell. Please connect the USB cable to your computer."
  echo "If you hear the Robot voice ('kaichi'), wait another two seconds and unplug and reconnect the cable."
  fix_adb_shell
  echo "Shell fixed..."
  persist_adb_shell

  echo "Please replug the USB cable one more time. Do not unplug once you hear the sound."
  wait_for_adb_shell
  echo "Shell is present."
  
  # TODO: wait for robot to connect to wifi
  ip=$(get_robot_ip)
  echo "IP is $ip"
  install_dropbear "$ip"

  echo "SSH was installed."
  echo 'Please change the root password now. The default one is typically "@3I#sc$RD%xm^2S&".'
  ssh vacuum "passwd"

  echo "Restoring robot services."
  restore_robot_services "$ip"

  read -p "Would you like to install Valetudo (open-source cloudless vacuum robot UI)? (y/n) " -n 1 -r
  if [[ ! $REPLY =~ ^[Yy]$ ]]
  then
      return
  fi
  install_valetudo
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
  ip=$(shift)
  wget https://itooktheredpill.irgendwo.org/static/2020/dropbear_2015.71-2_sunxi.ipk
  echo "6d21911b91505fd781dc2c2ad1920dfbb72132d7adb614cc5d2fb1cc5e29c8de  dropbear_2015.71-2_sunxi.ipk" dropbear.sha256
  sha256 -c dropbear.sha256 || exit
  adb push dropbear_2015.71-2_sunxi.ipk /tmp
  adb shell opkg install /tmp/dropbear_2015.71-2_sunxi.ipk
  adb push ~/.ssh/id_rsa.pub /etc/dropbear/authorized_keys
  adb shell chmod 0600 /etc/dropbear/authorized_keys
  adb shell sed -i "/PasswordAuth/ s/'on'/'off'/" /etc/config/dropbear
  adb shell /etc/init.d/dropbear start
  cat >> ~/.ssh/config <<EOF
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
  ip=$(shift)
  wget -O - https://github.com/rumpeltux/Valetudo/releases/download/0.4.1/valetudo.gz | gzip -d > valetudo
  echo "a6abc163b3f553926bcd7a211d46ed606bdb1ea2bcd4ae58627f8767c8c866b5  valetudo" > valetudo.sha256
  sha256 -c valetudo.sha256 || exit
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
	procd_set_param oom_adj $OOM_ADJ
	procd_set_param command $PROG
	procd_set_param stdout 1 # forward stdout of the command to logd
	procd_set_param stderr 1 # same for stderr
	procd_close_instance
}

shutdown() {
	echo shutdown
}
EOF
  ssh vacuum "cat >/etc/rc.d/S51valetudo" <<EOF
#!/bin/sh
iptables         -F OUTPUT
iptables  -t nat -F OUTPUT
dest=192.168.1.10  # enter your local development host here
for host in 110.43.0.83 110.43.0.85; do
  iptables  -t nat -A OUTPUT -p tcp --dport 80   -d $host -j DNAT --to-destination $dest:8080
  iptables  -t nat -A OUTPUT -p udp --dport 8053 -d $host -j DNAT --to-destination $dest:8053
  iptables         -A OUTPUT                     -d $host/32  -j REJECT
done
EOF
  ssh vacuum "echo '110.43.0.83 ot.io.mi.com ott.io.mi.com' >> /etc/hosts; chmod +x /etc/rc.d/S51valetudo /etc/init.d/valetudo; cd /etc/rc.d/; ln -s ../init.d/valetudo S97valetudo"
}

function get_robot_ip() {
  adb shell "ifconfig wlan0 | awk '/inet addr/{print substr($2,6)}'"
}

mkdir -p /tmp/viomi-root
pushd /tmp/viomi-root
main
