# 特殊场景下的slave重构
>It is important to back up your databases so that you can recover your data and be up and running again in case problems occur, such as system crashes, hardware failures, or users deleting data by mistake. Backups are also essential as a safeguard before upgrading a MySQL installation, and they can be used to transfer a MySQL installation to another system or to set up replication slave servers.

[Mysql Backup and Recovery](http://dev.mysql.com/doc/refman/5.6/en/backup-and-recovery.html)

## 背景说明
------------
备份和恢复，这是一个非常大的话题，但这不是本章的重点，关于详情，请看之前分享过的一篇PDF [Mysql Backup and Recovery 分享](https://github.com/Keithlan/Keithlan.github.io/tree/master/github_md/Mysql/BACKUP_RECOVERY) 。 备份，主要是用于灾难恢复。 那么，今天我们就来讨论一下再没有备份的前提下，如果从master上恢复一台slave出来？


## 前提

```
* Master
	1. Myisam 引擎
	2. 无全量备份
	3. 有最近2天的binlog
	4. SQL语句特点： 全是insert
	5. 每个表都有主键id，并且auto increment 
* Master 上的table
	1. table1_YYYMM (按月分表)
	2. table2_YYYMMDD (按天分表)
	3. table3 (整张表)
```

如果是innoDB 引擎，到时可以用mysqldump --single transaction 或者 percona xtrabackup 来恢复。  但是在Myisam中，在这种场景下，如何恢复搭建slave呢？

##方案一

```
1. copy 已经不在写的表，比如table1_YYYMM 今天之前，今月之前的表。 消耗时间A
2. 在master 上flush tables with read lock；show master status；消耗时间B
3. copy 剩下的表； 消耗时间C
4. unlock tables；
5. 在slave上，开启同步
```
* **方案一的优点和缺点也很明显：**

```
*优点
	1.无须担心一致性问题。
*缺点
	1. 需要锁表，锁住的时间就是copy数据的时间C。 表越大，锁越长，有些业务是不允许这么长时间的。 
```

##方案二

这里主要抓住一点，只有insert操作。根据这个特性，我们可以针对性的恢复

```

* 检查一下表的自增主键
* 第一步：提前先copy好所有不再写的表，比如table1_YYYMM 今天之前，今月之前的表，同上。  消耗时间A
* 第二步：然后再copy 当天，当月，当时的表， 并且记下 max（主键），以便后续补数据用。  消耗时间B
* 第三步：在master上  消耗时间C
 	1. flush tables with read lock；
 	2. show master status； 
 	3. 记下当天，当月，当时的表的max（主键），由于是myisam引擎，基本是瞬间完成。 
 	4. unlock tables； 
* 第四步：修补第二步和第三步 max（主键）中的空洞。  
* 第五步：repair 部分表，可以用同步机制自动检测且修复，无须人为关心。
* 第六步：在slave上，开启同步
```

* **方案二的优点和缺点：**

```
* 优点：
	1. 基本上无中断业务时间。
	2. 不会丢失任何数据。
* 缺点：
	1. 需要脚本处理max值，记录position点。
	2. 需要repair表。
	3. 如果有update，delete语句，有风险。
```


以上，就是这次奇葩的数据恢复。

## 总结

1. 没有备份，等于自掘坟墓。
2. 没有测试恢复过的备份，等于没有备份。
3. 请看第一点。
