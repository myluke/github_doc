# 操作系统初始化检查

---

## 检查硬件的配置和环境

```
* LSCI相关
free -m
MegaCli64 -PDList -aAll | grep -i 'Media Type'    
MegaCli64 -LdInfo -lAll -aALL
MegaCli64 -AdpBbuCmd -GetBbuStatus -aALL | grep isSOHGood
df -hT

* 非LSCI相关
free -m
hpssacli ctrl slot=0 pd all show detail  | grep 'Interface Type'
hpssacli ctrl all show detail config | grep "Drive Write Cache:"  
hpssacli ctrl all show  config | grep 'logicaldrive'

```


## SSH 第一次验证

```
[root@xx ~]# cat /etc/ssh/ssh_config  | grep StrictHostKeyChecking
   StrictHostKeyChecking no  --设置成no，第一次登陆不用验证。
   
/etc/init.d/sshd reload  --配置生效
```


## TCP相关

```
* 针对短连接,但是一定要确保不是在NAT环境
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 1
```

## 硬件

* **Raid相关**

```
1） 检查raid级别： raid10（SAS），raid5，raid50，raid10，raid1 （SSD）
		MegaCli64 -LdInfo -lAll -aALL

2） 检查raid策略： WB（正常） /  WT (有问题)
		MegaCli64 -LdInfo -lAll -aALL

3)  检查raid电池
		MegaCli64 -AdpBbuCmd -GetBbuStatus -aALL | grep isSOHGood

```

* **磁盘分区，对齐**

```

* 4k对齐,检查

	* fdisk分区的用fdisk检查：          fdisk -ul  如果起始位置能被8整除，说明对齐
	* parted分区的用parted检查：        parted  /dev/sdb1 align-check opt 1

* Raid
2SAS raid1 + 6 * 480G SSD raid10 

* 分区大小(参照)
/dev/sda2      ext4    98G  2.5G   25G   9% /
tmpfs          tmpfs   63G     0   63G   0% /dev/shm
/dev/sda1      ext4    97M   29M   63M  32% /boot
/dev/sdb1      xfs    2.0T  136G  1.9T   7% /data


```

## 系统

* **关闭numa**


```
a）/etc/grub.conf的kernel行最后添加numa=off
b）查看是否支持numa: dmesg | grep -i numa
c）查看状态： numastat
```

* **REDHAT 6系列中，将vm.swappiness 设置成1。 PS： 如果设置成0，可能导致mysql挂掉**

```
a）echo "vm.swappiness = 1" >> /etc/sysctl.conf
b）sysctl -p 让配置文件生效
c) 如何查看： cat /proc/sys/vm/swappiness
```

* **ulimit 设置**

```
简单总结：

ulimit -u   建议设置unlimit无限制

1）先读取/etc/security/limits.conf，如果有/etc/security/limits.d/90-nproc.conf存在，会覆盖掉/etc/security/limits.conf 的设置（RHEL6）。 如果没有，则使用limits.conf（RHEL5）。

2）如果注释掉/etc/security/limits.d/90-nproc.conf 里面的内容，那么ulimit -u 的值由内核决定：

$ cat /proc/meminfo |grep MemTotal
MemTotal:       65858988 kB
$ echo "65858988 / 128"| bc 
514523
$ ulimit -u
514523


服务器标准化：
	ulimit -n ：设置无限制
	ulimit -u ：设置无限制 
```




## 简单总结

```
* tcp
	1) for 短连接,但是一定确保不能是NAT环境
		net.ipv4.tcp_tw_reuse = 1
		net.ipv4.tcp_tw_recycle = 1


* Raid相关：
	1） 2*SAS raid1  + N*SSD raid5
	2） 策略：强制WB
	3） 必须有电池保护

* 磁盘分区：必须4k对齐

* 分区参考:

/dev/sda2      ext4    98G  2.5G   25G   9% /
tmpfs          tmpfs   63G     0   63G   0% /dev/shm
/dev/sda1      ext4    97M   29M   63M  32% /boot
/dev/sdb1      xfs    2.0T  136G  1.9T   7% /data

* /data 分区必须是： XFS

* 系统：高于RHEL6.4

* 关闭numa

* ulimit -u   unlimit无限制

* io scheduler ==  deadline

* 预先安装的包：perl-DBD-mysql , nc , cmake,ncurses-devel, wireshark 
```
