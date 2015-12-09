# ulimit 和 mysql 的故事

---

## 背景
>
前些天，mysql 自带的监控脚本无故卡死，报错信息如下： Resource temporarily unavailable
然后将mysql 用户下的 ulimit 设置为8192 ， 则正常。
虽然暂时解决了问题，但是背后的原理还没弄清楚，这里打算详细了解一下。

## ulimit -u & ulimit -n 区别？

```
这里先弄清楚一个概念：

open files                      (-n) 40000 ： 最大文件打开数

max user processes              (-u) 8092 ：  最大用户进程数

```

## 如何有效的设置ulimit -u ？

```
这里有一篇淘宝褚霸的blog, 请参考：http://blog.yufeng.info/archives/2568

简单总结：

ulimit -u

1）先读取/etc/security/limits.conf，如果有/etc/security/limits.d/90-nproc.conf存在，会覆盖掉/etc/security/limits.conf 的设置（RHEL6）。 如果没有，则使用limits.conf（RHEL5）。

2）如果注释掉/etc/security/limits.d/90-nproc.conf 里面的内容，那么ulimit -u 的值由内核决定：

$ cat /proc/meminfo |grep MemTotal
MemTotal:       65858988 kB
$ echo "65858988 / 128"| bc 
514523
$ ulimit -u
514523


```

## 如何有效的设置ulimit -n

```
1） 直接修改/etc/security/limits.conf ， 只能修改非root用户
2） 对于root用户，可以在/etc/profile 中设置ulimit -HSn 65535
```



## mysqld_safe 的相关知识

```
在root用户下，虽然这样启动mysq： mysqld_safe --user=mysql & ， mysqld 虽然是用mysql用户启动的，但是它使用的环境变量如（ulimit -u & ulimit -n ）都是root下的。 --谨记

```

## ulimit -u  和 mysql的纠缠

```
既然知道了ulimit -u 是设置的mysql的最大进程数，那我们就来测试一把。

先考虑一个问题： mysql是单进程多线程，那么为啥会超过max值呢？

不管，先测。。。

[root@db10-091 ~]# cat /etc/security/limits.d/90-nproc.conf
mysql       soft    nproc     40

[mysql@db10-091 ~]$ ulimit -u
40

[root@db10-091 ~]# lsof -u mysql | grep pipe | wc -l
2

循环40次后：
	mysql -ubackup -pbackup -e 'select 1,sleep(60)'
	
[root@db10-091 ~]# lsof -u mysql | grep pipe | wc -l
72

报错：
	-bash: fork: retry: Resource temporarily unavailable
	-bash: fork: retry: Resource temporarily unavailable
	-bash: fork: retry: Resource temporarily unavailable
	
所以，mysql的链接数会占用mysql的nproc，当超过max值后，会导致以上错误。

```

## ulimit -n  和 mysql的纠缠

---

* **innodb_open_files & open_files_limit**

```
解释来自官方文档：

1) innodb_open_files:
It specifies the maximum number of .ibd files that MySQL can keep open at one time

表示mysql能够同时打开的innoDB的表的数量。

2）open_files_limit
Changes the number of file descriptors available to mysqld.

mysql 能够打开的文件描述符数量。

PS： 一个表，不一定只打开一个文件描述符。计算方法请参照官方文档。

问题：如果超过了innodb_open_files的大小会怎么样？
答： mysql会将之前的表关闭，然后重启开启新的表。

问题：如果超过了open_files_limit的大小会怎么样？
答： 报错。 too many files 等

```

## 如何有效的设置open_files_limit

以下测试的前提条件是 : RHEL6.4, mysql 5.6.16 , 以root用户启动mysqld_safe . --至于区别，之前已经提到过。

至于以mysql用户启动mysqld_safe ， 请自行测试。

* **mysql配置文件中设置了open_files_limit**

```
cat /etc/my.cnf | grep limit
open-files-limit = 3000

[root@db10-091 ~]# ulimit -n
40000


场景一：
root:(none)> show global variables like '%max_connections%';
+-----------------+-------+
| Variable_name   | Value |
+-----------------+-------+
| max_connections | 1000  |
+-----------------+-------+
1 row in set (0.00 sec)

root:(none)> show global variables like '%open_files_limit%';
+------------------+-------+
| Variable_name    | Value |
+------------------+-------+
| open_files_limit | 5000  |
+------------------+-------+
1 row in set (0.00 sec)

场景二：
root:(none)> show global variables like '%max_conn%';
+--------------------+-------+
| Variable_name      | Value |
+--------------------+-------+
| max_connections    | 100   |
+--------------------+-------+
1 rows in set (0.00 sec)


root:(none)> show global variables like '%open_files_limit%';
+------------------+-------+
| Variable_name    | Value |
+------------------+-------+
| open_files_limit | 3000  |
+------------------+-------+
1 row in set (0.00 sec)


结果是：   open_files_limit = 5000.
计算方式： 当open_file_limit被配置的时候，比较open_files_limit和max_connections*5的值，哪个大用哪个
```


* **mysql配置文件没有设置open_files_limit**

```
cat /etc/my.cnf | grep limit  --没有设置open_files_limit
# open-files-limit = 3000

[root@db10-091 ~]# ulimit -n  --为什么看root用户的ulimit，之前已经讲过原因。
40000

场景一：

root:(none)> show global variables like '%max_conn%';
+--------------------+-------+
| Variable_name      | Value |
+--------------------+-------+
| max_connections    | 100   |
+--------------------+-------+
1 rows in set (0.01 sec)

root:(none)> show global variables like '%open_files_limit%';
+------------------+-------+
| Variable_name    | Value |
+------------------+-------+
| open_files_limit | 40000 |
+------------------+-------+
1 row in set (0.00 sec)


场景二：
root:(none)> show global variables like '%max_connection%';
+-----------------+-------+
| Variable_name   | Value |
+-----------------+-------+
| max_connections | 10000 |
+-----------------+-------+
1 row in set (0.00 sec)

root:(none)> show global variables like '%open_files_limit%';
+------------------+-------+
| Variable_name    | Value |
+------------------+-------+
| open_files_limit | 50000 |
+------------------+-------+
1 row in set (0.00 sec)

结果是：   open_files_limit=50000
计算方式： 当open_files_limit没有被配置的时候，比较max_connections*5和ulimit -n的值，哪个大用哪个

```




 
