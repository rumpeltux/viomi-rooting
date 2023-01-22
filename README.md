# Viomi Rooting Tool

This tool aims to automate the rooting process described in
[Rooting the Xiaomi STYJ02YM (viomi-v7) Vacuum Robot](https://itooktheredpill.irgendwo.org/2020/rooting-xiaomi-vacuum-robot/).

It is known to work with the following models:

* Mijia STYJ02YM (viomi-v7)
* Mijia STYTJ02YM (viomi-v8) (experimental)

## Prerequisites

* a linux (Mac, raspberry pi or OpenWRT router may also work) machine with
  `bash`, `ssh`, `wget`, `adb` and `sha256sum`
* the robot is already connected to your wifi (if you don't want to use the xiaomi app to do this,
  you can do this with [python-miio](https://github.com/rytilahti/python-miio))
* the linux machine needs to be on the same network as the robot
* a good micro-USB cable (with data support) plugged into the
  [robot’s micro-USB port](https://itooktheredpill.irgendwo.org/2020/rooting-xiaomi-vacuum-robot/).

### Linux setup

You may need to install these packages, e.g. for Ubuntu:

    apt install android-tools-adb wget coreutils

### Mac setup

On Mac, install `adb` and `sha256sum` as follows:

```shell
# Package for adb
brew install android-platform-tools

# Package for sha256sum
brew install coreutils
```

## Usage instructions

Clone this repository, then run the following command and follow its instructions:

    ./viomi-root.sh

Note: For newer viomi-v8 models, above will not work, but you can try the
following experimental procedure based on
[findings by @Dropaq](https://github.com/rumpeltux/python-miio/issues/1#issuecomment-915647117):

    NEW_V8=1 ./viomi-root.sh

## What’s the script doing?

1. Enable the `adb shell` command.
2. Temporarily disable robot services to allow the adb bridge to persist during setup.
3. Install `dropbear` along with your `~/.ssh/id_rsa.pub` public key
4. (Optionally:) Install [Valetudo](https://github.com/Hypfer/Valetudo).

## Troubleshooting

### No adb connection is established.

* Check that adb and your cable is working in general by connecting to an android phone
  (enable usb debugging on it), e.g. by using adb shell.
* Check the `dmesg` output to see if your computer ever recognized a USB devices.
  Some machines are too slow, some USB stacks flaky. People have
  [reported success](https://github.com/rumpeltux/viomi-rooting/issues/7#issuecomment-691664493)
  with a raspberry pi when their main computer didn’t work.
* If you see a message like:

      adb: insufficient permissions for device
      See [http://developer.android.com/tools/device.html] for more information
  Follow [the link](http://developer.android.com/tools/device.html) for advice, in particular
  make sure that you are a member of the plugdev group and have setup correct udev rules
  (`dmesg` would probably show you the device ids).
* Finally, this may not be working on first attempt, but may need multiple tries,
  but typically not more than 10.

### The script was not able to establish a ssh connection and didn't finish.

Solution: Rerun the remaining steps of the script

    ./viomi-root.sh change_password
    ./viomi-root.sh restore_robot_services
    ./viomi-root.sh install_valetudo

### The robot appears dead, but SSH or ADB are working.

Solution (does not apply to newer viomi-v8 models):

* When SSH is working:

      ./viomi-root.sh restore_robot_services
    
* When ADB is working:

      adb shell
      cd /etc/rc.d
      ln -s ../init.d/robotManager S90robotManager

### I accidentally resetted the wifi settings (Robot already rooted!).

Solution:
1.  Please connect to your robot using: `adb shell`
2.  Edit the `/etc/wifi/wpa_supplicant.conf` file using, e.g. vim:
   ```
   vim /etc/wifi/wpa_supplicant.conf
   ```
3.  Add these lines at the end of the file:
    ```
    network={
        ssid="SSIDGOESHERE"
        psk="PASSWORDHERE"
    }
    ```
4.  Reboot the device: `reboot`
5.  Check if your robot received an ip address: `adb shell ip a`
6.  Try to connect over ssh from your computer, and change your `.ssh/config` file
    accordingly `ssh root@robotIP` or `ssh vacuum`
