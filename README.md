# Viomi Rooting Tool

This tool aims to automate the rooting process described in
[Rooting the Xiaomi STYJ02YM (viomi-v7) Vacuum Robot](https://itooktheredpill.irgendwo.org/2020/rooting-xiaomi-vacuum-robot/).

It is known to work with the following models:

* Mijia STYJ02YM (viomi-v7)
* Mijia STYTJ02YM (viomi-v8) (experimental)

## Prerequisites

* a linux machine with `bash`, `ssh`, `wget`, `adb` and `sha256sum`
* the robot is already connected to your wifi (if you don't want to use the xiaomi app to do this,
  you can do this with [python-miio](https://github.com/rytilahti/python-miio)
* the linux machine needs to be on the same network as the robot
* a micro-USB cable plugged into the [robot’s micro-USB port](https://itooktheredpill.irgendwo.org/2020/rooting-xiaomi-vacuum-robot/).

## Usage instructions

Clone this repository, then run the following command and follow its instructions:

    ./viomi-root.sh

## What’s the script doing?

1. Enable the `adb shell` command.
2. Temporarily disable robot services to allow the adb bridge to persist during setup.
3. Install `dropbear` along with your `~/.ssh/id_rsa.pub` public key
4. (Optionally:) Install [Valetudo](https://github.com/Hypfer/Valetudo).

## Troubleshooting

**Problem:** No adb connection is established.

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

**Problem:** The script was not able to establish a ssh connection and didn't finish.

Solution: Rerun the remaining steps of the script (replace `ROBOT_IP` with the actual ip address)

    ./viomi-root.sh change_password
    ./viomi-root.sh restore_robot_services
    ./viomi-root.sh install_valetudo ROBOT_IP
