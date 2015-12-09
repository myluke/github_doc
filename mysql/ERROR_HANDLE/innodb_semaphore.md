# InnoDB hung&crash : a long semaphore wait 


## 环境


```
* OS
	CentOS release 6.6 (Final)
	Linux 2.6.32-504.el6.x86_64 #1 SMP Wed Oct 15 04:27:16 UTC 2014 x86_64 x86_64 x86_64 GNU/Linux
* disk
	2*SAS raid1 + 6*800G ssd raid5
* MySQL
	MySQL 5.6.16
* memory
	128G

```


## 症状

```
1) MySQL huang 住， 除了show variables 和 show processlist ，其他都做不了。
2）如果过一段时间不管他，会自己crash掉。然后就一直起不来了。
```


## how to repeat

```
M1 -> M2(log_slave_update) -> slave

当M2(log_slave_update) 开启同步后，过1~2小时，M2就会自己crash。如果想加速他的crash，可以写脚本对库里面的表转化表引擎。

* 做过的尝试和修改

1） 关闭AIO功能 ， 但是结果还是一样，会huag住

2） 关闭自适应hash索引,  还是会报同样的错，然后hung住。

https://dev.mysql.com/doc/refman/5.6/en/innodb-adaptive-hash.html

You can monitor the use of the adaptive hash index and the contention for its use in the SEMAPHORES section of the output of the SHOW ENGINE INNODB STATUS command.   
If you see many threads waiting on an RW-latch created in btr0sea.c, then it might be useful to disable adaptive hash indexing.  


```


## MySQL 配置文件

```
[client]
port            = 3306
socket          = /tmp/mysql.sock

[mysqld]
basedir         = /usr/local/mysql
datadir         = /data/mysql_data
port            = 3306
socket          = /tmp/mysql.sock
init-connect='SET NAMES utf8'
character-set-server = utf8

back_log = 500

max_connections = 3500
max_user_connections = 2000
max_connect_errors = 100000

max_allowed_packet = 16M

binlog_cache_size = 1M
max_heap_table_size = 64M
sort_buffer_size = 8M
join_buffer_size = 8M

thread_cache_size = 100
thread_concurrency = 8

query_cache_type = 0
query_cache_size = 0

ft_min_word_len = 4

thread_stack = 192K

tmp_table_size = 64M

# *** Log related settings
log-bin=/data/mysql.bin/xx
binlog-format=ROW
log-error=xx
relay-log=xx-relay-bin
slow_query_log = 1
slow-query-log-file = xx-slow.log
long_query_time = 0.1
log_queries_not_using_indexes = 1
log_slow_admin_statements = 1
log_slow_slave_statements = 1
#log_throttle_queries_not_using_indexes = 10
min_examined_row_limit = 1000

# ***  Replication related settings
server-id = xx
replicate-ignore-db=mysql
replicate-wild-ignore-table=mysql.%
replicate-ignore-db=test
replicate-wild-ignore-table=test.%
##replicate_do_db=c2cdb
##replicate-wild-do-table= c2cdb.%
skip-slave-start
#read_only
log_slave_updates
#innodb_adaptive_hash_index=off

#** Timeout options
wait_timeout = 1800
interactive_timeout = 1800

skip-name-resolve
skip-external-locking
#skip-bdb
#skip-innodb

##*** InnoDB Specific options
default-storage-engine = InnoDB
transaction_isolation = READ-COMMITTED
innodb_file_format=barracuda
innodb_file_format_max=Barracuda
innodb_buffer_pool_size = 95G
innodb_data_file_path = ibdata1:4G:autoextend
innodb_strict_mode = 1
innodb_file_per_table = 1
innodb_write_io_threads=32
innodb_read_io_threads=32
innodb_thread_concurrency = 64
innodb_io_capacity=4000
innodb_io_capacity_max=8000
innodb_flush_log_at_trx_commit = 1
innodb_log_buffer_size = 32M
innodb_log_file_size = 4G
innodb_log_files_in_group = 2
innodb_adaptive_flushing = 1
innodb_lock_wait_timeout = 120
innodb_fast_shutdown = 0

##innodb_status_file
##innodb_open_files
##innodb_table_locks

##5.6 new##
sync_master_info = 10000
sync_relay_log   = 10000
sync_relay_log_info = 10000
relay_log_info_repository = table
master_info_repository = table
sync_binlog = 1

#explicit_defaults_for_timestamp
innodb_buffer_pool_instances = 8
sysdate-is-now
performance_schema
performance_schema_max_table_instances = 30000
sql_mode=
innodb_flush_neighbors=1
innodb_flush_method=O_DIRECT
innodb_old_blocks_time = 1000
innodb_stats_on_metadata = off
innodb_online_alter_log_max_size = 256M
innodb_stats_persistent = on
innodb_stats_auto_recalc = on
table_definition_cache=4096
table_open_cache = 4096
innodb_open_files=4096

[mysqldump]
quick
max_allowed_packet = 16M

[mysql]
default-character-set=utf8
prompt="\\u:\\d> "
pager=more
#tee="/tmp/query.log"
no-auto-rehash

[isamchk]
key_buffer = 512M
sort_buffer_size = 512M
read_buffer = 8M
write_buffer = 8M

[myisamchk]
key_buffer = 512M
sort_buffer_size = 512M
read_buffer = 8M
write_buffer = 8M

[mysqlhotcopy]
interactive-timeout

[mysqld_safe]
open-files-limit = 65535
user = mysql
#nice = -20

```


* error log

```
第一个错误：

----------------------------
END OF INNODB MONITOR OUTPUT
============================
InnoDB: ###### Diagnostic info printed to the standard error stream
InnoDB: Error: semaphore wait has lasted > 600 seconds
InnoDB: We intentionally crash the server, because it appears to be hung.
2015-12-03 00:23:03 7fddc77c9700  InnoDB: Assertion failure in thread 140590511331072 in file srv0srv.cc line 1748
InnoDB: We intentionally generate a memory trap.
InnoDB: Submit a detailed bug report to http://bugs.mysql.com.
InnoDB: If you get repeated assertion failures or crashes, even
InnoDB: immediately after the mysqld startup, there may be
InnoDB: corruption in the InnoDB tablespace. Please refer to
InnoDB: http://dev.mysql.com/doc/refman/5.6/en/forcing-innodb-recovery.html
InnoDB: about forcing recovery.


第二错误： 

2015-11-30 18:08:42 17070 [Note] Check error log for additional messages. You will not be able to start replication until the issue is resolved and the server restarted.
2015-11-30 18:08:42 17070 [Note] Event Scheduler: Loaded 0 events
2015-11-30 18:08:42 17070 [Note] /usr/local/mysql/bin/mysqld: ready for connections.
Version: '5.6.16-log'  socket: '/tmp/mysql.sock'  port: 3306  MySQL Community Server (GPL)
2015-11-30 18:11:36 17070 [Note] 'CHANGE MASTER TO executed'. Previous state master_host='x', master_port= x, master_log_file='', master_log_pos= 4, master_bind=''. New state master_host='x', master_port= 3306, master_log_file='x', master_log_pos= x, master_bind=''.
2015-11-30 18:11:38 17070 [Warning] Storing MySQL user name or password information in the master info repository is not secure and is therefore not recommended. Please consider using the USER and PASSWORD connection options for START SLAVE; see the 'START SLAVE Syntax' in the MySQL Manual for more information.
2015-11-30 18:11:38 17070 [Note] Slave SQL thread initialized, starting replication in log 'x.004942' at position 118512044, relay log './x-relay-bin.000001' position: 4
2015-11-30 18:11:39 17070 [Note] Slave I/O thread: connected to master 'repl@x:3306',replication started in log 'db10-049.004942' at position 118512044
InnoDB: Warning: a long semaphore wait:
--Thread 139611514595072 has waited at sync0rw.cc line 297 for 241.00 seconds the semaphore:
Mutex at 0x1372a40 created file sync0sync.cc line 1472, lock var 1
waiters flag 1
InnoDB: Warning: a long semaphore wait:
--Thread 139611483125504 has waited at btr0cur.cc line 545 for 241.00 seconds the semaphore:
X-lock (wait_ex) on RW-latch at 0xa37b3dc8 created in file dict0dict.cc line 2420
a writer (thread id 139611483125504) has reserved it in mode  wait exclusive
number of readers 1, waiters flag 1, lock_word: ffffffffffffffff
Last time read locked in file btr0cur.cc line 554
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/ibuf/ibuf0ibuf.cc line 409
InnoDB: Warning: a long semaphore wait:
--Thread 139611546064640 has waited at sync0rw.cc line 297 for 241.00 seconds the semaphore:
Mutex at 0x1372a40 created file sync0sync.cc line 1472, lock var 1
waiters flag 1
InnoDB: Warning: a long semaphore wait:
--Thread 139610916673280 has waited at sync0rw.cc line 270 for 241.00 seconds the semaphore:
Mutex at 0x1372a40 created file sync0sync.cc line 1472, lock var 1
waiters flag 1
InnoDB: Warning: a long semaphore wait:
--Thread 139611357247232 has waited at btr0cur.cc line 554 for 241.00 seconds the semaphore:
S-lock on RW-latch at 0xa37b3dc8 created in file dict0dict.cc line 2420
a writer (thread id 139611483125504) has reserved it in mode  wait exclusive
number of readers 1, waiters flag 1, lock_word: ffffffffffffffff
Last time read locked in file btr0cur.cc line 554
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/ibuf/ibuf0ibuf.cc line 409
InnoDB: Warning: a long semaphore wait:
--Thread 139611619493632 has waited at btr0cur.cc line 554 for 241.00 seconds the semaphore:
S-lock on RW-latch at 0xa37b3dc8 created in file dict0dict.cc line 2420
a writer (thread id 139611483125504) has reserved it in mode  wait exclusive
number of readers 1, waiters flag 1, lock_word: ffffffffffffffff
Last time read locked in file btr0cur.cc line 554
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/ibuf/ibuf0ibuf.cc line 409
InnoDB: Warning: a long semaphore wait:
--Thread 139611525084928 has waited at sync0rw.cc line 297 for 241.00 seconds the semaphore:
Mutex at 0x1372a40 created file sync0sync.cc line 1472, lock var 1
waiters flag 1
InnoDB: Warning: a long semaphore wait:
--Thread 139611441166080 has waited at btr0cur.cc line 554 for 241.00 seconds the semaphore:
S-lock on RW-latch at 0xa37b3dc8 created in file dict0dict.cc line 2420
a writer (thread id 139611483125504) has reserved it in mode  wait exclusive
number of readers 1, waiters flag 1, lock_word: ffffffffffffffff
Last time read locked in file btr0cur.cc line 554
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/ibuf/ibuf0ibuf.cc line 409
InnoDB: Warning: a long semaphore wait:
--Thread 139719716267776 has waited at buf0buf.cc line 2457 for 241.00 seconds the semaphore:
S-lock on RW-latch at 0x7f098dc11540 created in file buf0buf.cc line 996
a writer (thread id 139719716267776) has reserved it in mode  exclusive
number of readers 0, waiters flag 1, lock_word: 0
Last time read locked in file not yet reserved line 0
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/buf/buf0buf.cc line 3579
InnoDB: Warning: a long semaphore wait:
--Thread 139610260764416 has waited at btr0cur.cc line 554 for 241.00 seconds the semaphore:
S-lock on RW-latch at 0xa37b3dc8 created in file dict0dict.cc line 2420
a writer (thread id 139611483125504) has reserved it in mode  wait exclusive
number of readers 1, waiters flag 1, lock_word: ffffffffffffffff
Last time read locked in file btr0cur.cc line 554
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/ibuf/ibuf0ibuf.cc line 409
InnoDB: ###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
InnoDB: Pending preads 0, pwrites 0

=====================================
2015-11-30 20:33:03 7ef9b3b86700 INNODB MONITOR OUTPUT
=====================================
Per second averages calculated from the last 60 seconds
-----------------
BACKGROUND THREAD
-----------------
srv_master_thread loops: 8135 srv_active, 0 srv_shutdown, 175 srv_idle
srv_master_thread log flush and writes: 8309
----------
SEMAPHORES
----------
OS WAIT ARRAY INFO: reservation count 66048
--Thread 139611514595072 has waited at sync0rw.cc line 297 for 251.00 seconds the semaphore:
Mutex at 0x1372a40 created file sync0sync.cc line 1472, lock var 1
waiters flag 1
--Thread 139611483125504 has waited at btr0cur.cc line 545 for 251.00 seconds the semaphore:
X-lock (wait_ex) on RW-latch at 0xa37b3dc8 created in file dict0dict.cc line 2420
a writer (thread id 139611483125504) has reserved it in mode  wait exclusive
number of readers 1, waiters flag 1, lock_word: ffffffffffffffff
Last time read locked in file btr0cur.cc line 554
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/ibuf/ibuf0ibuf.cc line 409
--Thread 139611546064640 has waited at sync0rw.cc line 297 for 251.00 seconds the semaphore:
Mutex at 0x1372a40 created file sync0sync.cc line 1472, lock var 1
waiters flag 1
--Thread 139610916673280 has waited at sync0rw.cc line 270 for 251.00 seconds the semaphore:
Mutex at 0x1372a40 created file sync0sync.cc line 1472, lock var 1
waiters flag 1
--Thread 139611357247232 has waited at btr0cur.cc line 554 for 251.00 seconds the semaphore:
S-lock on RW-latch at 0xa37b3dc8 created in file dict0dict.cc line 2420
a writer (thread id 139611483125504) has reserved it in mode  wait exclusive
number of readers 1, waiters flag 1, lock_word: ffffffffffffffff
Last time read locked in file btr0cur.cc line 554
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/ibuf/ibuf0ibuf.cc line 409
--Thread 139611619493632 has waited at btr0cur.cc line 554 for 251.00 seconds the semaphore:
S-lock on RW-latch at 0xa37b3dc8 created in file dict0dict.cc line 2420
a writer (thread id 139611483125504) has reserved it in mode  wait exclusive
number of readers 1, waiters flag 1, lock_word: ffffffffffffffff
Last time read locked in file btr0cur.cc line 554
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/ibuf/ibuf0ibuf.cc line 409
--Thread 139611525084928 has waited at sync0rw.cc line 297 for 251.00 seconds the semaphore:
Mutex at 0x1372a40 created file sync0sync.cc line 1472, lock var 1
waiters flag 1
--Thread 139611441166080 has waited at btr0cur.cc line 554 for 251.00 seconds the semaphore:
S-lock on RW-latch at 0xa37b3dc8 created in file dict0dict.cc line 2420
a writer (thread id 139611483125504) has reserved it in mode  wait exclusive
number of readers 1, waiters flag 1, lock_word: ffffffffffffffff
Last time read locked in file btr0cur.cc line 554
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/ibuf/ibuf0ibuf.cc line 409
--Thread 139719716267776 has waited at buf0buf.cc line 2457 for 251.00 seconds the semaphore:
S-lock on RW-latch at 0x7f098dc11540 created in file buf0buf.cc line 996
a writer (thread id 139719716267776) has reserved it in mode  exclusive
number of readers 0, waiters flag 1, lock_word: 0
Last time read locked in file not yet reserved line 0
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/buf/buf0buf.cc line 3579
--Thread 139610260764416 has waited at btr0cur.cc line 554 for 251.00 seconds the semaphore:
S-lock on RW-latch at 0xa37b3dc8 created in file dict0dict.cc line 2420
a writer (thread id 139611483125504) has reserved it in mode  wait exclusive
number of readers 1, waiters flag 1, lock_word: ffffffffffffffff
Last time read locked in file btr0cur.cc line 554
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/ibuf/ibuf0ibuf.cc line 409
--Thread 139610895693568 has waited at buf0flu.cc line 1064 for 244.00 seconds the semaphore:
S-lock on RW-latch at 0x7f09893f2340 created in file buf0buf.cc line 996
a writer (thread id 139611525084928) has reserved it in mode  exclusive
number of readers 0, waiters flag 1, lock_word: 0
Last time read locked in file btr0cur.cc line 265
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/btr/btr0cur.cc line 265
OS WAIT ARRAY INFO: signal count 82316
Mutex spin waits 5723675, rounds 5019676, OS waits 27829
RW-shared spins 68787, rounds 1361576, OS waits 31392
RW-excl spins 47999, rounds 493233, OS waits 5902
Spin rounds per wait: 0.88 mutex, 19.79 RW-shared, 10.28 RW-excl
------------
TRANSACTIONS
------------
Trx id counter 39221621177
Purge done for trx's n:o < 39221621177 undo n:o < 0 state: running but idle
History list length 2003
LIST OF TRANSACTIONS FOR EACH SESSION:
---TRANSACTION 39221621175, not started
MySQL thread id 2, OS thread handle 0x7f13080b5700, query id 0 Waiting for master to send event
---TRANSACTION 39221620820, ACTIVE 251 sec inserting
mysql tables in use 1, locked 1
1 lock struct(s), heap size 360, 0 row lock(s), undo log entries 1
MySQL thread id 3, OS thread handle 0x7ef98bfff700, query id 28601706 System lock
---TRANSACTION 39221511555, ACTIVE 300 sec fetching rows, thread declared inside InnoDB 1853
mysql tables in use 1, locked 1
27937 lock struct(s), heap size 3405352, 7514649 row lock(s)
MySQL thread id 981, OS thread handle 0x7f13080e6700, query id 28351219 localhost dbadmin copy to tmp table
alter table user_pool_20150318 engine=MyISAM
--------
FILE I/O
--------
I/O thread 0 state: waiting for i/o request (insert buffer thread)
I/O thread 1 state: waiting for i/o request (log thread)
I/O thread 2 state: complete io for buf page (read thread) ev set
I/O thread 3 state: waiting for i/o request (read thread)
I/O thread 4 state: waiting for i/o request (read thread)
I/O thread 5 state: waiting for i/o request (read thread)
I/O thread 6 state: waiting for i/o request (read thread)
I/O thread 7 state: waiting for i/o request (read thread)
I/O thread 8 state: waiting for i/o request (read thread)
I/O thread 9 state: complete io for buf page (read thread) ev set
I/O thread 10 state: waiting for i/o request (read thread)
I/O thread 11 state: complete io for buf page (read thread) ev set
I/O thread 12 state: complete io for buf page (read thread) ev set
I/O thread 13 state: waiting for i/o request (read thread)
I/O thread 14 state: waiting for i/o request (read thread)
I/O thread 15 state: complete io for buf page (read thread) ev set
I/O thread 16 state: complete io for buf page (read thread) ev set
I/O thread 17 state: waiting for i/o request (read thread)
I/O thread 18 state: waiting for i/o request (read thread)
I/O thread 19 state: complete io for buf page (read thread) ev set
I/O thread 20 state: waiting for i/o request (read thread)
I/O thread 21 state: waiting for i/o request (read thread)
I/O thread 22 state: waiting for i/o request (read thread)
I/O thread 23 state: waiting for i/o request (read thread)
I/O thread 24 state: waiting for i/o request (read thread)
I/O thread 25 state: waiting for i/o request (read thread)
I/O thread 26 state: waiting for i/o request (read thread)
I/O thread 27 state: complete io for buf page (read thread) ev set
I/O thread 28 state: waiting for i/o request (read thread)
I/O thread 29 state: waiting for i/o request (read thread)
I/O thread 30 state: waiting for i/o request (read thread)
I/O thread 31 state: waiting for i/o request (read thread)
I/O thread 32 state: waiting for i/o request (read thread)
I/O thread 33 state: waiting for i/o request (read thread)
I/O thread 34 state: waiting for i/o request (write thread)
I/O thread 35 state: waiting for i/o request (write thread)
I/O thread 36 state: waiting for i/o request (write thread)
I/O thread 37 state: waiting for i/o request (write thread)
I/O thread 38 state: waiting for i/o request (write thread)
I/O thread 39 state: waiting for i/o request (write thread)
I/O thread 40 state: waiting for i/o request (write thread)
I/O thread 41 state: waiting for i/o request (write thread)
I/O thread 42 state: waiting for i/o request (write thread)
I/O thread 43 state: waiting for i/o request (write thread)
I/O thread 44 state: waiting for i/o request (write thread)
I/O thread 45 state: waiting for i/o request (write thread)
I/O thread 46 state: waiting for i/o request (write thread)
I/O thread 47 state: waiting for i/o request (write thread)
I/O thread 48 state: waiting for i/o request (write thread)
I/O thread 49 state: waiting for i/o request (write thread)
I/O thread 50 state: waiting for i/o request (write thread)
I/O thread 51 state: waiting for i/o request (write thread)
I/O thread 52 state: waiting for i/o request (write thread)
I/O thread 53 state: waiting for i/o request (write thread)
I/O thread 54 state: waiting for i/o request (write thread)
I/O thread 55 state: waiting for i/o request (write thread)
I/O thread 56 state: waiting for i/o request (write thread)
I/O thread 57 state: waiting for i/o request (write thread)
I/O thread 58 state: waiting for i/o request (write thread)
I/O thread 59 state: waiting for i/o request (write thread)
I/O thread 60 state: waiting for i/o request (write thread)
I/O thread 61 state: waiting for i/o request (write thread)
I/O thread 62 state: waiting for i/o request (write thread)
I/O thread 63 state: waiting for i/o request (write thread)
I/O thread 64 state: waiting for i/o request (write thread)
I/O thread 65 state: waiting for i/o request (write thread)
Pending normal aio reads: 100 [5, 0, 0, 0, 0, 0, 0, 7, 0, 3, 70, 0, 0, 4, 2, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0] , aio writes: 0 [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] ,
 ibuf aio reads: 0, log i/o's: 0, sync i/o's: 0
Pending flushes (fsync) log: 0; buffer pool: 0
270736 OS file reads, 396343 OS file writes, 132039 OS fsyncs
0.00 reads/s, 0 avg bytes/read, 0.00 writes/s, 0.00 fsyncs/s
-------------------------------------
INSERT BUFFER AND ADAPTIVE HASH INDEX
-------------------------------------
InnoDB: ###### Diagnostic info printed to the standard error stream
InnoDB: Warning: a long semaphore wait:
--Thread 139611514595072 has waited at sync0rw.cc line 297 for 272.00 seconds the semaphore:
Mutex at 0x1372a40 created file sync0sync.cc line 1472, lock var 1
waiters flag 1
InnoDB: Warning: a long semaphore wait:
--Thread 139611483125504 has waited at btr0cur.cc line 545 for 272.00 seconds the semaphore:
X-lock (wait_ex) on RW-latch at 0xa37b3dc8 created in file dict0dict.cc line 2420
a writer (thread id 139611483125504) has reserved it in mode  wait exclusive
number of readers 1, waiters flag 1, lock_word: ffffffffffffffff
Last time read locked in file btr0cur.cc line 554
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/ibuf/ibuf0ibuf.cc line 409
InnoDB: Warning: a long semaphore wait:
--Thread 139611546064640 has waited at sync0rw.cc line 297 for 272.00 seconds the semaphore:
Mutex at 0x1372a40 created file sync0sync.cc line 1472, lock var 1
waiters flag 1
InnoDB: Warning: a long semaphore wait:
--Thread 139610916673280 has waited at sync0rw.cc line 270 for 272.00 seconds the semaphore:
Mutex at 0x1372a40 created file sync0sync.cc line 1472, lock var 1
waiters flag 1
InnoDB: Warning: a long semaphore wait:
--Thread 139611357247232 has waited at btr0cur.cc line 554 for 272.00 seconds the semaphore:
S-lock on RW-latch at 0xa37b3dc8 created in file dict0dict.cc line 2420
a writer (thread id 139611483125504) has reserved it in mode  wait exclusive
number of readers 1, waiters flag 1, lock_word: ffffffffffffffff
Last time read locked in file btr0cur.cc line 554
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/ibuf/ibuf0ibuf.cc line 409
InnoDB: Warning: a long semaphore wait:
--Thread 139611619493632 has waited at btr0cur.cc line 554 for 272.00 seconds the semaphore:
S-lock on RW-latch at 0xa37b3dc8 created in file dict0dict.cc line 2420
a writer (thread id 139611483125504) has reserved it in mode  wait exclusive
number of readers 1, waiters flag 1, lock_word: ffffffffffffffff
Last time read locked in file btr0cur.cc line 554
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/ibuf/ibuf0ibuf.cc line 409
InnoDB: Warning: a long semaphore wait:
--Thread 139611525084928 has waited at sync0rw.cc line 297 for 272.00 seconds the semaphore:
Mutex at 0x1372a40 created file sync0sync.cc line 1472, lock var 1
waiters flag 1
InnoDB: Warning: a long semaphore wait:
--Thread 139611441166080 has waited at btr0cur.cc line 554 for 272.00 seconds the semaphore:
S-lock on RW-latch at 0xa37b3dc8 created in file dict0dict.cc line 2420
a writer (thread id 139611483125504) has reserved it in mode  wait exclusive
number of readers 1, waiters flag 1, lock_word: ffffffffffffffff
Last time read locked in file btr0cur.cc line 554
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/ibuf/ibuf0ibuf.cc line 409
InnoDB: Warning: a long semaphore wait:
--Thread 139719716267776 has waited at buf0buf.cc line 2457 for 272.00 seconds the semaphore:
S-lock on RW-latch at 0x7f098dc11540 created in file buf0buf.cc line 996
a writer (thread id 139719716267776) has reserved it in mode  exclusive
number of readers 0, waiters flag 1, lock_word: 0
Last time read locked in file not yet reserved line 0
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/buf/buf0buf.cc line 3579
InnoDB: Warning: a long semaphore wait:
--Thread 139610260764416 has waited at btr0cur.cc line 554 for 272.00 seconds the semaphore:
S-lock on RW-latch at 0xa37b3dc8 created in file dict0dict.cc line 2420
a writer (thread id 139611483125504) has reserved it in mode  wait exclusive
number of readers 1, waiters flag 1, lock_word: ffffffffffffffff
Last time read locked in file btr0cur.cc line 554
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/ibuf/ibuf0ibuf.cc line 409
InnoDB: Warning: a long semaphore wait:
--Thread 139610895693568 has waited at buf0flu.cc line 1064 for 265.00 seconds the semaphore:
S-lock on RW-latch at 0x7f09893f2340 created in file buf0buf.cc line 996
a writer (thread id 139611525084928) has reserved it in mode  exclusive
number of readers 0, waiters flag 1, lock_word: 0
Last time read locked in file btr0cur.cc line 265
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/btr/btr0cur.cc line 265
InnoDB: ###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
InnoDB: Pending preads 0, pwrites 0
InnoDB: ###### Diagnostic info printed to the standard error stream
InnoDB: Warning: a long semaphore wait:
--Thread 139611514595072 has waited at sync0rw.cc line 297 for 303.00 seconds the semaphore:
Mutex at 0x1372a40 created file sync0sync.cc line 1472, lock var 1
waiters flag 1
InnoDB: Warning: a long semaphore wait:
--Thread 139611483125504 has waited at btr0cur.cc line 545 for 303.00 seconds the semaphore:
X-lock (wait_ex) on RW-latch at 0xa37b3dc8 created in file dict0dict.cc line 2420
a writer (thread id 139611483125504) has reserved it in mode  wait exclusive
number of readers 1, waiters flag 1, lock_word: ffffffffffffffff
Last time read locked in file btr0cur.cc line 554
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/ibuf/ibuf0ibuf.cc line 409
InnoDB: Warning: a long semaphore wait:
--Thread 139611546064640 has waited at sync0rw.cc line 297 for 303.00 seconds the semaphore:
Mutex at 0x1372a40 created file sync0sync.cc line 1472, lock var 1
waiters flag 1
InnoDB: Warning: a long semaphore wait:
--Thread 139610916673280 has waited at sync0rw.cc line 270 for 303.00 seconds the semaphore:
Mutex at 0x1372a40 created file sync0sync.cc line 1472, lock var 1
waiters flag 1
InnoDB: Warning: a long semaphore wait:
--Thread 139611357247232 has waited at btr0cur.cc line 554 for 303.00 seconds the semaphore:
S-lock on RW-latch at 0xa37b3dc8 created in file dict0dict.cc line 2420
a writer (thread id 139611483125504) has reserved it in mode  wait exclusive
number of readers 1, waiters flag 1, lock_word: ffffffffffffffff
Last time read locked in file btr0cur.cc line 554
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/ibuf/ibuf0ibuf.cc line 409
InnoDB: Warning: a long semaphore wait:
--Thread 139611619493632 has waited at btr0cur.cc line 554 for 303.00 seconds the semaphore:
S-lock on RW-latch at 0xa37b3dc8 created in file dict0dict.cc line 2420
a writer (thread id 139611483125504) has reserved it in mode  wait exclusive
number of readers 1, waiters flag 1, lock_word: ffffffffffffffff
Last time read locked in file btr0cur.cc line 554
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/ibuf/ibuf0ibuf.cc line 409
InnoDB: Warning: a long semaphore wait:
--Thread 139611525084928 has waited at sync0rw.cc line 297 for 303.00 seconds the semaphore:
Mutex at 0x1372a40 created file sync0sync.cc line 1472, lock var 1
waiters flag 1
InnoDB: Warning: a long semaphore wait:
--Thread 139611441166080 has waited at btr0cur.cc line 554 for 303.00 seconds the semaphore:
S-lock on RW-latch at 0xa37b3dc8 created in file dict0dict.cc line 2420
a writer (thread id 139611483125504) has reserved it in mode  wait exclusive
number of readers 1, waiters flag 1, lock_word: ffffffffffffffff
Last time read locked in file btr0cur.cc line 554
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/ibuf/ibuf0ibuf.cc line 409
InnoDB: Warning: a long semaphore wait:
--Thread 139719716267776 has waited at buf0buf.cc line 2457 for 303.00 seconds the semaphore:
S-lock on RW-latch at 0x7f098dc11540 created in file buf0buf.cc line 996
a writer (thread id 139719716267776) has reserved it in mode  exclusive
number of readers 0, waiters flag 1, lock_word: 0
Last time read locked in file not yet reserved line 0
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/buf/buf0buf.cc line 3579
InnoDB: Warning: a long semaphore wait:
--Thread 139610260764416 has waited at btr0cur.cc line 554 for 303.00 seconds the semaphore:
S-lock on RW-latch at 0xa37b3dc8 created in file dict0dict.cc line 2420
a writer (thread id 139611483125504) has reserved it in mode  wait exclusive
number of readers 1, waiters flag 1, lock_word: ffffffffffffffff
Last time read locked in file btr0cur.cc line 554
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/ibuf/ibuf0ibuf.cc line 409
InnoDB: Warning: a long semaphore wait:
--Thread 139610895693568 has waited at buf0flu.cc line 1064 for 296.00 seconds the semaphore:
S-lock on RW-latch at 0x7f09893f2340 created in file buf0buf.cc line 996
a writer (thread id 139611525084928) has reserved it in mode  exclusive
number of readers 0, waiters flag 1, lock_word: 0
Last time read locked in file btr0cur.cc line 265
Last time write locked in file /export/home/pb2/build/sb_0-11248666-1389714123.71/mysql-5.6.16/storage/innobase/btr/btr0cur.cc line 265
InnoDB: ###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
InnoDB: Pending preads 0, pwrites 0
InnoDB: ###### Diagnostic info printed to the standard error stream

```

期间，本想对有问题的MySQL进行strace跟踪，看看出错后发生了什么。

结果，开启strace，他却没有发生故障，如果你再次关闭strace，不久立马报错。

尝试过的解决方案：

1）echo "kernel.sem=250 32000 100 128″>>/etc/sysctl.conf   

2）设置 innodb innodb_adaptive_hash_index=OFF  

均无效果。  


这时，已哭晕在厕所，醒来之后开始模拟测试各种场景。



## 测试手法

* **1 . M-M(log_slave_update)-S**

* **2 . set trx=0 & alter table engine=Myisam & start slave**



## 测试方案
 
### 第一轮测试（无厘头测试）

* MySQL 5.6.16 ROW AIO 边转换表引擎，边级联复制 

```
1.0) 天津机房： centos6.6  二进制安装       aio=ON or aio=OFF  结果：crash
1.1) 天津机房 ：centos6.6  源码编译安装     aio=ON  结果：crash
1.2) 天津机房： centos6.6  二进制安装 开启strace 
	结果：
		* 没有crash，但是有如下错误
		* InnoDB: unable to purge a record
		* Enabling keys got errno 127 on aifang_adm.#sql-5d39_12d9, retrying
1.3) 天津机房: centos6.6 二进制安装 dw load压力测试
	结果： ？

1.4) 天津机房: centos6.6 二进制安装, yum erase libaio 结果：

2.1) 上海机房： redhat6.x 二进制安装     aio=ON  结果：ok
2.2）上海机房： redhat6.x 源码编译安装   aio=OFF 结果：ok
```

* MySQL 5.6.27 ROW AIO 边转换表引擎，边级联复制

```
1.0) 天津机房：  centos6.6 二进制安装       aio=ON or aio=OFF  结果：?
1.1) 天津机房 ： centos6.6 源码编译安装    aio=ON  结果：？
1.3) 天津机房: centos6.6 二进制安装 dw load压力测试
    结果： ？
2.1) 上海机房：  redhat6.x 二进制安装     aio=ON  结果：ok
2.2）上海机房：  redhat6.x 源码编译安装   aio=OFF 结果: ok
```


测试方式|机房|memory|OS版本|OS内核|MySQL版本|MySQL安装方式|innodb_use_native_aio|libaio是否安装|测试结果|补充|
----|----|----|----|----|----|----|----|----|----|----|
ROW 模式，边转换表引擎，边级联复制|天津|128G|centos6.6|2.6.32-504.el6.x86_64|5.6.16|binary|ON or OFF|yes|crash|-
ROW 模式，边转换表引擎，边级联复制|天津|128G|centos6.6|2.6.32-504.el6.x86_64|5.6.16|source|ON or OFF|yes|crash|-
ROW 模式，边转换表引擎，边级联复制|天津|128G|centos6.6|2.6.32-504.el6.x86_64|5.6.16|binary|ON or OFF|yes|problem|开启strace后，没有crash
ROW 模式，边转换表引擎，边级联复制|天津|128G|centos6.6|2.6.32-504.el6.x86_64|5.6.16|binary|OFF|no|无法启动mysql|-
ROW 模式，边转换表引擎，边级联复制|天津|128G|centos6.6|2.6.32-504.el6.x86_64|5.6.16|source|OFF|no|ok|-
ROW 模式，边转换表引擎，边级联复制|天津|128G|centos6.6|2.6.32-504.23.4.el6.x86_64|5.6.16|binary|ON or OFF|yes|?|-
ROW 模式，边转换表引擎，边级联复制|天津|128G|centos6.6|2.6.32-504.23.4.el6.x86_64|5.6.16|source|ON or OFF|yes|?|-
ROW 模式，大量load数据|天津|128G|centos6.6|2.6.32-504.el6.x86_64|5.6.16|binary|ON|yes|?|-
ROW 模式，边转换表引擎，边级联复制|天津|64G|centos6.6|2.6.32-504.el6.x86_64|5.6.16|binary|ON or OFF|yes|crash|-
ROW 模式，边转换表引擎，边级联复制|天津|64G|centos6.6|2.6.32-504.el6.x86_64|5.6.16|source|ON or OFF|yes|crash|-
ROW 模式，边转换表引擎，边级联复制|上海|128G|redhat6.5|2.6.32-504.el6.x86_64|5.6.16|binary|ON or OFF|yes|ok|-
ROW 模式，边转换表引擎，边级联复制|上海|128G|redhat6.5|2.6.32-504.el6.x86_64|5.6.16|source|OFF|yes|ok|-
ROW 模式，边转换表引擎，边级联复制|天津|128G|centos6.6|2.6.32-504.el6.x86_64|5.6.27|binary|ON or OFF|yes|?|-
ROW 模式，边转换表引擎，边级联复制|天津|128G|centos6.6|2.6.32-504.el6.x86_64|5.6.27|source|ON or OFF|yes|?|-
ROW 模式，边转换表引擎，边级联复制|天津|128G|centos6.6|2.6.32-504.el6.x86_64|5.6.27|binary|ON or OFF|yes|ok|开启strace后，没有crash
ROW 模式，边转换表引擎，边级联复制|天津|128G|centos6.6|2.6.32-504.el6.x86_64|5.6.27|binary|OFF|no|?|-
ROW 模式，边转换表引擎，边级联复制|天津|128G|centos6.6|2.6.32-504.el6.x86_64|5.6.27|source|OFF|no|?|-
ROW 模式，边转换表引擎，边级联复制|天津|128G|centos6.6|2.6.32-504.23.4.el6.x86_64|5.6.27|binary|ON or OFF|yes|?|-
ROW 模式，边转换表引擎，边级联复制|天津|128G|centos6.6|2.6.32-504.23.4.el6.x86_64|5.6.27|source|ON or OFF|yes|?|-
ROW 模式，大量load数据|天津|128G|centos6.6|2.6.32-504.el6.x86_64|5.6.27|binary|ON|yes|?|-
ROW 模式，边转换表引擎，边级联复制|上海|128G|redhat6.5|2.6.32-504.el6.x86_64|5.6.27|binary|ON or OFF|yes|ok|-
ROW 模式，边转换表引擎，边级联复制|上海|128G|redhat6.5|2.6.32-504.el6.x86_64|5.6.27|source|OFF|yes|ok|-

经过第一轮测试，大致得到以下结论,初步怀疑是硬件故障：

* **1. 部分机器dmesg : hpsa 0000:03:00.0: out of memory**

```
网上搜索 & 联系HP官方 得到的答复是：驱动升级

1) https://access.redhat.com/solutions/1248173 
2) http://h20564.www2.hpe.com/hpsc/doc/public/display?docId=c04302261&lang=en-us&cc=us

```

不过，再升级之前，我又做了以下测试, 想验证除了硬件故障外，是否还有其他猫腻：

第二波测试：

id|内存|OS|aio|是否有out of memory|MySQL版本|测试方法|结果|补充
----|----|----|----|----|----|----|----|----
1|128G|redhat6.5|innodb_use_native_aio=on|no|5.6.16|OLAP压测|ok|-
2|128G|redhat6.5|innodb_use_native_aio=on|no|5.6.27|OLAP压测|ok|-
3|128G|centos6.6|innodb_use_native_aio=off|no|5.6.16|OLAP压测|ok|-
4|128G|centos6.6|innodb_use_native_aio=off|no|5.6.27|OLAP压测|ok|-
5|128G|centos6.6|innodb_use_native_aio=on|yes|5.6.16|OLAP压测|crash|-
6|128G|centos6.6|innodb_use_native_aio=on|yes|5.6.27|OLAP压测|ok|-
7|128G|centos6.6|innodb_use_native_aio=off|yes|5.6.27|OLAP压测|ok|-
8|128G|centos6.6|innodb_use_native_aio=off|yes|5.6.16|OLAP压测|crash|-
9|128G|centos6.6|innodb_use_native_aio=on|yes|5.6.16|追同步测试|crash|-
10|128G|centos6.6|innodb_use_native_aio=on|yes|5.6.27|追同步测试|ok|-
11|128G|centos6.6|innodb_use_native_aio=on|no|5.6.16|追同步测试|ok|-
12|128G|centos6.6|innodb_use_native_aio=on|no|5.6.27|追同步测试|ok|-
13|128G|centos6.6|innodb_use_native_aio=off|yes|5.6.27|追同步测试|ok|-
14|128G|centos6.6|innodb_use_native_aio=on|yes|5.6.27|追同步测试|ok|-
14|128G|centos6.6|innodb_use_native_aio=off|no，驱动升级|5.6.16|追同步测试|crash|-
15|128G|centos6.6|innodb_use_native_aio=on|no，驱动升级|5.6.27|追同步测试|ok|-

## 测试表示

* **1. MySQL5.6.27 在各方面都ok，没有报错**

* **2. MySQL5.6.16 在硬件完全没问题的机器上ok，不会报错**

## 总结

* **1. 硬件知识需要多学习，自动化检测,硬件监控需加强**

* **2. Linux 调优与故障诊断需要加强**

> 善于利用dmesg,对/var/log/kernel.log & /var/log/messges 信息要过于敏感。

* **3. 要经常翻MySQL的release note，多关注bug的修复，做到心中有数**

* **4. 测试非常重要，自动化压力测试和基准测试，可以提前发现很多问题**

* **5. 态度，情怀，毅力最重要，要怀抱敬畏之心**


## 最后方案

1. 从以上测试得知，并非完全是硬件问题，但又和硬件相关。 MySQL5.6.27 的稳定性 要优于 MySQL5.6.16，所以升级是王道。

2. 但是由于线上还有5.1，5.5 的服务，所以还是不要用有问题的机器。




最后感谢为此付出努力和帮助过我的同学们，接下来继续填坑吧，走起。。。

