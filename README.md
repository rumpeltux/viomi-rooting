# Viomi Rooting Tool

This tool aims to automate the rooting process described in
[Rooting the Xiaomi STYJ02YM (viomi-v7) Vacuum Robot](https://itooktheredpill.irgendwo.org/2020/rooting-xiaomi-vacuum-robot/).

It is known to work with the following models:

* Mijia STYJ02YM (viomi-v7)
* Mijia STYTJ02YM (viomi-v8) (not tried yet)

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

**Problem:** The script was not able to establish a ssh connection and didn't finish.

Solution: Rerun the remaining steps of the script (replace `ROBOT_IP` with the actual ip address)

    ./viomi-root.sh change_password
    ./viomi-root.sh restore_robot_services
    ./viomi-root.sh install_valetudo ROBOT_IP
