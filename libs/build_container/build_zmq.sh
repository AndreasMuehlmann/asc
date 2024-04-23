pt-get install -y build-essential pkg-config libtool autoconf automake uuid-dev libsodium-dev libssl-dev
git clone --depth 1 https://github.com/raspberrypi/tools rpi-tools
TOOLCHAIN_HOST="arm-linux-gnueabihf"
TOOLCHAIN_PATH="$PWD/rpi-tools/arm-bcm2708/arm-rpi-4.9.3-linux-gnueabihf/bin"
CPP="${TOOLCHAIN_PATH}/${TOOLCHAIN_HOST}-cpp"
CC="${TOOLCHAIN_PATH}/${TOOLCHAIN_HOST}-gcc"
CXX="${TOOLCHAIN_PATH}/${TOOLCHAIN_HOST}-g++"
LD="${TOOLCHAIN_PATH}/${TOOLCHAIN_HOST}-ld"
AS="${TOOLCHAIN_PATH}/${TOOLCHAIN_HOST}-as"
AR="${TOOLCHAIN_PATH}/${TOOLCHAIN_HOST}-ar"
RANLIB="${TOOLCHAIN_PATH}/${TOOLCHAIN_HOST}-ranlib"
SYSROOT=$PWD/rpi-tools/arm-bcm2708/arm-rpi-4.9.3-linux-gnueabihf/arm-linux-gnueabihf/sysroot
CFLAGS+="--sysroot=${SYSROOT}"
CPPFLAGS+="--sysroot=${SYSROOT}"
CXXFLAGS+="--sysroot=${SYSROOT}"
CONFIG_OPTS=()
CONFIG_OPTS+=("CFLAGS=${CFLAGS}")
CONFIG_OPTS+=("CPPFLAGS=${CPPFLAGS}") CONFIG_OPTS+=("CXXFLAGS=${CXXFLAGS}")
CONFIG_OPTS+=("LDFLAGS=${LDFLAGS}") CONFIG_OPTS+=("PKG_CONFIG_DIR=")
CONFIG_OPTS+=("--host=${TOOLCHAIN_HOST}")
CONFIG_OPTS+=("CPP=${CPP}")
CONFIG_OPTS+=("CC=${CC}")
CONFIG_OPTS+=("CXX=${CXX}")
CONFIG_OPTS+=("LD=${LD}")
CONFIG_OPTS+=("AS=${AS}")
CONFIG_OPTS+=("AR=${AR}")
CONFIG_OPTS+=("RANLIB=${RANLIB}")
BUILD_PREFIX=$PWD/tmp
CONFIG_OPTS+=("--prefix=${BUILD_PREFIX}")
CONFIG_OPTS+=("PKG_CONFIG_DIR=")
CONFIG_OPTS+=("PKG_CONFIG_LIBDIR=${SYSROOT}/usr/lib/arm-linux-gnueabihf/pkgconfig:${SYSROOT}/usr/share/pkgconfig")
CONFIG_OPTS+=("PKG_CONFIG_SYSROOT=${SYSROOT}")
CONFIG_OPTS+=("PKG_CONFIG_PATH=${BUILD_PREFIX}/lib/pkgconfig")

git clone --depth 1 https://github.com/zeromq/libzmq.git
pushd libzmq
(
    ./autogen.sh &&
    ./configure "${CONFIG_OPTS[@]}" &&
    make -j4 &&
    make install
) || exit 1
popd

git clone --depth 1 https://github.com/zeromq/czmq.git
pushd czmq
(
    ./autogen.sh &&
    ./configure "${CONFIG_OPTS[@]}" &&
    make -j4
    make install
) || exit 1
popd
