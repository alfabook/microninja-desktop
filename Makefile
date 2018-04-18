#
# kano-desktop Makefile
#
# Copyright (C) 2015 Kano Computing Ltd.
# License: http://www.gnu.org/licenses/gpl-2.0.txt GNU General Public License v2
#
# Copyright (C) 2016 Alfabook srl
# License: http://www.gnu.org/licenses/gpl-2.0.txt GNU General Public License v2
# rebadged with microninja
#



all: microninja-mount-trigger.target

microninja-mount-trigger.target:
	cd microninja-mount-trigger && make all
