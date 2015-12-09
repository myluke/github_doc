# MegaCli 工具篇

---

## 相关链接

```
http://www.igigo.net/post/archives/251
http://blog.sina.com.cn/s/blog_5f5716580100k5ae.html
http://leejia.blog.51cto.com/4356849/1441499
```

## 相关注意事项


* **生成Raid日志**
 
```
MegaCli -FwTermLog -Dsply -aALL
```

* **显示Raid卡信息**

```
MegaCli -AdpAllInfo -aAll
```

* **显示所有的物理硬盘信息**

```
MegaCli -PDList -aAll
```

* **查看dell的机器的磁盘是什么类型**

```
[root@xx ~]# MegaCli64 -PDList -aAll | grep -i 'Media Type'
Media Type: Hard Disk Device
Media Type: Hard Disk Device
Media Type: Hard Disk Device
Media Type: Hard Disk Device
Media Type: Hard Disk Device
Media Type: Hard Disk Device
Media Type: Hard Disk Device
Media Type: Hard Disk Device
Media Type: Hard Disk Device
Media Type: Hard Disk Device
```

* **查看电池是否损坏**

```
MegaCli -AdpBbuCmd -GetBbuStatus -aALL | grep isSOHGood
```

* **显示 电池 相关信息**

```
MegaCli -AdpBbuCmd -aAll
```

* **危险： 强制 电池 进行充放电**

```
MegaCli -AdpBbuCmd -BbuLearn -aAll
DELL的Raid卡会90天自动充放电一次，充放电期间BBU会Disable
如果Raid的BBU老化，其“Absolute State of charge”过低，会使BBU自动Disable
```

* **查看Raid卡策略**

```
MegaCli -LdInfo -lAll -aALL
```

* **调整RAID策略**

```
write policy : WT (Write through), WB (Write back)
BBU policy : CachedBadBBU (Write Cache OK if Bad BBU), NOCachedBadBBU (No Write Cache if Bad BBU)
当BBU不可用时，为了数据安全，Raid会自动进入WT模式，读写性能巨跌，但为了不影响线上使用，可以手动强行设置
MegaCli -LDSetProp WB -Lall -aall
MegaCli -LDSetProp CachedBadBBU -Lall -aALL

read policy : NORA (No read ahead), RA (Read ahead), ADRA (Adaptive read ahead)
开启RA在顺序读的情况下会有好处，但会影响随机读，一般使用ADRA，自适应预读模式
MegaCli -LDSetProp ADRA -LALL -aALL

disk policy : EnDskCache (Enables disk cache), DisDskCache (Disables disk cache)
cache policy : Cached, Direct
当有UPS时，可以启用Disk上的Cache来进一步提升性能，如果没有UPS，建议关闭，以防掉电时丢失数据
MegaCli -LDSetProp -DisDskCache -LAll -aALL
MegaCli -LDSetProp -Direct -LAll -aAll

access policy : RW, RO, Blocked
```

# HP RAID 命令集

* **显示raid卡信息**

```
hpssacli ctrl all show  config

hpssacli ctrl all show detail config   //查看raid卡详细信息

```

* **显示所有物理磁盘信息**

```
hpssacli ctrl slot=0 pd all show status
hpssacli ctrl slot=0 pd all show detail   //查看所有物理磁盘详细信息
```

* **检查HP机器的磁盘类型**

```
hpssacli ctrl slot=0 pd all show detail  | grep 'Interface Type'
```

* **查看电池状态**

```
hpssacli ctrl all show status | grep Battery
```

* **查看raid缓存策略**

```
hpssacli ctrl all show detail config | grep "Drive Write Cache:"
Drive Write Cache: Enabled

// Drive Write Cache 有两种状态：Disable和Enable。
// Disable代表将数据直接写入磁盘，Enable代表先将数据写入缓存然后在写入磁盘。

// 修改cache状态：
hpssacli  ctrl slot=0 modify dwc={enable|disable}

hpssacli ctrl all show detail config | grep "No-Battery Write Cache"
No-Battery Write Cache: Disabled

//修改状态
hpssacli  ctrl slot=0 modify nobatterywritecache=enable
```

* **未完待续...**
