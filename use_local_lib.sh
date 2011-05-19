libdir=$1
if [ "x$libdir" = "x" ]; then
    libdir="$HOME/cxgn/local-lib"
fi
perl -I$libdir/lib/perl5 -Mlocal::lib=$libdir | tee /tmp/use_local_lib_sh;
. /tmp/use_local_lib_sh;
rm /tmp/use_local_lib_sh;
