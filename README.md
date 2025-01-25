# ASC - Autonomous Slot Car

An autonomous slot-car running on a Raspberry Pi

## Quickstart

This Quickstart enables you to build the controller for Raspberry Pi and a client for your machine.

### Setup the Raspberry Pi

First install `Raspberry Pi Os Lite 64-bit`: 

    - configure WLAN
    - use ssh keys

Then update the system with `apt update && apt upgrade`.
Activate I2C with `raspi-config` under Interface Options.

### Configure deployment

`deploy_raspi.sh`: Set the `IP` to the ip of your Raspberry Pi or to the hostname and specify the `USER`.
Then set the `REMOTE_DIRECTORY` to an existing directory in the users home (relative path).

### Run the program

`zig build run`

## TODO

- don't use poll windows since it is not supported
- use raylib for plotting and ui

Later:
- IMU that works well in high acceleration environment

Maybe:
- Endianness?
- Compile error bei falschen typen (decode)
- Compile error wenn typ nicht in contract (encode)
- CallHandler ohne for loop und compile error wenn index nicht existiert
