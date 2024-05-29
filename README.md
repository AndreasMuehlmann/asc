# ASC - Autonomous Slot Car

An autonomous slot-car running on a Raspberry Pi

## Quickstart

This Quickstart enables you to build the controller for Raspberry Pi and a client for your machine.

### Setup the Raspberry Pi

First install `Raspberry Pi Os Lite`: 

    - configure WLAN
    - use ssh keys

Then update the system with `apt update && apt upgrade`.
Install required libraries:

    - Pigpio: `apt install pigpio` 
    - ZeroMQ: `apt install libzmq` 
    - Protocol Buffers: `apt install libprotobuf-dev`

Activate I2C with `raspi-config` under Interface Options.

### Build the cross compilation toolchain

Crosstool-ng is used to build the toolchain. The config for Crosstool-ng is in `toolchain_config_raspi`.
To use to build the toolchain run `ct-ng build`.

When the build completes, specify the path to your toolchain binaries in `CMakeLists.txt`.

See more on [cross compilation](./doc/cross_compilation.md)

### Setup CMake

Create a build directory with `mkdir build`. Change into it with `cd build`.
Then run `cmake ..`.

### Sync the sysroot

In `sync_sysroot.sh`, set the `IP` to the ip of your Raspberry Pi or to the hostname and specify the `USER`.
Then run it.

### Setup the client

The client is written in python, so that has to be installed.

Then in the client directory run `python -m venv venv` and `source venv/bin/activate`.
Then install all needed packages with pip:

    - Matplotlib: `pip install matplotlib`
    - Pandas: `pip install pandas`
    - ZeroMQ: `pip install zmq`
    - Protocol Buffers: `pip install protobuf==<version>`
        The correct version can be found when installing the protobuf compiler with
        `apt install protobuf-compiler` on the Raspberry Pi and running `protoc --version`.

### Configure scripts

- `build.sh`: Needs a `protoc` with the correct version in a directory named `helper_programs`.
    The correct version can be found when installing the protobuf compiler with
    `apt install protobuf-compiler` on the Raspberry Pi and running `protoc --version`.
    Then search [this](https://github.com/protocolbuffers/protobuf/tags) for the correct version.
- `deploy_raspi.sh`: Set the `IP` to the ip of your Raspberry Pi or to the hostname and specify the `USER`.
    Then set the `REMOTE_DIRECTORY` to an existing directory in the users home (relative path).
- `run.sh`: Check that the `venv` exists.

### Run the program

Use `run.sh`!
