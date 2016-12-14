#!/bin/bash

set -e

libssl1.0.0_update() {
    mkdir -p $NEW_DIR/usr/$ARCHDIR/lib/
    cp -a $ORIG_DIR/usr/lib/$ARCHDIR/openssl-1.0.0/engines/ $NEW_DIR/usr/$ARCHDIR/lib/
}

libc_update() {
    mkdir -p $NEW_DIR/usr/$ARCHDIR/lib/
    cp -a $ORIG_DIR/lib/$ARCHDIR/ld-linux.so.* $NEW_DIR/usr/$ARCHDIR/lib/
}

IN_FILE=$(readlink -f $1)
IN=$(basename $IN_FILE .deb)

die () {
    printf >&2 '%s\n' "$*"
    exit 1
}

# split the given .deb into name, version and arch
echo $IN | while IFS=_ read -r name version arch; do
    NAME=$name
    VERSION=$version
    ARCH=$arch

    OUT=${NAME}-${ARCH}-cross_${VERSION}_all
    OUT_FILE=$(pwd)/$OUT.deb

    case $ARCH in
	armhf)
	    ARCHDIR=arm-linux-gnueabihf
	    ;;
	armel)
	    ARCHDIR=arm-linux-gnueabi
	    ;;
	*)
	    die "unknown arch"
	    ;;
    esac

    dpkg-cross -b -a $ARCH -M -A $IN_FILE

    tempdir=$(mktemp -d)
    ORIG_DIR=$tempdir/orig
    NEW_DIR=$tempdir/new
    mkdir $ORIG_DIR $NEW_DIR

    dpkg -x $IN_FILE $ORIG_DIR

    ${name}_update

    # update data.tar with NEW_DIR
    # 1. extract data.tar in OUTFILE
    # 2. add all files in NEW_DIR to data.tar
    # 3. put data.tar back into OUTFILE
    (cd $tempdir
     ar x $OUT_FILE data.tar.gz
     gzip -d data.tar.gz
     data=$(readlink -f data.tar)
     (cd $NEW_DIR; fakeroot tar rf $data .)
     gzip -9 data.tar
     ar r $OUT_FILE data.tar.gz
    )
    # rm -rf $tempdir
done
