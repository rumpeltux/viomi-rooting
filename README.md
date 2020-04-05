# Viomi Rooting Tool

This tool aims to automate the rooting process described in
[Rooting the Xiaomi STYJ02YM (viomi-v7) Vacuum Robot](https://itooktheredpill.irgendwo.org/2020/rooting-xiaomi-vacuum-robot/).

## Prerequisites

* a linux machine with `bash`, `ssh`, `wget` and `sha256sum`
* the robot is already connected to your wifi (if you don't want to use the xiaomi app to do this,
  you can do this with [python-miio](https://github.com/rytilahti/python-miio)
* the linux machine needs to be on the same network as the robot
* a micro-USB cable plugged into the [robot’s micro-USB port](https://itooktheredpill.irgendwo.org/2020/rooting-xiaomi-vacuum-robot/).

## Usage instructions

Just run

    ./viomi-root.sh
