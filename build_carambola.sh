#!/bin/sh

# Assumes we are sitting in ~/build/src ...

~/freebsd-wifi-build/build/bin/build carambola2  buildworld buildkernel 
~/freebsd-wifi-build/build/bin/build carambola2  installworld installkernel distribution

PACKAGES="sysutils/less net/tcpdump"

X_STAGING_FSROOT=../mfsroot/carambola2
X_DESTDIR=../root/mips
${INSTALL_PROG} ${X_DESTDIR}/bin/date ${X_STAGING_FSROOT}/bin/
${INSTALL_PROG} ${X_DESTDIR}/bin/kill ${X_STAGING_FSROOT}/bin/
# ${INSTALL_PROG} ${X_DESTDIR}/sbin/bsdbox ${X_STAGING_FSROOT}/bin/
${INSTALL_PROG} ${X_DESTDIR}/sbin/sha1 ${X_STAGING_FSROOT}/sbin/
${INSTALL_PROG} ${X_DESTDIR}/sbin/sha256 ${X_STAGING_FSROOT}/sbin/
${INSTALL_PROG} ${X_DESTDIR}/sbin/sha512 ${X_STAGING_FSROOT}/sbin/
${INSTALL_PROG} ${X_DESTDIR}/sbin/pfctl ${X_STAGING_FSROOT}/sbin/
${INSTALL_PROG} ${X_DESTDIR}/sbin/pflogd ${X_STAGING_FSROOT}/sbin/


DOWNLOADS=../ports-distfiles
X_DESTDIR=../ports/install
for p in $PACKAGES ; do

  make PREFIX=${X_DESTDIR} WRKDIRPREFIX=../ports/work TARGET=mips TARGET_ARCH=mips TARGET_CPUTYPE=mips32 \
              NO_PKG_REGISTER=1 DB_FROM_SRC=1 BUILD_FLAGS=NO_CLEAN=1 \
              PORT_DBDIR=../ports/db INSTALL_AS_USER=yes -DDISABLE_VULNERABILITIES \
              DISTDIR=${DOWNLOADS} install

done

~/freebsd-wifi-build/build/bin/build carambola2  mfsroot

INSTALL_PROG=install
${INSTALL_PROG} ${X_DESTDIR}/bin/less ${X_STAGING_FSROOT}/bin/


~/freebsd-wifi-build/build/bin/build carambola2  fsimage uboot
