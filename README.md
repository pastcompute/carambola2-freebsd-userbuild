# Introduction

Some scripts for tweaking freebsd-wifi-build for the Carambola2.
This project initially started because I wanted to build as a normal user instead of root, however has evolved into a 
more general automation script for my purpose, as user build is becoming the default mode for freebsd-wifi-build.

* Tested build host using FreeBSD release/10.0.0 inside a Linux debian wheezy amd64 hosted qemu-kvm machine.
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


To get simplify working with tftp, I cheated and did `chmod 777 /tftpboot`, which also required:

		@@ -111,8 +123,8 @@ while [ "x$1" != "x" ]; do
				    || exit 1
				    if [ "$1" = "installkernel" ]; then
				            echo "*** Copying kernel to /tftpboot/kernel.${KERNCONF}"
		-               cp ${X_KERNEL} /tftpboot/kernel.${KERNCONF}
		-               cp ${X_KERNEL}.symbols /tftpboot/kernel.${KERNCONF}.symbols
		+               cp -f ${X_KERNEL} /tftpboot/kernel.${KERNCONF}
		+               cp -f ${X_KERNEL}.symbols /tftpboot/kernel.${KERNCONF}.symbols

This may become unnecessary in due course once https://github.com/freebsd/freebsd-wifi-build/issues/4 is resolved.

4. Clone freebsd, or just get the release sources. One way to do this is

    wget https://github.com/freebsd/freebsd/archive/release/10.1.0.zip
    unzip 10.1.0.zip

5. Generate a ports working area

    mkdir portsnap ports ports-distfiles
    portsnap -d portsnap fetch
    portsnap -d portsnap -p ports extract

6. Hack configurations, for example `freebsd-release-10.1.0/sys/mips/conf/CARAMBOLA2` to enable MSDOSFS

Instead of modifying freebsd-wifi-build I hacked my own changes into the firmware directory tree inside `build_carambola.sh`

You can also edit the script to add extra ports.

I did also modify freebsd-wifi-scripts to remove more stuff from the world build:

		+echo 'WITHOUT_GAMES="YES"' >> ${X_DESTDIR}/../src.conf.${BUILDNAME}
		+echo 'WITHOUT_DOCS="YES"' >> ${X_DESTDIR}/../src.conf.${BUILDNAME}
		+echo 'WITHOUT_MAN="YES"' >> ${X_DESTDIR}/../src.conf.${BUILDNAME}
		+echo 'WITHOUT_INFO="YES"' >> ${X_DESTDIR}/../src.conf.${BUILDNAME}
		+echo 'WITHOUT_LOCALES="YES"' >> ${X_DESTDIR}/../src.conf.${BUILDNAME}
		+echo 'WITHOUT_NLS="YES"' >> ${X_DESTDIR}/../src.conf.${BUILDNAME}
		+echo 'WITHOUT_EXAMPLES="YES"' >> ${X_DESTDIR}/../src.conf.${BUILDNAME}
		+echo 'WITHOUT_ZFS="YES"' >> ${X_DESTDIR}/../src.conf.${BUILDNAME}
		+echo 'WITHOUT_RCS="YES"' >> ${X_DESTDIR}/../src.conf.${BUILDNAME}
		+echo 'WITH_INSTALL_AS_USER="YES"' >> ${X_DESTDIR}/../src.conf.${BUILDNAME}

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

## Ignored uboot environment

FreeBSD kernel ignores the uboot environment. 
I worked out how to fix this:

    diff --git a/sys/mips/atheros/ar71xx_machdep.c b/sys/mips/atheros/ar71xx_machdep.c
    index 52f938c..5422324 100644
    --- a/sys/mips/atheros/ar71xx_machdep.c
    +++ b/sys/mips/atheros/ar71xx_machdep.c
    @@ -303,18 +303,33 @@ platform_start(__register_t a0 __unused, __register_t a1 __unused,
            }
            else
                    printf ("argv is invalid");
    +
            printf("\n");
     
            printf("Environment:\n");
            if (MIPS_IS_VALID_PTR(envp)) {
    +#ifndef        AR71XX_ENV_UBOOT
                    for (i = 0; envp[i]; i+=2) {
                            printf("  %s = %s\n", envp[i], envp[i+1]);
                            kern_setenv(envp[i], envp[i+1]);
                    }
    +#else
    +               for (i = 0; envp[i]; i++) {
    +                       char *sep = strchr(envp[i], '=');
    +                       *sep = 0;
    +                       printf("  %s = %s\n", envp[i], sep+1);
    +                       kern_setenv(envp[i], sep+1);
    +               }
    +#endif
            }
            else 
                    printf ("envp is invalid\n");


## Switched Ethernet ports

The 'stock' Carambola2 OpenWRT build from 8devices (and the trunk OpenWRT) configures the ethernet ports backwards from
FreeBSD at least through to 10.1.0, and independently routes them, whereas FreeBSD defaults to switched, which is not
much use as a firewall.

The FreeBSD kernel in -LATEST actually allows the network ports to be swapped.
I was unable to succesfully buildworld against -LATEST using freebsd-wifi-build but I was however able to use the release-10.1.0
userland with the -LATEST kernel, the script allows for this by setting ${SOURCES_KERNEL} !

Once that it done you can modify CARAMBOLA2 and CARAMBOLA2 hints:

    --- a/sys/mips/conf/AR933X_BASE.hints
    +++ b/sys/mips/conf/AR933X_BASE.hints
    @@ -22,15 +22,15 @@ hint.ehci.0.maddr=0x1b000100
     hint.ehci.0.msize=0x00ffff00
     hint.ehci.0.irq=1
     
    -hint.arge.0.at="nexus0"
    -hint.arge.0.maddr=0x19000000
    -hint.arge.0.msize=0x1000
    -hint.arge.0.irq=2
    -
     hint.arge.1.at="nexus0"
    -hint.arge.1.maddr=0x1a000000
    +hint.arge.1.maddr=0x19000000
     hint.arge.1.msize=0x1000
    -hint.arge.1.irq=3
    +hint.arge.1.irq=2
    +
    +hint.arge.0.at="nexus0"
    +hint.arge.0.maddr=0x1a000000
    +hint.arge.0.msize=0x1000
    +hint.arge.0.irq=3
     
     # XXX The ath device hangs off of the AHB, rather than the Nexus.
     hint.ath.0.at="nexus0"
    diff --git a/sys/mips/conf/CARAMBOLA2.hints b/sys/mips/conf/CARAMBOLA2.hints
    index 9610337..3eaad71 100644
    --- a/sys/mips/conf/CARAMBOLA2.hints
    +++ b/sys/mips/conf/CARAMBOLA2.hints
    @@ -18,19 +18,19 @@ hint.arswitch.0.is_7240=1
     hint.arswitch.0.numphys=4
     hint.arswitch.0.phy4cpu=1      # phy 4 is a "CPU" separate PHY
     hint.arswitch.0.is_rgmii=0
    -hint.arswitch.0.is_gmii=1      # arge1 <-> switch PHY is GMII
    +hint.arswitch.0.is_gmii=1      # arge1^H^H^H^H^H arge0 <-> switch PHY is GMII
     
     # OpenWRT cramabola routed ports: ath79_setup_ar933x_phy4_switch(true,true)
     # --> mac :-> phy_swap, mdio :-> phy_addr_swap
     
     # arge0 - MII, autoneg, phy(4)
    -hint.arge.0.phymask=0x10       # PHY4
    -hint.arge.0.mdio=mdioproxy1    # .. off of the switch mdiobus
    +hint.arge.1.phymask=0x10       # PHY4
    +hint.arge.1.mdio=mdioproxy1    # .. off of the switch mdiobus
     
     # arge1 - GMII, 1000/full
    -hint.arge.1.phymask=0x0                # No directly mapped PHYs
    -hint.arge.1.media=1000
    -hint.arge.1.fduplex=1
    +hint.arge.0.phymask=0x0                # No directly mapped PHYs
    +hint.arge.0.media=1000
    +hint.arge.0.fduplex=1
     hint.ar933x_gmac.0.override_phy=1
     hint.ar933x_gmac.0.swap_phy=1


