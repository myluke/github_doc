# MySQL 运维常用工具&命令

---

## information_schema相关


### PROCESSLIST

* **分析出当前连接过来的客户端ip的分布情况**

```
select substring_index(host,':', 1) as appip ,count(*) as count from information_schema.PROCESSLIST group by appip order by count desc ;
```


* **分析处于Sleep状态的连接分布情况**

```
select substring_index(host,':', 1) as appip ,count(*) as count from information_schema.PROCESSLIST where COMMAND='Sleep' group by appip order by count desc ;
```

* **分析哪些DB访问的比较多**

```
select DB ,count(*) as count from information_schema.PROCESSLIST where COMMAND='Sleep' group by DB order by count desc ;
```

* **分析哪些用户访问的比较多**

```
select user ,count(*) as count from information_schema.PROCESSLIST where COMMAND='Sleep' group by user order by count desc ;
```



## performance_schema相关

### Table IO 相关的监控

#### 库级别

* **如何查看一个MySQL实例中哪个库的latency时间最大**

```
select OBJECT_SCHEMA,sum(SUM_TIMER_WAIT) as all_time,sum(COUNT_STAR) as all_star,sum(COUNT_read) as all_read ,sum(COUNT_WRITE) as all_write,sum(COUNT_FETCH) as all_fetch,sum(COUNT_INSERT) as all_insert,sum(COUNT_UPDATE) as all_update,sum(COUNT_DELETE) as all_delete  from performance_schema.table_io_waits_summary_by_table   group by OBJECT_SCHEMA order by all_time  desc;
```

* **如何查看一个MySQL实例中哪个库的总访问量最大**

```
select OBJECT_SCHEMA,sum(SUM_TIMER_WAIT) as all_time,sum(COUNT_STAR) as all_star,sum(COUNT_read) as all_read ,sum(COUNT_WRITE) as all_write,sum(COUNT_FETCH) as all_fetch,sum(COUNT_INSERT) as all_insert,sum(COUNT_UPDATE) as all_update,sum(COUNT_DELETE) as all_delete  from performance_schema.table_io_waits_summary_by_table   group by OBJECT_SCHEMA order by all_star  desc;
```

* **如何查看一个MySQL实例中哪个库的查询量(除了select中的fetchs外,还包括update，delete过程中的fetchs)最大**

```
select OBJECT_SCHEMA,sum(SUM_TIMER_WAIT) as all_time,sum(COUNT_STAR) as all_star,sum(COUNT_read) as all_read ,sum(COUNT_WRITE) as all_write,sum(COUNT_FETCH) as all_fetch,sum(COUNT_INSERT) as all_insert,sum(COUNT_UPDATE) as all_update,sum(COUNT_DELETE) as all_delete  from performance_schema.table_io_waits_summary_by_table   group by OBJECT_SCHEMA order by all_read  desc;
```

* **如何查看一个MySQL实例中哪个库的写入量最大**

```
select OBJECT_SCHEMA,sum(SUM_TIMER_WAIT) as all_time,sum(COUNT_STAR) as all_star,sum(COUNT_read) as all_read ,sum(COUNT_WRITE) as all_write,sum(COUNT_FETCH) as all_fetch,sum(COUNT_INSERT) as all_insert,sum(COUNT_UPDATE) as all_update,sum(COUNT_DELETE) as all_delete  from performance_schema.table_io_waits_summary_by_table   group by OBJECT_SCHEMA order by all_write  desc;
```


* **如何查看一个MySQL实例中哪个库的update量最大**

```
select OBJECT_SCHEMA,sum(SUM_TIMER_WAIT) as all_time,sum(COUNT_STAR) as all_star,sum(COUNT_read) as all_read ,sum(COUNT_WRITE) as all_write,sum(COUNT_FETCH) as all_fetch,sum(COUNT_INSERT) as all_insert,sum(COUNT_UPDATE) as all_update,sum(COUNT_DELETE) as all_delete  from performance_schema.table_io_waits_summary_by_table   group by OBJECT_SCHEMA order by all_update  desc;
```

* **如何查看一个MySQL实例中哪个库的insert量最大**

```
select OBJECT_SCHEMA,sum(SUM_TIMER_WAIT) as all_time,sum(COUNT_STAR) as all_star,sum(COUNT_read) as all_read ,sum(COUNT_WRITE) as all_write,sum(COUNT_FETCH) as all_fetch,sum(COUNT_INSERT) as all_insert,sum(COUNT_UPDATE) as all_update,sum(COUNT_DELETE) as all_delete  from performance_schema.table_io_waits_summary_by_table   group by OBJECT_SCHEMA order by all_insert  desc;
```


* **如何查看一个MySQL实例中哪个库的delete量最大**

```
select OBJECT_SCHEMA,sum(SUM_TIMER_WAIT) as all_time,sum(COUNT_STAR) as all_star,sum(COUNT_read) as all_read ,sum(COUNT_WRITE) as all_write,sum(COUNT_FETCH) as all_fetch,sum(COUNT_INSERT) as all_insert,sum(COUNT_UPDATE) as all_update,sum(COUNT_DELETE) as all_delete  from performance_schema.table_io_waits_summary_by_table   group by OBJECT_SCHEMA order by all_delete  desc;
```

#### 表级别

* **表的latency时间最大**

```
select OBJECT_SCHEMA,OBJECT_NAME,SUM_TIMER_WAIT,COUNT_STAR,COUNT_read,COUNT_WRITE,COUNT_UPDATE,COUNT_insert,COUNT_delete from performance_schema.table_io_waits_summary_by_table  order by SUM_TIMER_WAIT desc  limit 10
```

* **表的总访问量最大**

```
select OBJECT_SCHEMA,OBJECT_NAME,SUM_TIMER_WAIT,COUNT_STAR,COUNT_read,COUNT_WRITE,COUNT_UPDATE,COUNT_insert,COUNT_delete from performance_schema.table_io_waits_summary_by_table  order by COUNT_STAR  desc  limit 10
```

* **表的查询量最大**

```
select OBJECT_SCHEMA,OBJECT_NAME,SUM_TIMER_WAIT,COUNT_STAR,COUNT_read,COUNT_WRITE,COUNT_UPDATE,COUNT_insert,COUNT_delete from performance_schema.table_io_waits_summary_by_table  order by  COUNT_read desc  limit 10
```

* **表的写入量最大**

```
select OBJECT_SCHEMA,OBJECT_NAME,SUM_TIMER_WAIT,COUNT_STAR,COUNT_read,COUNT_WRITE,COUNT_UPDATE,COUNT_insert,COUNT_delete from performance_schema.table_io_waits_summary_by_table  order by  COUNT_WRITE desc  limit 10
```


* **表的update量最大**

```
select OBJECT_SCHEMA,OBJECT_NAME,SUM_TIMER_WAIT,COUNT_STAR,COUNT_read,COUNT_WRITE,COUNT_UPDATE,COUNT_insert,COUNT_delete from performance_schema.table_io_waits_summary_by_table  order by  COUNT_update desc  limit 10
```

* **表的insert量最大**

```
select OBJECT_SCHEMA,OBJECT_NAME,SUM_TIMER_WAIT,COUNT_STAR,COUNT_read,COUNT_WRITE,COUNT_UPDATE,COUNT_insert,COUNT_delete from performance_schema.table_io_waits_summary_by_table  order by  COUNT_insert desc  limit 10
```


* **表的delete量最大**

```
select OBJECT_SCHEMA,OBJECT_NAME,SUM_TIMER_WAIT,COUNT_STAR,COUNT_read,COUNT_WRITE,COUNT_UPDATE,COUNT_insert,COUNT_delete from performance_schema.table_io_waits_summary_by_table  order by  COUNT_delete desc  limit 10
```






## 抓包

```


分析xx   select count(*)

tshark -r xx.tcpdump -d tcp.port==3306,mysql -T fields  -e frame.time -e ip.src -e mysql.query | awk '{if(NF>1) print $0}' > test.tshark
cat test.tshark | grep 'select count'


=============================================================================================================================================================
tshark 中的 -e参数有哪些内容请参考http://www.wireshark.org/docs/dfref/


tshark: 抓mysql包
tshark -i eth0 dst host ${ip} and dst port 3306 -l -d tcp.port==3306,mysql -T fields -e frame.time -e 'ip.src'  -e 'mysql.query' > yy.tshark  --这种方式，会在/tmp/目录下创建很多临时文件，要小心，会产生磁盘报警。

tshark -i eth0 dst host ${ip} and dst port 3306 -l -d tcp.port==3306,mysql -T fields -e 'ip.src' -e 'tcp.srcport' -e 'mysql.schema'  -e 'mysql.query' -w yy.tshark  --类似于tcpdump。

nohup tshark -i eth0 dst host ${ip} and dst port 3306 -l -d tcp.port==3306,mysql -a duration:20  -T fields -e mysql.schema -e frame.time -e ip.src -e tcp.srcport -e mysql.query -w xx.sql &  -- -a duration 当时间超过 20秒时，停止抓取。  


nohup tshark -i eth0 dst host ${ip} and dst port 3306 -l -d tcp.port==3306,mysql -a filesize:2000000 -T fields -e mysql.schema -e frame.time -e ip.src -e tcp.srcport -e mysql.query -w xx.sql &     注：当文件超过2G时，停止抓取。单位是Kilobyte。

thark：解tcpdump包
tshark -r xx.tcpdump -d tcp.port==3306,mysql -T fields -e mysql.schema  -e frame.time -e ip.src -e mysql.query  > test.tshark
```

## mysqldump 相关
---

* **常用命令**

```

FROM: http://www.cnblogs.com/qq78292959/p/3637135.html


* 在线导出master数据

/usr/local/mysql/bin/mysqldump -uxx -pxx --master-data --single-transaction -A > bakup_${date}.sql

* --where, -w

只转储给定的WHERE条件选择的记录。请注意如果条件包含命令解释符专用空格或字符，一定要将条件引用起来。

mysqldump  -uroot -p --host=localhost --all-databases --where=” user=’root’”


--databases,  -B

导出几个数据库。参数后面所有名字参量都被看作数据库名。

mysqldump  -uroot -p --databases test mysql



* --tables

覆盖--databases (-B)参数，指定需要导出的表名。

mysqldump  -uroot -p --host=localhost --databases test --tables test

* --quick, -q (强烈建议开启)

不缓冲查询，直接导出到标准输出。默认为打开状态，使用--skip-quick取消该选项。

mysqldump  -uroot -p --host=localhost --all-databases 

mysqldump  -uroot -p --host=localhost --all-databases --skip-quick


* --no-data, -d

不导出任何数据，只导出数据库表结构。

* --no-create-info,  -t

只导出数据，而不添加CREATE TABLE 语句。

mysqldump  -uroot -p --host=localhost --all-databases --no-create-info

* --no-create-db,  -n

只导出数据，而不添加CREATE DATABASE 语句。

mysqldump  -uroot -p --host=localhost --all-databases --no-create-db

* --lock-tables,  -l

开始导出前，锁定所有表。用READ  LOCAL锁定表以允许MyISAM表并行插入。对于支持事务的表例如InnoDB和BDB，--single-transaction是一个更好的选择，因为它根本不需要锁定表。

请注意当导出多个数据库时，--lock-tables分别为每个数据库锁定表。因此，该选项不能保证导出文件中的表在数据库之间的逻辑一致性。不同数据库表的导出状态可以完全不同。

mysqldump  -uroot -p --host=localhost --all-databases --lock-tables


* --lock-all-tables,  -x  （--skip-lock-all-tables）

提交请求锁定所有数据库中的所有表，以保证数据的一致性。这是一个全局读锁，并且自动关闭--single-transaction 和--lock-tables 选项。

mysqldump  -uroot -p --host=localhost --all-databases --lock-all-tables


* --add-locks

在每个表导出之前增加LOCK TABLES并且之后UNLOCK  TABLE。(默认为打开状态，使用--skip-add-locks取消选项)

mysqldump  -uroot -p --all-databases  (默认添加LOCK语句)

mysqldump  -uroot -p --all-databases –-skip-add-locks   (取消LOCK语句)


* --add-drop-database

每个数据库创建之前添加drop数据库语句。

mysqldump  -uroot -p --all-databases --add-drop-database

* --add-drop-table

每个数据表创建之前添加drop数据表语句。(默认为打开状态，使用--skip-add-drop-table取消选项)

mysqldump  -uroot -p --all-databases  (默认添加drop语句)

mysqldump  -uroot -p --all-databases –-skip-add-drop-table  (取消drop语句)



* --dump-slave

该选项将导致主的binlog位置和文件名追加到导出数据的文件中。设置为1时，将会以CHANGE MASTER命令输出到数据文件；设置为2时，在命令前增加说明信息。该选项将会打开--lock-all-tables，除非--single-transaction被指定。该选项会自动关闭--lock-tables选项。默认值为0。

mysqldump  -uroot -p --all-databases --dump-slave=1

mysqldump  -uroot -p --all-databases --dump-slave=2



* --master-data

该选项将binlog的位置和文件名追加到输出文件中。如果为1，将会输出CHANGE MASTER 命令；如果为2，输出的CHANGE  MASTER命令前添加注释信息。该选项将打开--lock-all-tables 选项，除非--single-transaction也被指定（在这种情况下，全局读锁在开始导出时获得很短的时间；其他内容参考下面的--single-transaction选项）。该选项自动关闭--lock-tables选项。

mysqldump  -uroot -p --host=localhost --all-databases --master-data=1;

mysqldump  -uroot -p --host=localhost --all-databases --master-data=2;




* --log-error

附加警告和错误信息到给定文件

mysqldump  -uroot -p --host=localhost --all-databases  --log-error=/tmp/mysqldump_error_log.err


```



* **基本原理和注意点**

```
0） 原文出处：
http://imysql.cn/2008_10_24_deep_into_mysqldump_options
http://imysql.com/2014/06/22/mysql-faq-mysqldump-where-option.shtml
http://imysql.com/2015/03/21/mysql-faq-why-turn-on-quick-option.shtml

1）使用mysqldump来备份数据时，建议总是加上 -q 参数，避免发生swap反而影响备份效率。

	* -q, --quick         Don't buffer query, dump directly to stdout.
	* 加上 -q 后，不会把SELECT出来的结果放在buffer中，而是直接dump到标准输出中，顶多只是buffer当前行结果，正常情况下是不会超过 max_allowed_packet 限制的，它默认情况下是开启的。
	* 如果关闭该参数，则会把SELECT出来的结果放在本地buffer中，然后再输出给客户端，会消耗更多内存。
	
2）--lock-tables

	* 加了一个 READ LOCAL LOCK，该锁不会阻止读，也不会阻止新的数据插入
	
3) --lock-all-tables
	
	* 这个就有点不太一样了，它请求发起一个全局的读锁，会阻止对所有表的写入操作，以此来确保数据的一致性。备份完成后，该会话断开，会自动解锁。
	
详细流程，可以从query 日志看
====================================

6 Query       /*!40100 SET @@SQL_MODE='' */
6 Query       FLUSH TABLES
6 Query       FLUSH TABLES WITH READ LOCK

           ...     ....
6 quit

=====================================



4) --master-data

	* 除了和刚才的 --lock-all-tables 多了个 SHOW MASTER STATUS 之外，没有别的变化。
	
详细流程，可以从query 日志看
====================================

6 Query       /*!40100 SET @@SQL_MODE='' */
6 Query       FLUSH TABLES
6 Query       FLUSH TABLES WITH READ LOCK
6 Query       SHOW MASTER STATUS

           ...     ....
6 quit

=====================================


5) --single-transaction

	* InnoDB 表在备份时，通常启用选项 --single-transaction 来保证备份的一致性，实际上它的工作原理是设定本次会话的隔离级别为：REPEATABLE READ，以确保本次会话(dump)时，不会看到其他会话已经提交了的数据。
	
详细流程，可以从query 日志看
====================================

6 Query       /*!40100 SET @@SQL_MODE='' */
6 Query       SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ
6 Query       BEGIN
6 Query       UNLOCK TABLES

           ...     ....
6 quit

=====================================


6) --single-transaction and --master-data

	* 本例中，由于增加了选项 --master-data，因此还需要提交一个快速的全局读锁。在这里，可以看到和上面的不同之处在于少了发起 BEGIN 来显式声明事务的开始.这里采用 START TRANSACTION WITH CONSISTENT SNAPSHOT 来代替 BEGIN
	
详细流程，可以从query 日志看
====================================

6 Query       /*!40100 SET @@SQL_MODE='' */
6 Query       FLUSH TABLES
6 Query       FLUSH TABLES WITH READ LOCK
6 Query       SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ
6 Query       START TRANSACTION WITH CONSISTENT SNAPSHOT
6 Query       SHOW MASTER STATUS
6 Query       UNLOCK TABLES

           ...     ....
6 quit

=====================================



```

## NC 传送
---


```
传送文件
目的主机监听
nc -l 监听端口<未使用端口>  > 要接收的文件名
nc -l 4444 > cache.tar.gz
 
源主机发起请求
nc  目的主机ip    目的端口 < 要发送的文件
nc  192.168.0.85  4444 < /root/cache.tar.gz
=============================================

==传送文件夹==
接收方的命令：
nc -l ${ip} 4444 | tar xf -

传送方的命令：
tar -cvf - ppc_* | nc ${ip} 4444
```

## rsync

```
配置：/etc/rsyncd.conf
uid = root
gid = root
use chroot = no
max connections = 64
pid file = /var/run/rsyncd.pid
lock file = /var/run/rsync.lock
log file = /var/log/rsyncd.log

[dbbak]
path = /data/dbbackup
use chroot = no
ignore errors
read only = no
list = no

[Binlog]
path = /data/BINLOG_BACKUP
use chroot = no
ignore errors
read only = no
list = no

[fullbak]
path = /data/FULL_BACKUP
use chroot = no
ignore errors
read only = no
list = no	

启动： /usr/bin/rsync --daemon

限速100k/s传输 ：
	/usr/bin/rsync -av --progress  --update --bwlimit=100 --checksum --compress  $file  root@$ip::dbbak

正常传输：
   /usr/bin/rsync -av --progress   $file  root@$ip::dbbak

```

## pigz使用

* **常用知识普及**

```
错误的写法：nohup tar -cvf - xx_20151129 | pigz  -p 24 > xx_20151129.tar.gz & --一定不能加nohup，因为中间有管道符，不能传递下去的
错误的代价：
	tar: This does not look like a tar archive
	tar: Skipping to next header
	tar: Exiting with failure status due to previous errors
以上错误的案例中，为此付出过很大的代价，哭晕在厕所N次了...

正确的写法：  tar -cvf - xx_20151129 | pigz  -p 24 > xx_20151129.tar.gz &


```


* **用法**

```
* 压缩
tar cvf - 目录名 | pigz -9 -p 24 > file.tgz
pigz：用法-9是压缩比率比较大，-p是指定cpu的核数。

* 解压1
pigz -d file.tgz
tar -xf --format=posix file

* 解压2
tar xf file.tgz
```

## axel & httpd 多线程数据传输

```
* axel 下载&安装
wget -c http://pkgs.repoforge.org/axel/axel-2.4-1.el5.rf.x86_64.rpm
rpm -ivh axel-2.4-1.el5.rf.x86_64.rpm

* axel 核心参数
-n   指定线程数
-o   指定另存为目录


* httpd服务搭建与配置

	yum install httpd

* httpd配置主目录
	/etc/httpd/conf/httpd.conf

[xx html]# cat /etc/httpd/conf/httpd.conf | grep DocumentRoot
# DocumentRoot: The directory out of which you will serve your
#DocumentRoot "/var/www/html" --注释
DocumentRoot "/data/dbbackup/html" --配置成容量大的地址

* 开启httpd服务

service httpd restart

* 下载数据
目的地ip shell> nohup axel -n 10 -v -o /data/dbbackup/ http://$数据源ip/xx_20151129.tar.gz &


```


## 查看ip1 与 ip2 之间的流量

```
root@ip1> iftop -F $ip2/32     =============   iftop -F $P{ip}/32
```
