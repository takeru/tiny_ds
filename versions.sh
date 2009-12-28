#!/bin/bash -v
# ./versions.sh > versions.txt 2>&1
uname -a
date +"%Y/%m/%d %H:%M:%S"
#-----------------------------
jruby -v
#-----------------------------
java -version
#-----------------------------
gem list | grep -E '(appengine|bundler)'
#-----------------------------
jgem list
#-----------------------------
