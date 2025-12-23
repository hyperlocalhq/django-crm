#!/usr/bin/env bash
pg_dump --format=c --compress=9 --file=museumsportal.backup --no-owner museumsportal
