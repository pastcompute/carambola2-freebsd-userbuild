## Flashing Procedure

sudo scp -P62222 $LOGNAME@localhost:/tftpboot/* /srv/tftp/

sudo service tftpd-hpa start
minicom -b 115200 -D /dev/ttyUSB0 -o

erase 0x9f050000 +0xd90000
setenv ipaddr 192.168.0.201
setenv serverip 192.168.0.107
tftpboot 0x80050000 mfsroot-carambola2.img.ulzma
cp.b 0x80050000 0x9f250000 $filesize
tftpboot 0x80050000 kernel.CARAMBOLA2.lzma.uImage
#cp.b 0x80050000 0x9f050000 $filesize

## Making a single bundle

We need to pad `kernel.CARAMBOLA2.lzma.uImage` out to 0x200000 (2MB)

dd if=/dev/zero bs=$(( 0x200000 )) count=1 of=/tftpboot/kernel.CARAMBOLA2.lzma.flash
dd if=/tftpboot/kernel.CARAMBOLA2.lzma.uImage of=/tftpboot/kernel.CARAMBOLA2.lzma.flash conv=notrunc
dd if=/tftpboot/mfsroot-carambola2.img.ulzma >> /tftpboot/kernel.CARAMBOLA2.lzma.flash

## Flashing the bundle instead

setenv ipaddr 192.168.0.244
setenv serverip 192.168.0.107
saveenv

erase 0x9f050000 +0xd90000
tftpboot 0x80050000 kernel.CARAMBOLA2.lzma.flash
cp.b 0x80050000 0x9f050000 $filesize
reset

