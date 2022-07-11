# shifupool

by CoinFuMasterShifu

The `c++` directory contains the C++ backend server that signs transactions/creates blocks.

* It has to be compiled using meson+ninja: use the command `meson <path of c++ directory> <build directory>` to create a build directory, then `cd` into the build directory and build the backend server using the command `ninja`. In the `src` subdirectory of the `<build directory>` there should exist an executable file `miningproblem` which is the backend server.
* It needs to run while the pool is running. Otherwise the pool cannot not operate.
* After you started the backend server (for example within a screen session) you can start the pool, see the readme file in the `shifupool` directory.

## additional readme

bin/container up
bin/container shell
  ./build.sh
