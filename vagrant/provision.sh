#!/bin/bash

set -euf -o pipefail

apt-get update
apt-get -y upgrade

# Install build essential and debugger
apt-get install -y build-essential gdb valgrind
