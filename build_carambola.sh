#!/bin/sh
#
# Optional options: clean | noworld nokernel nodist noports
#
# Assumes we are sitting in ~/build, run as path/to/build_carambola.sh
#
# Features:
#
#   less vi pf pw dhclient ldd netcat scp rsync tcpdump
#
#
# Carambola2 specific quirks:
#
# * arge0/1 switched instead of routed when both arge0 and arge1 enabled;
#   we fix that by using the kernel from svnhead and overriding the phys in CARAMBOLA2.hints
#   and by swapping which ports are arge0/arge1
# * extra GPIO pins -- need to edit CARAMBOLA2.hints
# * waring 'sysctl: unknown oid 'dev.ath.1.txq_mcastq_maxdepth': No such file or directory' comment line out in freebsd-wifi-build
# * serial terminal gets capped at 25 lines high with programs like less in the serial port
# * Carambola passes uboot args into expected place so uncomment #ifdef in ar71xx_machdep.c and fix the loops
#
# Setting up to build ports (at least, those that are buildable)
#
#     mkdir portsnap ports
#     portsnap -d portsnap fetch
#     portsnap -d portsnap -p ports extract # once
#     portsnap -d portsnap -p ports update # thereafter
#
# I might use git annex locally to manage downloads
#
#
# Build dependencies include:
#
#     gmake bison dialog4ports git wget subversion fakeroot lzma uboot-mkimage libtool
#
# Optional useful host things:
#
#     vim screen less tcpdump gedit bash xorg urwfonts xdm openbox gedit rsync
#

set -e
X_SELF_DIR=`pwd`
FWB=${X_SELF_DIR}/freebsd-wifi-build

SOURCES_KERNEL=${SOURCES:-${X_SELF_DIR}/freebsd-git}
SOURCES=${SOURCES:-${X_SELF_DIR}/freebsd-release-10.1.0}

# For use with tweaked freebsd-wifi-build
export X_BUILDASUSER=YES
export X_SKIP_MORE_STUFF=YES
export X_FORCE_TFTPCP=YES

X_STAGING_FSROOT=${X_SELF_DIR}/mfsroot/carambola2
X_DESTDIR=${X_SELF_DIR}/root/mips

X_DOWNLOADS=${X_SELF_DIR}/ports-distfiles
X_PORTS=${X_SELF_DIR}/ports
X_PORTSBUILD=${X_SELF_DIR}/ports-build
X_FROM=${X_PORTSBUILD}/staging/target
X_CROSSPATH=${X_SELF_DIR}/obj/mips/mips.mips/${SOURCES}/tmp/usr/bin
X_FAKEROOT=fakeroot

if [ "x$1" = "xclean" ] ; then
  rm -rf obj root mfsroot* tmp
  scripts/clean_ports.sh
  exit 0
fi

OPT_WORLD=yes
OPT_KERNEL=yes
OPT_PORTS=yes
OPT_PORTS_INSTALL=yes
OPT_DIST=yes
while [ "x$1" != "x" ]; do
  if [ "x$1" = "xnoworld" ] ; then OPT_WORLD=no ; shift ; fi
  if [ "x$1" = "xnokernel" ] ; then OPT_KERNEL=no ; shift ; fi
  if [ "x$1" = "xnoports" ] ; then OPT_PORTS=no ; shift ; fi
  if [ "x$1" = "xnodist" ] ; then OPT_DIST=no ; shift ; fi
done

if [ $OPT_WORLD = yes ] ; then
  cd ${SOURCES}
  ${FWB}/build/bin/build carambola2  buildworld
fi

if [ $OPT_KERNEL = yes ] ; then
  cd ${SOURCES_KERNEL}
  if [ $OPT_WORLD = yes ] ; then
    if [ "${SOURCES_KERNEL}" != "${SOURCES}" ] ; then
      ${FWB}/build/bin/build carambola2  buildworld
    fi
  fi
  ${FWB}/build/bin/build carambola2  buildkernel
fi

# ------------------------------------------------------------------------------------------------
# Cross build a port method #1.
# Problems:
#   We hack this by calling configure without the cross compiler.
#   This works for ports that dont check for correct cross compiler in configure stage.
#   This lets us build ports that run host tests during the configure stage and use CC from the PATH in the build stage.
#   It is currently also necessary to get dialog4ports to work correctly, also, things can break if we were to run make
#   clean in those locations.
#   Doesnt work where package needs '--host=arch --build=arch'.
#
# * Assumes in ports directory
# * $1 == group/port
#
build_port()
{
# We needed fakeroot for `mtree`
# PORTSDIR=${X_PORTS}                                   # <-- ./ports           <-- generated by portsnap
# DISTDIR=${X_DOWNLOADS}                                # <-- ./ports-distfiles <-- downloaded sources
# PORT_DBDIR=${X_PORTSBUILD}/db                         # <-- ./ports-build/db  <-- config
# WRKDIR=${X_PORTSBUILD}/w/$PACKAGE/work                # <-- ./ports-build/w/$PACKAGE/work
# STAGEDIR=${X_PORTSBUILD}/staging                      # <-- ./ports-build/staging
# PREFIX=/target                                        # <-- ./ports-build/staging/target/
# NO_DEPENDS=1 NO_PKG_REGISTER=1 DB_FROM_SRC=1          # <-- depends check looks for libs.so's in wrong place

  echo Package: $1
  cd $1
  ${X_FAKEROOT} make DISABLE_MAKE_JOBS=yes \
        PORTSDIR=${X_PORTS} \
        DISTDIR=${X_DOWNLOADS} \
        PORT_DBDIR=${X_PORTSBUILD}/db \
        WRKDIR=${X_PORTSBUILD}/w/${WORKING}/work \
        STAGEDIR=${X_PORTSBUILD}/staging \
        PREFIX=/target \
        NO_DEPENDS=1 NO_PKG_REGISTER=1 DB_FROM_SRC=1 BUILD_FLAGS=NO_CLEAN=1 \
        -DDISABLE_VULNERABILITIES \
          configure
  PATH=${X_CROSSPATH}:${PATH} ${X_FAKEROOT} make DISABLE_MAKE_JOBS=yes \
        PORTSDIR=${X_PORTS} \
        DISTDIR=${X_DOWNLOADS} \
        PORT_DBDIR=${X_PORTSBUILD}/db \
        WRKDIR=${X_PORTSBUILD}/w/${WORKING}/work \
        STAGEDIR=${X_PORTSBUILD}/staging \
        PREFIX=/target \
        NO_DEPENDS=1 NO_PKG_REGISTER=1 DB_FROM_SRC=1 BUILD_FLAGS=NO_CLEAN=1 \
        -DDISABLE_VULNERABILITIES \
          install
  cd $OLDPWD
}

if [ $OPT_PORTS = yes ] ; then
  # This might not work in all cases, especially if SOURCES is a relative path
  # We also get some pain because /usr/home ==> /home yet it doesnt WTF (pwd --> /home/...)
  # Workaround this for now:
  ln -sf ${X_SELF_DIR}/obj/mips/mips.mips/usr/home ${X_SELF_DIR}/obj/mips/mips.mips/home

  echo "Building PORTS using CROSS toolchain `${X_CROSSPATH}/cc -dumpmachine`"
  cd ${X_PORTS}
  build_port  sysutils/less
  build_port  net-mgmt/libsmi
  build_port  net/libpcap
  build_port  net/tcpdump
  build_port  net/netcat
  build_port  net/rsync              # rsync needs scp installed
#  build_port  net/dhcpcd
# Breakage: ftp/curl
# Breakage: ftp/wget
# Breakage: ftp/screen
# Breakage: sysutils/screen-legacy
# Breakage: i2c-tools
fi

if [ $OPT_WORLD = yes ] ; then
  cd ${SOURCES}
  ${FWB}/build/bin/build carambola2  installworld
fi
if [ $OPT_KERNEL = yes ] ; then
  cd ${SOURCES_KERNEL}
  ${FWB}/build/bin/build carambola2  installkernel
fi
if [ $OPT_DIST = yes ] ; then
  cd ${SOURCES}
  ${FWB}/build/bin/build carambola2  distribution
fi

cd ${X_SELF_DIR}
rm -rf mfsroot

cd ${SOURCES}
${FWB}/build/bin/build carambola2 mfsroot || true


#INSTALL_PROG="fakeroot install -p -s " 
# install is stupid it wont copy a symlink as a symlink
INSTALL_PROG="${X_FAKEROOT} cp -fPRpv "
${INSTALL_PROG} ${X_SELF_DIR}/scripts/files/rc.conf ${X_STAGING_FSROOT}/c/etc/cfg/

# Features:
# less vi pf pw dhclient ldd netcat scp rsync tcpdump

cd ${X_SELF_DIR}

# This will get replaced by login.conf in /c/etc but should fix the 'daemon' warning
# (FIXES) login_getclass: unknown class 'daemon' _before_ populating var
${INSTALL_PROG} ${X_DESTDIR}/etc/login.conf ${X_STAGING_FSROOT}/etc
# Our version removes 'russians' and sets the coredump to 0
${INSTALL_PROG} scripts/files/login.conf ${X_STAGING_FSROOT}/c/etc/

# ${INSTALL_PROG} ${X_DESTDIR}/sbin/bsdbox ${X_STAGING_FSROOT}/bin/
${INSTALL_PROG} ${X_DESTDIR}/bin/kill ${X_STAGING_FSROOT}/sbin/
${INSTALL_PROG} ${X_DESTDIR}/bin/date ${X_STAGING_FSROOT}/bin/
${INSTALL_PROG} ${X_DESTDIR}/usr/bin/which ${X_STAGING_FSROOT}/usr/bin/
${INSTALL_PROG} ${X_DESTDIR}/usr/bin/sed ${X_STAGING_FSROOT}/usr/bin/
${INSTALL_PROG} ${X_DESTDIR}/usr/bin/od ${X_STAGING_FSROOT}/usr/bin/
${INSTALL_PROG} ${X_DESTDIR}/usr/sbin/watch ${X_STAGING_FSROOT}/usr/sbin/
${INSTALL_PROG} ${X_DESTDIR}/usr/sbin/i2c ${X_STAGING_FSROOT}/usr/sbin/
${INSTALL_PROG} ${X_DESTDIR}/sbin/sha1 ${X_STAGING_FSROOT}/sbin/
${INSTALL_PROG} ${X_DESTDIR}/sbin/sha256 ${X_STAGING_FSROOT}/sbin/
${INSTALL_PROG} ${X_DESTDIR}/sbin/sha512 ${X_STAGING_FSROOT}/sbin/

${INSTALL_PROG} ${X_DESTDIR}/etc/dhclient.conf ${X_STAGING_FSROOT}/c/etc/
${INSTALL_PROG} ${X_DESTDIR}/sbin/dhclient ${X_STAGING_FSROOT}/sbin/
${INSTALL_PROG} ${X_DESTDIR}/sbin/dhclient-script ${X_STAGING_FSROOT}/sbin/
${INSTALL_PROG} ${X_DESTDIR}/etc/rc.d/dhclient ${X_STAGING_FSROOT}/c/etc/rc.d/

${INSTALL_PROG} ${X_DESTDIR}/usr/sbin/pw ${X_STAGING_FSROOT}/usr/sbin/

${INSTALL_PROG} ${X_DESTDIR}/sbin/pfctl ${X_STAGING_FSROOT}/sbin/
${INSTALL_PROG} ${X_DESTDIR}/sbin/pflogd ${X_STAGING_FSROOT}/sbin/

${INSTALL_PROG} ${X_DESTDIR}/usr/bin/ldd ${X_STAGING_FSROOT}/usr/bin/

if [ $OPT_PORTS_INSTALL = yes ] ; then
	${INSTALL_PROG} ${X_FROM}/bin/less ${X_STAGING_FSROOT}/bin/
	${INSTALL_PROG} ${X_DESTDIR}/lib/libncurses.so* ${X_STAGING_FSROOT}/lib/
	${INSTALL_PROG} ${X_DESTDIR}/usr/bin/vi ${X_STAGING_FSROOT}/usr/bin/

	${INSTALL_PROG} ${X_FROM}/bin/netcat ${X_STAGING_FSROOT}/sbin/

	${X_FAKEROOT} install -d ${X_STAGING_FSROOT}/usr/lib/private/
	${INSTALL_PROG} ${X_DESTDIR}/usr/lib/private/libssh.so* ${X_STAGING_FSROOT}/usr/lib/private/
	${INSTALL_PROG} ${X_DESTDIR}/usr/lib/private/libldns.so* ${X_STAGING_FSROOT}/usr/lib/private/
	${INSTALL_PROG} ${X_DESTDIR}/usr/bin/scp ${X_STAGING_FSROOT}/usr/bin/
	${INSTALL_PROG} ${X_DESTDIR}/usr/bin/ssh ${X_STAGING_FSROOT}/usr/bin/
	${INSTALL_PROG} ${X_FROM}/bin/rsync ${X_STAGING_FSROOT}/sbin/

	${INSTALL_PROG} ${X_FROM}/sbin/tcpdump ${X_STAGING_FSROOT}/sbin/
	${INSTALL_PROG} ${X_FROM}/lib/libsmi.so* ${X_STAGING_FSROOT}/lib/
	${INSTALL_PROG} ${X_FROM}/lib/libpcap.so* ${X_STAGING_FSROOT}/lib/      # <-- Note, also in the base as libcpap.so.8  so whats the diff?
	echo 'mkdir /var/run/tcpdump' >> ${X_STAGING_FSROOT}/c/etc/rc.ports
fi

# Disable telnetd for security reasons
sed -e '/^telnet/d' -i "" ${X_STAGING_FSROOT}/c/etc/inetd.conf
rm ${X_STAGING_FSROOT}/usr/libexec/telnetd

# Configure some actual passwords
# Note: requires vt100 in login.conf
${X_FAKEROOT} pwd_mkdb -d ${X_STAGING_FSROOT}/c/etc ${X_STAGING_FSROOT}/c/etc/master.passwd
echo root | ${X_FAKEROOT} pw -V ${X_STAGING_FSROOT}/c/etc usermod root -h0 -c 'Here\ Lies\ Root' -C ${X_STAGING_FSROOT}/c/etc/pw.conf
echo user | ${X_FAKEROOT} pw -V ${X_STAGING_FSROOT}/c/etc usermod user -h0 -c -C ${X_STAGING_FSROOT}/c/etc/pw.conf
rm ${X_STAGING_FSROOT}/c/etc/spwd.db ${X_STAGING_FSROOT}/c/etc/pwd.db

cd ${SOURCES}
${FWB}/build/bin/build carambola2 fsimage
${FWB}/build/bin/build carambola2 uboot

# Build a combined flash image. Kernel is first 2MB followed by compressed mfs image
X_FLASH=/tftpboot/kernel.CARAMBOLA2.lzma.flash
dd if=/dev/zero bs=$(( 0x200000 )) count=1 of=${X_FLASH}
dd if=/tftpboot/kernel.CARAMBOLA2.lzma.uImage of=${X_FLASH} conv=notrunc
dd if=/tftpboot/mfsroot-carambola2.img.ulzma >> ${X_FLASH}

ls -l ${X_FLASH}

