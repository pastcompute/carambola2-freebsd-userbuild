# Introduction

Some scripts for tweaking freebsd-wifi-build for the Carambola2, in particular as a normal user instead of root.

* Tested build using FreeBSD release/10.0.0 inside a Linux debian wheezy amd64 hosted qemu-kvm machine.
* Tested for destination FreeBSD release/10.1.0
* I also had it working with destination release/10.0.0 but that was early on so I dont know if it will still work.

# Instructions

0. Setup stuff

    $SUDO pkg install gmake bison dialog4ports git wget subversion fakeroot lzma uboot-mkimage libtool

1. Create a working directory.

    mkdir whatever && cd whatever

2. Clone this repository

    git clone carambola2-freebsd-userbuild

3. Clone freebsd-wifi-build

    git clone https://github.com/freebsd/freebsd-wifi-build.git

I also had to hack freebsd-wifi-build to enable building as a normal user.

In file `build/bin/build_freebsd`:
    
		@@ -91,7 +103,7 @@ while [ "x$1" != "x" ]; do
		 
				    X_DESTDIR_LINE=""
				    if [ "$1" = "installworld" -o "$1" = "installkernel" -o "$1" = "distribution" ]; then
		-               X_DESTDIR_LINE="DESTDIR=${X_DESTDIR}"
		+               X_DESTDIR_LINE="DESTDIR=${X_DESTDIR} -DNO_ROOT"
				    fi

And to get simplify working with tftp, I cheated and did `chmod 777 /tftpboot`, which also required:

		@@ -111,8 +123,8 @@ while [ "x$1" != "x" ]; do
				    || exit 1
				    if [ "$1" = "installkernel" ]; then
				            echo "*** Copying kernel to /tftpboot/kernel.${KERNCONF}"
		-               cp ${X_KERNEL} /tftpboot/kernel.${KERNCONF}
		-               cp ${X_KERNEL}.symbols /tftpboot/kernel.${KERNCONF}.symbols
		+               cp -f ${X_KERNEL} /tftpboot/kernel.${KERNCONF}
		+               cp -f ${X_KERNEL}.symbols /tftpboot/kernel.${KERNCONF}.symbols

Early I I had to make the following change as well, this may be redundant with 10.1.0 I havent tried reverting.

		@@ -47,7 +47,8 @@ if [ "x${LOCAL_TOOL_DIRS}" != "x" ]; then
		 fi
		 
		 # Create a make.conf
		-echo "MALLOC_PRODUCTION=" > ${X_DESTDIR}/../make.conf.${BUILDNAME}
		+echo > ${X_DESTDIR}/../make.conf.${BUILDNAME}

4. Clone freebsd, or just get the release sources. One way to do this is

    wget https://github.com/freebsd/freebsd/archive/release/10.1.0.zip
    unzip 10.1.0.zip

5. Generate a ports working area

    mkdir portsnap ports ports-distfiles
    portsnap -d portsnap fetch
    portsnap -p ports extract

6. Hack configurations, for example `freebsd/sys/mips/conf/CARAMBOLA2` to enable MSDOSFS

Instead of modifying freebsd-wifi-build I hacked my own changes into the firmware directory tree inside `build_carambola.sh`

You can also edit the script to add extra ports.

7. Run `scripts/build_carambola.sh`

    carambola2-freebsd-userbuild/build_carambola.sh

This generates a single flashable file in the end to make life easier inside u-boot.

Which means you can do the following once:

    setenv ipaddr 192.168.0.244
    setenv serverip 192.168.0.107
    saveenv

Then you can simply hit the reset button on the carambola to test a new firmware image:

    erase 0x9f050000 +0xd90000
    tftpboot 0x80050000 kernel.CARAMBOLA2.lzma.flash
    cp.b 0x80050000 0x9f050000 $filesize
    reset

# To build against a different FreeBSD source (for example)

     SOURCES=freebsd-release-10.0.0 carambola2-freebsd-userbuild/build_carambola.sh

# Issues I discovered

The 'stock' Carambola2 OpenWRT build from 8devices (and the trunk OpenWRT) configures the ethernet ports backwards from
FreeBSD at least through to 10.1.0, and if my memory serves me right, independently.

It appears that there are changes in svn_head that may support this mode, but I am still understand where the difference is,
whether it is a switch configuration thing in OpenWRT or a kernel / chip configuration difference.

What I have worked out, is that https://github.com/pastcompute/freebsd/commit/d5c874addf86f765e52c446893d83d14e9cca9cd appears
to do the same as this suggestion for OpenWRT to allow the opposite, http://patchwork.openwrt.org/patch/6217/, but I am still
trying to get svn_head to behave the same as OpenWRT with this.

When I build against svnhead I was able to swap arge0 and arge1 so they now are the same way around as openWRT
I think it is working in routed mode with the correct hints but I need to do further testing when I get some time.
