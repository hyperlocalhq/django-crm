#!/usr/bin/env bash

rsync --archive --compress --partial --progress --ignore-existing staging_museumsportal:/var/webapps/museumsportal/media/slideshows/ ../../media/slideshows/
