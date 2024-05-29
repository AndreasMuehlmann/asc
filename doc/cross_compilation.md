# Cross Compilation

The cross compilation uses a cross compilation toolchain built with Crosstool-ng.

The right cross compilation tuple for the Raspberry Pi architecture is `arm-linux-unkown-gnueabihf`.
That stands for the architecture `arm`, the kernel `linux`, the operating system `unknown`,
the application binary interface `GNU Embedded Application Binary Interface` and `hard float`
(floating point math is implemented in hardware).

A sysroot enables the host system to use libraries installed on the raspberry pi for compilation.

`usr/include/arm-linux-gnueabihf/` has to be added as include path and 
`usr/lib/arm-linux-gnueabihf/` as library path because they are not found automatically in the sysroot.

They also have to be added as `rpath-link` and `rpath` to solve problems while linking.
They `-B` option also has to be specified otherwise some files are not found.

See [controller/CMakeLists.txt](../controller/CMakeLists.txt)
