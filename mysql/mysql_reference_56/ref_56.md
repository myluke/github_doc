# Mysql5.6 新特性
>

---


## 第一章：基本信息

---

### ```1.4__ Mysql5.6 的新特性```

#### 新增的特性
---

* **安全方面的增强**
	* mysql 提供存放认真信息在 .mylogin.cnf,“mysql_config_editor — MySQL Configuration Utility”
	
	* mysql 提供更加强大的用户密码加密，sha256_password
	
	* mysql.user 现在可以设置过期用户
	
	* mysql_upgrade如果发现用户密码hasded with older 4.1版本的方法，会提示警告。
	
	* mysql_install_db 支持随机密码选项，更加安全的mysql 安装
	
	* start slave 语法，目前已经支持connection信息，用户可以考虑是否需要将信息保存在master.info
	
* **Mysql 企业版**

* **mysql 默认参数的变更，可参考Section 5.1.2.1, “Changes to Server Defaults”.**	
* **InnoDB的增强**
	* innoDB支持全文索引
	
	* Online ddl
	
	* InnoDB 支持将某一个表，单独指定存放在某一块磁盘上
	
	* InnoDB 支持transportable tablespaces，可以在线导出导入innoDB表空间
	
	* 可以指定innoDB pagesize大小到 8k，4k，默认是16k
	
	* 自适应刷新算法的增强，可以提高更高的并发。调优可参考： Section 14.3.3.6, “Tuning InnoDB Buffer Pool Flushing”
	
	* 可以通过NoSQL-style API 访问innoDB 表。详情：Section 14.17, “InnoDB Integration with memcached” 
	
	* 优化innoDB 索引统计信息，详情： Section 14.3.11.1, “Configuring Persistent Optimizer Statistics Parameters”
	
	* 只读事务的优化，提升了ad-hoc 查询以及报表应用的性能。详情： Section 8.5.3, “Optimizing InnoDB Read-Only Transactions” 
	
	* 可以单独将undo log指定在特殊的磁盘上，如（ssd）
	
	* 可以配置innoDB checksum算法innodb_checksum_algorithm=crc32来提升checksum速度。
	* innoDB redo log 大小从 4G 可以指定到 512G 了
	
	*  --innodb-read-only 可以设置只读模式。
	
	* innodb_compression_level 新参数，可以设置压缩表的等级 0-9 ，used by zlib
	* innoDB压缩表数据块中包含了大量的空的space，主要用于DML的时候不需要re-compressing。 这两个参数可以控制：innodb_compression_failure_threshold_pct, innodb_compression_pad_pct_max
	
	* innoDB 现在可以智能的将很久没有使用的表从内存中清除（LRU），以便更多的元数据可以占用内存。可以调高table_definition_cache 参数，可以缓存更多的open状态表的元数据，但这只是soft limit
	
	* innoDB 使用了更新，更快的算法来检测死锁。
	
	* 为了避免instance重启后的长时间预热数据问题，尤其是大内存的实例，mysql 提供了关闭mysql时候dump数据块到文件，然后重启后，可以通过这个文件找到之前热数据page并加载到内存。更多详细信息请关注：Section 14.3.3.5, “Preloading the InnoDB Buffer Pool for Faster Restart” 
	
	* 从mysql5.6.16开始，innochecksum已经支持大于2GB的表，之前版本是不支持2GB以上表的。
	
	* 从mysql5.6.16开始，新的配置参数innodb_status_output ，innodb_status_output_locks 已经可以动态打开和关闭 innoDB Monitor 和 innoDB lock Monitor。之前通过创建特定名字表的方式打开Monitor的方式已经过时，在新版本中将会被废弃。
	
	* 从mysql5.6.17开始，mysql 支持ONLINE DDL(ALGORITHM=INPLACE)的rebuilding 操作。
		
		optimize table 。。。
		
		alter table 。。。 force
		
		alter table 。。。 engine=innoDB
		
* 分区表的增强
 
* performance schema 的增强
 
* MySQL Cluster的增强

* 复制方面的增强
	* GTID 支持，但是还是不能动态开启和关闭
	
	* 基于row模式的复制，已经可以控制image的方式了 binlog_row_image：minimal，full，nonblob。具体看：System Variables Used with Binary Logging
	
	* Binary log 现在支持crash-safe了。
		* binlog_checksum: mysql写入binlog的时候用crc32算法 checksum
		* master_verify_checksum: mysql从binary log读取的时候检测checksums
		* slave-sql-verify-checksum: SQL-thread 读取的时候检测checksums
		
	* 为了让replication支持crash-safe，mysql提供了以下两个参数：
		*  --master-info-repository=table： 将master的connection信息可以记录到slave_master_info表
		*  --relay-log-info-repository=table： 将slave的connection信息记录到slave_relay_log_info表
		* 必须要设置slave_master_info，slave_relay_log_info为innoDB引擎才可以保证事务的原子性。
		* 更多细节关注： Crash-safe replication
		
	* 现在可以使用mysqlbinlog工具直接远程连接mysql，并将binlog从远端backup到mysqlbinlog所在host。更多细节：Section 4.6.8.3, “Using mysqlbinlog to Back Up Binary Log Files”
	
	* mysql现在支持原生的延迟slave，通过设置MASTER_DELAY option for CHANGE MASTER TO
		* 可以避免人为失误操作
		* 可以测试延迟情况下的slave的恢复能力
		* 更多细节： Section 17.3.9, “Delayed Replication”.
		
	* 新增系统变量，可以查看binlog和relay log的位置
		* show global variables like 'log_bin_basename'；
		* show global variables like 'relay_log_basename'；
	
	* 多线程复制，目前只支持基于schema的多线程。

* 优化器方面的增强
	* order by xx limit [M]，N 查询的优化 ， 如果sort_buffer_size足够大，可以避免merge file。 细节： Section 8.2.1.19, “Optimizing LIMIT Queries”.
	
	* Disk-Sweep MRR 特性。简单描述就是：Mysql从secondary index 中range方式读取主键id后，然后会再去从primary-index 中读取数据。这里就会导致primary-index中根据主键的查询是random查询。MRR主要的方案就是：从secondary index中读取到随机主键后，会先进行主键排序，最后再primary-index中查询的时候，就基本上是order 方式查询了。详情： Section 8.2.1.13, “Multi-Range Read Optimization”
	
	* Index Condition PushDown (ICP)特性：主要就是存储引擎层也可以使用where条件过滤了。
	更多细节：Section 8.2.1.6, “Index Condition Pushdown Optimization”.
	
	* explain现在可以支持DML了，并且可以以Jason的方式打印输出
	
	* 子查询优化  Section 8.2.1.18.3, “Optimizing Derived Tables (Subqueries) in the FROM Clause”.
	
	* A Batched Key Access (BKA) 连接算法，提升连接性能。更多细节：Section 8.2.1.14, “Block Nested-Loop and Batched Key Access Joins”
	
	* 可以使用 INFORMATION_SCHEMA.OPTIMIZER_TRACE 来跟踪优化器，主要是针对数据库开发人员。更多细节：MySQL Internals: Tracing the Optimizer.
	
* 数据类型
	* fractional seconds 支持：TIME，DATETIME，TIMESTAMP，支持微秒级别（6位精度）
	
	* mysql5.6之前的版本，一个表最多只能有一个timestamp字段会被自动初始化或者自动更新。
	mysql5.6，以及之后的版本以及放开了这个限制。并且，datetime这个字段也能使用自动初始化了。更多细节：Section 11.3.5, “Automatic Initialization and Updating for TIMESTAMP and DATETIME”.
	
	*  explicit_defaults_for_timestamp 关闭timestamp的默认值。更多细节： Section 11.3.5, “Automatic Initialization and Updating for TIMESTAMP and DATETIME”, and Section 5.1.4, “Server System Variables”.
	
* Host cache
	* 新增 Connection_errors_xxx status 变量
	* host_cache 在performance schema中有相关变量
	* host_cache_size  可以配置大小
	* 更多细节： Section 8.12.6.2, “DNS Lookup Optimization and the Host Cache”, and Section 22.9.10.1, “The host_cache Table”.
	
* OpenGIS
	* 地理位置信息查询的增强，更多细节： Section 12.15.9, “Functions That Test Spatial Relations Between Geometry Objects”.
	
	
		
#### 过时的特性
---

*  ERROR_FOR_DIVISION_BY_ZERO, NO_ZERO_DATE, and NO_ZERO_IN_DATE SQL modes 将被废弃，mysql 5.7 这些参数就会无效。
*  依赖Group by 的隐式排序将被废弃，为了获得排序，必须使用显示的order by
*  mysql_old_password  将被废弃
*   --skip-innodb 被废弃，用（--innodb=OFF, --disable-innodb）代替
*   date_format, datetime_format, and time_format 以及无效
*   have_profiling, profiling, and profiling_history_size 将被废弃
*   innodb_use_sys_malloc and innodb_additional_mem_pool_size 将废弃
*   timed_mutexes 已经无效
*   The IGNORE clause for ALTER TABLE 废弃，会导致online ddl 出错
*   The msql2mysql, mysql_convert_table_format, mysql_find_rows, mysql_fix_extensions, mysql_setpermission, mysql_waitpid, mysql_zap, mysqlaccess, and mysqlbug utilities 废弃
*   mysqlhotcopy utility 废弃

   
#### 被废除的特性
---

* --log 已经移除。 用 --general_log代替
*  --log-slow-queries 已经移除。 用 --slow_query_log_file=file_name 代替
*  --one-thread  已经移除。用 --thread_handling=no-threads 代替
*  --safe-mode 已经移除
*   --skip-thread-priority 已经移除
*   --table-cache 已经移除。 用 --table_opne_cache 代替
*   sql_big_tables 已经移除。 用 big_tables 代替
*   sql_low_priority_updates 已经移除。 用 low_priority_updates代替
*   sql_max_join_size 已经移除。用  max_join_size代替
*   max_long_data_size 已经移除。用  max_allowed_packet 代替
*   FLUSH MASTER and FLUSH SLAVE 已经移除。用  RESET MASTER and RESET SLAVE代替
*   SLAVE START and SLAVE STOP  已经移除。用 START SLAVE and STOP SLAVE代替
*   show engine innoDB mutex 将被移除。 用performance schema 中查询代替
	


