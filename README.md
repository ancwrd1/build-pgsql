# Bash script to build and package the portable PostgreSQL binaries for Linux

## Introduction

This script will build the specified PostgreSQL version for the target triple and package it
 into the tarball. A minimum set of options is selected: openssl and libedit.
 

No existing dependencies are required; the script will download and build them automatically. All dependencies are linked
 statically. Executables are created with `$ORIGIN/../lib` rpath and so are portable.

## Usage

### Host compilation

If you have a cross compiler installed for the target triple run the build-postgresql.sh as follows:

```bash
./build-postgresql.sh <triple> <version>
```

If `zig` compiler is installed it is also possible to use "zig cc" cross compiler to build for specific
 target and GLIBC version.
 
Examples:

```bash
./build-postgresql.sh aarch64-unknown-linux-gnu 17.2
./build-postgresql.sh x86_64-unknown-linux-gnu 17.2
CC="zig cc --target=x86_64-linux-gnu.2.17" ./build-postgresql.sh x86_64-unknown-linux-gnu 17.2
```

## Packaging

Resulting tarball is generated under `dist/<triple>` directory.
