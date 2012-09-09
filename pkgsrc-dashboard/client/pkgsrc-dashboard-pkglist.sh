#! /bin/sh
server=$1
hostkey=$2
pkgpath=`pkg_admin config-var PKG_PATH`

pkg_info -a | awk '{ print $1 }' | xargs -I{} ftp -o - ${server}/pkglist.pl?hostkey=${hostkey}\&pkgpath=${pkgpath}\&pkgname={}
