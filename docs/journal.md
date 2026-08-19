#Journal

OS:
Linux server 6.14.0-37-generic #37-Ubuntu SMP PREEMPT_DYNAMIC Fri Nov 14 22:10:32 UTC 2025 x86_64 x86_64 x86_64 GNU/Linux
nroc: 4
free -h
               total        used        free      shared  buff/cache   available
Mem:           7.6Gi       832Mi       2.3Gi       4.2Mi       4.8Gi       6.8Gi
Swap:           11Gi        67Mi        11Gi
df -h
Filesystem      Size  Used Avail Use% Mounted on
tmpfs           776M  1.2M  774M   1% /run
/dev/sda1        72G   28G   45G  38% /
tmpfs           3.8G     0  3.8G   0% /dev/shm
tmpfs           5.0M     0  5.0M   0% /run/lock
tmpfs           3.8G  3.3M  3.8G   1% /tmp
tmpfs           1.0M     0  1.0M   0% /run/credentials/systemd-resolved.service
/dev/sda13      989M  147M  775M  16% /boot
/dev/sda15      105M  6.1M   99M   6% /boot/efi
tmpfs           1.0M     0  1.0M   0% /run/credentials/systemd-networkd.service
tmpfs           1.0M     0  1.0M   0% /run/credentials/serial-getty@ttyS0.service
tmpfs           1.0M     0  1.0M   0% /run/credentials/getty@tty1.service
tmpfs           1.0M     0  1.0M   0% /run/credentials/systemd-journald.service
tmpfs           776M   16K  776M   1% /run/user/0
ip -brief a
lo               UNKNOWN        127.0.0.1/8 ::1/128
ens3             UP             51.83.159.246/32 metric 100 2001:41d0:601:1100::204f/128 fe80::f816:3eff:fe09:c5d2/64
docker0          DOWN           172.17.0.1/16 fe80::10d9:87ff:fe3c:e6c5/64
tun0             UNKNOWN        10.8.0.1/24 fe80::963a:fc23:6e0e:df9f/64
br-c8252a487554  DOWN           172.18.0.1/16 fe80::2cfa:4eff:fe3c:a96/64

