## 维护供应商
上海能新网络  
陈汉彪 13651795922  
彭利斌 13788908092  
刑工	15721428528


## DW20-006 master 

机柜：       06-055  
采购商：     睦盛  
保修：       2010-07-01~2013-06-30  
机头SN：     SGA01200VW  
机头WWID：   5001-4380-04C7-E310  
1号盘笼SN：  SGA9500012  
1号盘笼WWID：5001-4380-05DD-E9E0  
2号盘笼SN：  SGA02802SW  
2号盘笼WWID：5001-4380-05DF-A585  
3号盘笼SN：  SGA11304TB  
3号盘笼WWID：5001-4380-05DF-162E  
远程控制IP： https://10.20.8.18:2373    
			https://10.20.8.18:2374
			passwd: dw@anjuke2014


## DW20-005 slave 
 
机柜：       06-054  
采购商：     郎摩  
保修：       2010-09-23~2013-09-22  
机头SN：     SGA036019W  
机头WWID：   5001-4380-04C8-EEE0  
1号盘笼SN：  SGA03503KR  
1号盘笼WWID：5001-4380-0649-073A  
2号盘笼SN：  SGA03503K1  
2号盘笼WWID：5001-4380-0649-0783  
3号盘笼SN：  SGA11304TY  
3号盘柜WWID：5001-4380-05E0-3392  
远程控制IP： https://10.20.8.17:2373  
			https://10.20.8.17:2374  
			passwd: dw@anjuke2014


## 维护
1. HP EVA4400 Storage 远程管理地址修改
	* https://10.20.8.18:2373 登录StorageWorks Enterprise Virtual Array （admin/）
	* Administrator Options
    * Configure network options
    * 修改 IP address: New IPS
    * 修改 Gateway server: New GATEWAY
	* 点左上角 Save changes
	
2. 重做系统
	* 安装操作系统前先登录https://10.20.8.18:2373/Login   
	* 在 "Administrator Options"   
   		--> "Power down or restart system"   
      	--> "Power the Whole System OFF"  
        按下"Power OFF" 将控制器与存储柜都关机  
		这样操作的目的是为了在安装系统的时候，不会对存储上的分区和数据产生影响   

	* INSTALL Qlogic HBA Driver
		
			1[root@DW01-005 qla2xxx-src-8.03.01.05.05.06-k]# ./extras/build.sh install
			QLA2XXX -- Building the qla2xxx driver...
			make: Entering directory `/usr/src/kernels/2.6.18-128.el5-x86_64'
 			CC [M]  /root/qla2xxx-src-8.03.01.05.05.06-k/qla_os.o
 			CC [M]  /root/qla2xxx-src-8.03.01.05.05.06-k/qla_init.o
 			CC [M]  /root/qla2xxx-src-8.03.01.05.05.06-k/qla_mbx.o
 			CC [M]  /root/qla2xxx-src-8.03.01.05.05.06-k/qla_iocb.o
 			CC [M]  /root/qla2xxx-src-8.03.01.05.05.06-k/qla_isr.o
 			CC [M]  /root/qla2xxx-src-8.03.01.05.05.06-k/qla_gs.o
 			CC [M]  /root/qla2xxx-src-8.03.01.05.05.06-k/qla_dbg.o
 			CC [M]  /root/qla2xxx-src-8.03.01.05.05.06-k/qla_sup.o
 			CC [M]  /root/qla2xxx-src-8.03.01.05.05.06-k/qla_attr.o
 			CC [M]  /root/qla2xxx-src-8.03.01.05.05.06-k/qla_mid.o
 			CC [M]  /root/qla2xxx-src-8.03.01.05.05.06-k/qla_nlnk.o
 			CC [M]  /root/qla2xxx-src-8.03.01.05.05.06-k/ql2100_fw.o
 			CC [M]  /root/qla2xxx-src-8.03.01.05.05.06-k/ql2200_fw.o
 			CC [M]  /root/qla2xxx-src-8.03.01.05.05.06-k/ql2300_fw.o
 			CC [M]  /root/qla2xxx-src-8.03.01.05.05.06-k/ql2322_fw.o
 			CC [M]  /root/qla2xxx-src-8.03.01.05.05.06-k/ql2400_fw.o
 			CC [M]  /root/qla2xxx-src-8.03.01.05.05.06-k/ql2500_fw.o
 			LD [M]  /root/qla2xxx-src-8.03.01.05.05.06-k/qla2xxx.o
 			Building modules, stage 2.
 			MODPOST
 			CC      /root/qla2xxx-src-8.03.01.05.05.06-k/qla2xxx.mod.o
 			LD [M]  /root/qla2xxx-src-8.03.01.05.05.06-k/qla2xxx.ko
			make: Leaving directory `/usr/src/kernels/2.6.18-128.el5-x86_64'
			QLA2XXX -- Installing the qla2xxx modules to /lib/modules/2.6.18-128.el5/extra/qlgc-		qla2xxx/...
			QLA2XXX -- Installing udev rule to capture FW dump...

	* INSTALL HPDMmultipath-4.4.1  
		a) tar -zxvf HPDMmultipath-4.4.1.tar.gz  
		b) cd HPDMmultipath-4.4.1  
		c) ./INSTALL  
 			1. Install HPDM Multipath Utilities
 			2. Uninstall HPDM Multipath Utilities
 			3. Exit
		d) please select 1
 			Configuring multipath services to start at boot time....OK  
 			Installation completed successfully!

	* vi /etc/multipath.conf
		将path_grouping_policy改为"multibus"
			
			The defaults section 
			defaults {
       		udev_dir                /dev
       		polling_interval        10
       		selector                "round-robin 0"
       		path_grouping_policy    multibus
       		getuid_callout          "/sbin/scsi_id -g -u -s /block/%n"
       		prio_callout            "/bin/true"
       		path_checker            tur
       		rr_min_io               100
       		rr_weight               uniform
       		failback                immediate
       		no_path_retry           12
       		user_friendly_names     yes
			}

		通过"^(sda|sdb)[0-9]*" 
		隐藏掉 sda,sdb 开头的所有设备，看具体情况做调整
			
			blacklist {
       			devnode         "^(sda|sdb)[0-9]*"
      		}

	
	* 将path_grouping_policy改为"multibus"
		
			For EVA A/A arrays
			device {
       			vendor                  "HP|COMPAQ"
       			product                 "HSV1[01]1 \(C\)COMPAQ|HSV2[01]0|HSV300|HSV4[05]0"
       			path_grouping_policy    multibus
       			getuid_callout          "/sbin/scsi_id -g -u -s /block/%n"
       			path_checker            tur
       			path_selector           "round-robin 0"
       			prio_callout            "/sbin/mpath_prio_alua /dev/%n"
       			rr_weight               uniform
       			failback                immediate
       			hardware_handler        "0"
       			no_path_retry           18
       			rr_min_io               100
			}

	* 重启 multipathd 服务  
		/etc/init.d/multipathd restart 

	* multipath -ll查看多路径设备是否连接正常
		[root@DW01-005 dev]# multipath -ll
			
			mpath2 (36001438007f2d0620000300000270000) dm-1 HP,HSV300
			[size=7.2T][features=1 queue_if_no_path][hwhandler=0][rw]
			\_ round-robin 0 [prio=120][active]
			\_ 1:0:0:1 sdc 8:32  [active][ready]
			\_ 2:0:0:1 sdd 8:48  [active][ready]
			\_ 3:0:0:1 sde 8:64  [active][ready]
			\_ 4:0:0:1 sdf 8:80  [active][ready]

	* 格式化并mount使用  
		parted /dev/sdb -s mklabel gpt  
		parted /dev/sdb -s print  
		parted /dev/sdb -s mkpart primary xfs 0.000 3472000.000   (3472000.000=3640655872000 		bytes/1024/1024)Mb  
		mkfs.xfs -f -d agsize=4g -l size=128m /dev/sdb1   
		parted /dev/sdb -s print  
	
3. 故障日志
	2012-07-30  
	故障原因：应用无响应，系统日志中存储报错，CommandView中存储信息丢失  
	故障原因：机房空调失效，EVA温度过高，存储Hang住  
	处理方式：进机房，稳定温度，  
        先关闭控制器（从绿灯变成桔红色），控制器拔电，再关闭盘柜（从绿灯变成桔红色，如果电源按钮无效，可以直接拔电），盘柜拔电，
        等待一段时间，待温度降下后，  
        先开启盘柜，插电或按电源，所有盘柜的指示灯或磁盘灯都正常后，开启控制器，插电或按电源，控制器指示灯都正常后，  
        可以进入CommandView查看EVA是否正常（有需要的话可以重启一下远程控制卡），进入OS查看存储是否可以使用