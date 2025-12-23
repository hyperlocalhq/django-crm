#!/usr/bin/env zsh

CURRENT_DIR=$(dirname "$0")
cd $CURRENT_DIR
./full_restore_aidas.sh -e production
