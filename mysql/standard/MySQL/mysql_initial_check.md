# MySQL 初始化检查

---

## io scheduler

```
原则：
	SAS =>  deadline
	SSD =>  noop or  deadline

echo deadline > /sys/block/$disk/queue/scheduler  --动态调整
```


## 文件系统XFS

```
mkfs.xfs -f -d agcount=32 -l size=128m -L /data /dev/$disk

vi /etc/fstab 
        将原来的 
        LABEL=/data /data ext3 noatime 1 2 
        改成 
        LABEL=/data /data xfs noatime,nodiratime,osyncisdsync,inode64 0 0 
        或 
        /dev/sda8 /data xfs noatime,nodiratime,osyncisdsync,inode64 0 0 
```


## 安装包预先安装

```
1) perl-DBD-mysql , nc , cmake,ncurses-devel, wireshark ...

yum install perl-DBD-mysql -y;
yum install cmake -y;
yum install ncurses-devel -y;

yum install nc -y;
yum install wireshark -y;

2) libaio-devel，zlib-devel，openssl-devel，libevent-devel，perl-Socket6，perl-Time-HiRes
```

## online mysql check by daily

```
* my.cnf : read_only=on

* my.cnf : wait_timeout=60,interactive_timeout=60; 这两值必须一样，否则以interactive_timeout为主 
原理
1. wait_timeout & interactive_timeout 只针对sleep状态的链接有效。
2. sleep=10 ， 并不是代表这个链接闲置了 10秒，而表示query+sleep的总和。	
	 例如： sleep（10s => show processlits看到的） = query（1s => 执行query的时间） + sleep（9s => 真实sleep的时间）
	 
3. 假设：wait_timeout & interactive_timeout = 10s （简称变量$time_out）
   那么：什么时候会被自动killed 呢？
   
   情景1：Query（3s）+ Sleep（$time_out=10s） = Sleep（13秒 show processlits看到的） -- 会被kill掉
   
   情景2：Query（15s）+ Sleep（$time_out=10s） = Sleep（25秒 show processlits看到的）-- 会被kill掉



* master影响io的参数(酌情处理)
	sync_binlog = N;
	innodb_flush_logs_at_trx_commit={0|1|2}

* slave影响io的参数（酌情处理）
	sync_relay_log =N;
	innodb_flush_logs_at_trx_commit={0|1|2}
```

## MySQL 配置文件


* old: https://github.com/Keithlan/file_md/blob/master/Keithlan/mysql/Mysql_upgrade/51_to_56.md

* from innoSQL:

```
[client]
user=david
password=88888888

[mysqld]
########basic settings########
server-id = 11 
port = 3306
user = mysql
bind_address = 10.166.224.32
autocommit = 0
character_set_server=utf8mb4
skip_name_resolve = 1
max_connections = 800
max_connect_errors = 1000
datadir = /data/mysql_data
transaction_isolation = READ-COMMITTED
explicit_defaults_for_timestamp = 1
join_buffer_size = 134217728
tmp_table_size = 67108864
tmpdir = /tmp
max_allowed_packet = 16777216
sql_mode = "STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER"
interactive_timeout = 1800
wait_timeout = 1800
read_buffer_size = 16777216
read_rnd_buffer_size = 33554432
sort_buffer_size = 33554432
########log settings########
log_error = error.log
slow_query_log = 1
slow_query_log_file = slow.log
log_queries_not_using_indexes = 1
log_slow_admin_statements = 1
log_slow_slave_statements = 1
log_throttle_queries_not_using_indexes = 10
expire_logs_days = 90
long_query_time = 2
min_examined_row_limit = 100
########replication settings########
master_info_repository = TABLE
relay_log_info_repository = TABLE
log_bin = bin.log
sync_binlog = 1
gtid_mode = on
enforce_gtid_consistency = 1
log_slave_updates
binlog_format = row 
relay_log = relay.log
relay_log_recovery = 1
binlog_gtid_simple_recovery = 1
slave_skip_errors = ddl_exist_errors
########innodb settings########
innodb_page_size = 8192
innodb_buffer_pool_size = 6G
innodb_buffer_pool_instances = 8
innodb_buffer_pool_load_at_startup = 1
innodb_buffer_pool_dump_at_shutdown = 1
innodb_lru_scan_depth = 2000
innodb_lock_wait_timeout = 5
innodb_io_capacity = 4000
innodb_io_capacity_max = 8000
innodb_flush_method = O_DIRECT
innodb_file_format = Barracuda
innodb_file_format_max = Barracuda
innodb_log_group_home_dir = /redolog/
innodb_undo_directory = /undolog/
innodb_undo_logs = 128
innodb_undo_tablespaces = 3
innodb_flush_neighbors = 1
innodb_log_file_size = 4G
innodb_log_buffer_size = 16777216
innodb_purge_threads = 4
innodb_large_prefix = 1
innodb_thread_concurrency = 64
innodb_print_all_deadlocks = 1
innodb_strict_mode = 1
innodb_sort_buffer_size = 67108864 
########semi sync replication settings########
plugin_dir=/usr/local/mysql/lib/plugin
plugin_load = "rpl_semi_sync_master=semisync_master.so;rpl_semi_sync_slave=semisync_slave.so"
loose_rpl_semi_sync_master_enabled = 1
loose_rpl_semi_sync_slave_enabled = 1
loose_rpl_semi_sync_master_timeout = 5000

[mysqld-5.7]
innodb_buffer_pool_dump_pct = 40
innodb_page_cleaners = 4
innodb_undo_log_truncate = 1
innodb_max_undo_log_size = 2G
innodb_purge_rseg_truncate_frequency = 128
binlog_gtid_simple_recovery=1
log_timestamps=system
transaction_write_set_extraction=MURMUR32
show_compatibility_56=on

```



* **128G SSD InnoDB 5.6**


```

```

* **128G SSD Myisam 5.6**

```

```

* **128G SAS InnoDB 5.6**

```

```

* **128G SAS Myisam 5.6**


```

```


