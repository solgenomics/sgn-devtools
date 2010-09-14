#!/bin/sh
export LANG=C;
list=`editfind "$@"`;
if [ "x$list" != "x" ]; then
    $EDITOR $list &
fi

