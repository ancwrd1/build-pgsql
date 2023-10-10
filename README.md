# Bash script to build and package the PostgreSQL binaries for Linux

## Introduction

This script will build the specified PostgreSQL version for the target triple and package it
 into the tarball. A minimum set of options is selected: openssl and libedit.

No existing dependencies are required; the script will download and build them automatically. All dependencies are linked
 statically. Executables are created with $ORIGIN/../lib rpath.

## Usage

### Host compilation

If you have a cross compiler installed for the target triple run the build-postgresql.sh as follows:

```bash
./build-postgresql.sh <triple> <version>
```

Examples:

```bash
./build-postgresql.sh aarch64-unknown-linux-gnu 16.0
./build-postgresql.sh x86_64-unknown-linux-gnu 16.0
```

### Docker-based compilation

There are two scripts included which use `dockcross` images to build for x86_64 (GLIBC 2.17) and AARCH64 targets:

```bash
./scripts/dockcross-manylinux2014-x64 ./build-postgresql.sh x86_64-redhat-linux-gnu 16.0
./scripts/dockcross-manylinux2014-aarch64 ./build-postgresql.sh aarch64-unknown-linux-gnu 16.0
```

## Packaging

Resulting tarball is generated under `dist/<triple>` directory.
