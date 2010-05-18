libdir=$1
if [ "x$libdir" = "x" ]; then
    libdir="/data/local/cxgn/perl"
fi
perl -Mlocal::lib=$libdir | tee /tmp/use_local_lib_sh;
. /tmp/use_local_lib_sh;
rm /tmp/use_local_lib_sh;
