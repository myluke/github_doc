/*
* 所涉及的performance_schema的所有列表
* 1）file_summary_by_instance
* 2) file_summary_by_event_name
* 3) table_io_waits_summary_by_index_usage
* 4) events_statements_summary_by_digest
* 5) events_statements_summary_by_host_by_event_name
* 6) events_statements_summary_global_by_event_name
* 7) events_waits_summary_global_by_event_name
* 8) events_waits_summary_by_host_by_event_name 
* 9) objects_summary_global_by_type
*/

/*
*	Create DATABASE v_monitor
*/
CREATE DATABASE IF NOT EXISTS v_monitor DEFAULT CHARACTER SET utf8;
USE v_monitor;

/*
*	Create function format_time
*/

DROP FUNCTION IF EXISTS format_time;

DELIMITER $$

CREATE DEFINER='readonly'@'%'  FUNCTION format_time (
        picoseconds BIGINT UNSIGNED
    )
    RETURNS VARCHAR(16) CHARSET UTF8
    SQL SECURITY INVOKER
    DETERMINISTIC
    NO SQL
BEGIN
  IF picoseconds IS NULL THEN RETURN NULL;
  ELSEIF picoseconds >= 3600000000000000 THEN RETURN CONCAT(ROUND(picoseconds / 3600000000000000, 2), 'h');
  ELSEIF picoseconds >= 60000000000000 THEN RETURN SEC_TO_TIME(ROUND(picoseconds / 1000000000000, 2));
  ELSEIF picoseconds >= 1000000000000 THEN RETURN CONCAT(ROUND(picoseconds / 1000000000000, 2), ' s');
  ELSEIF picoseconds >= 1000000000 THEN RETURN CONCAT(ROUND(picoseconds / 1000000000, 2), ' ms');
  ELSEIF picoseconds >= 1000000 THEN RETURN CONCAT(ROUND(picoseconds / 1000000, 2), ' us');
  ELSEIF picoseconds >= 1000 THEN RETURN CONCAT(ROUND(picoseconds / 1000, 2), ' ns');
  ELSE RETURN CONCAT(picoseconds, ' ps');
  END IF;
END $$

DELIMITER ;


/*
*	Create function format_statement
*/

DROP FUNCTION IF EXISTS format_statement;

DELIMITER $$

CREATE DEFINER='readonly'@'%'  FUNCTION format_statement (
        statement LONGTEXT
    )
    RETURNS VARCHAR(65)
    SQL SECURITY INVOKER
    DETERMINISTIC
    NO SQL
BEGIN
  IF LENGTH(statement) > 64 THEN 
      RETURN REPLACE(CONCAT(LEFT(statement, 30), ' ... ', RIGHT(statement, 30)), '\n', ' ');
  ELSE 
      RETURN REPLACE(statement, '\n', ' ');
  END IF;
END $$

DELIMITER ;

/*
*	Create function format_bytes
*/


DROP FUNCTION IF EXISTS format_bytes;

DELIMITER $$

CREATE DEFINER='readonly'@'%'  FUNCTION format_bytes (
        bytes BIGINT
    )
    RETURNS VARCHAR(16)
    SQL SECURITY INVOKER
    DETERMINISTIC
    NO SQL
BEGIN
  IF bytes IS NULL THEN RETURN NULL;
  ELSEIF bytes >= 1125899906842624 THEN RETURN CONCAT(ROUND(bytes / 1125899906842624, 2), ' PiB');
  ELSEIF bytes >= 1099511627776 THEN RETURN CONCAT(ROUND(bytes / 1099511627776, 2), ' TiB');
  ELSEIF bytes >= 1073741824 THEN RETURN CONCAT(ROUND(bytes / 1073741824, 2), ' GiB');
  ELSEIF bytes >= 1048576 THEN RETURN CONCAT(ROUND(bytes / 1048576, 2), ' MiB');
  ELSEIF bytes >= 1024 THEN RETURN CONCAT(ROUND(bytes / 1024, 2), ' KiB');
  ELSE RETURN CONCAT(bytes, ' bytes');
  END IF;
END $$

DELIMITER ;


/*
*	Create function format_path
*/

DROP FUNCTION IF EXISTS format_path;

DELIMITER $$

CREATE DEFINER='readonly'@'%'  FUNCTION format_path (
        path VARCHAR(260)
    )
    RETURNS VARCHAR(260) CHARSET UTF8
    SQL SECURITY INVOKER
    DETERMINISTIC
    NO SQL
BEGIN
  DECLARE v_path VARCHAR(260);

  
  IF path LIKE '/private/%' 
    THEN SET v_path = REPLACE(path, '/private', '');
    ELSE SET v_path = path;
  END IF;

  IF v_path IS NULL THEN RETURN NULL;
  ELSEIF v_path LIKE CONCAT(@@global.datadir, '%') ESCAPE '|' THEN 
    RETURN REPLACE(REPLACE(REPLACE(v_path, @@global.datadir, '@@datadir/'), '\\\\', ''), '\\', '/');
  ELSEIF v_path LIKE CONCAT(@@global.tmpdir, '%') ESCAPE '|' THEN 
    RETURN REPLACE(REPLACE(REPLACE(v_path, @@global.tmpdir, '@@tmpdir/'), '\\\\', ''), '\\', '/');
  ELSE RETURN v_path;
  END IF;
END$$

DELIMITER ;



/*
*	IO 相关，文件相关的延迟 ， 事件相关的延迟， FILE IO
*   View: io_global_by_file_by_bytes
* 	使用说明： 统计每个文件的IO使用率, 比如读写次数，读写bytes	
*   能解决什么问题？
*	1）可以清楚的知道那个文件是被访问的最频繁，压力最大，延迟最多的文件。
*	2）可以实时监控redo log，undo，datafile的变化，从而做针对性的优化和调整。当然，通过这个，也能知道瓶颈。
*	3）可以清楚的知道某个库级别，表级别的压力情况，这个比之前count sql数量，观察data size要靠谱，真实的多。
*	4）可以做前瞻性的规划，比如：拆库拆表，可以指导如何按照压力负载均衡的做到合理来优化拆分
*	5）通过表级别的count监控，还可以用做前端缓存的利用率监控。
*       6）可以知道哪些db.table是以只读为主，哪些db.test是以只写为主。从而又进一步做缓存和业务监控。
*readonly:v_monitor> select * from io_global_by_file_by_bytes limit 10;
*+--------------------------------------------------+------------+------------+-------------+---------------+------------+
*| file                                             | count_read | total_read | count_write | total_written | total      |
*+--------------------------------------------------+------------+------------+-------------+---------------+------------+
*| /data/mysql/var/ibdata1                          |          0 | 0 bytes    |    16952506 | 880.15 GiB    | 880.15 GiB |
*| /data/mysql/var/ark_db/hp_pro_stats_hour_11.ibd  |          0 | 0 bytes    |     8782380 | 140.21 GiB    | 140.21 GiB |
*| /data/mysql/var/ark_db/hp_pro_stats_hour_oth.ibd |          0 | 0 bytes    |     5631256 | 89.36 GiB     | 89.36 GiB  |
*| /data/mysql/var/ark_db/hp_pro_stats_day_11.ibd   |          0 | 0 bytes    |     5017652 | 80.69 GiB     | 80.69 GiB  |
*| /data/mysql/var/ark_db/hp_pro_stats_11.ibd       |          0 | 0 bytes    |     3692307 | 60.88 GiB     | 60.88 GiB  |
*| /data/mysql/var/ark_db/hp_pro_stats_day_oth.ibd  |          0 | 0 bytes    |     2999151 | 49.81 GiB     | 49.81 GiB  |
*| /data/mysql/var/ark_db/hp_pro_stats_oth.ibd      |          0 | 0 bytes    |     2103639 | 36.41 GiB     | 36.41 GiB  |
*| /data/mysql/var/ib_logfile0                      |          0 | 0 bytes    |    29454850 | 21.94 GiB     | 21.94 GiB  |
*| /data/mysql/var/ib_logfile1                      |          0 | 0 bytes    |    29102130 | 21.60 GiB     | 21.60 GiB  |
*| /data/mysql/var/ark_db/hp_pro_click_oth.ibd      |          0 | 0 bytes    |      898190 | 14.53 GiB     | 14.53 GiB  |
*+--------------------------------------------------+------------+------------+-------------+---------------+------------+
*10 rows in set (0.00 sec)
*/

CREATE OR REPLACE
  ALGORITHM = MERGE
  DEFINER = 'readonly'@'%' 
  SQL SECURITY INVOKER 
VIEW io_global_by_file_by_bytes (
  file,
  count_read,
  total_read,
  count_write,
  total_written,
  total
) AS
SELECT v_monitor.format_path(file_name) AS file, 
       count_read, 
       v_monitor.format_bytes(sum_number_of_bytes_read) AS total_read,
       count_write, 
       v_monitor.format_bytes(sum_number_of_bytes_write) AS total_written,
       v_monitor.format_bytes(sum_number_of_bytes_read + sum_number_of_bytes_write) AS total
  FROM performance_schema.file_summary_by_instance
 ORDER BY sum_number_of_bytes_read + sum_number_of_bytes_write DESC;

/*
 	* 未经过转换的原始信息
*/

 CREATE OR REPLACE
   ALGORITHM = MERGE
   DEFINER = 'readonly'@'%' 
   SQL SECURITY INVOKER 
 VIEW origin_io_global_by_file_by_bytes (
   file,
   count_read,
   total_read,
   count_write,
   total_written,
   total
 ) AS
 SELECT v_monitor.format_path(file_name) AS file, 
        count_read, 
        sum_number_of_bytes_read AS total_read,
        count_write, 
        sum_number_of_bytes_write AS total_written,
        sum_number_of_bytes_read + sum_number_of_bytes_write AS total
   FROM performance_schema.file_summary_by_instance
  ORDER BY sum_number_of_bytes_read + sum_number_of_bytes_write DESC;



/*
*	IO 相关，文件相关的延迟 ， 事件相关的延迟 FILE IO
*   View: io_global_by_file_by_latency
* 	使用说明： 统计每个文件的latency  	
*   能解决什么问题？
*   1）能解决的问题和io_global_by_file_by_bytes一样，只不过角度不一样。这里是以延迟来衡量
*readonly:v_monitor> select * from io_global_by_file_by_latency limit 10;
*+--------------------------------------------------+----------+---------------+------------+--------------+-------------+---------------+
*| file                                             | total    | total_latency | count_read | read_latency | count_write | write_latency |
*+--------------------------------------------------+----------+---------------+------------+--------------+-------------+---------------+
*| /data/mysql/var/ib_logfile0                      | 59328704 | 1.40h         |          0 | 0 ps         |    29670415 | 00:03:05.51   |
*| /data/mysql/var/ib_logfile1                      | 58204245 | 1.38h         |          0 | 0 ps         |    29102130 | 00:03:01.40   |
*| /data/mysql/var/ibdata1                          | 18492358 | 00:54:07.96   |          0 | 0 ps         |    17039981 | 00:06:49.20   |
*| /data/mysql/var/ark_db/hp_pro_stats_hour_11.ibd  |  9369453 | 00:08:23.82   |          0 | 0 ps         |     8832634 | 00:01:19.78   |
*| /data/mysql/var/ark_db/hp_pro_stats_day_11.ibd   |  5548183 | 00:05:52.43   |          0 | 0 ps         |     5052084 | 45.78 s       |
*| /data/mysql/var/ark_db/hp_pro_stats_hour_oth.ibd |  6172184 | 00:05:46.43   |          0 | 0 ps         |     5667656 | 54.00 s       |
*| /data/mysql/var/ark_db/hp_pro_stats_11.ibd       |  4126313 | 00:04:59.54   |          0 | 0 ps         |     3717949 | 32.73 s       |
*| /data/mysql/var/ark_db/hp_pro_stats_oth.ibd      |  2376313 | 00:04:14.98   |          0 | 0 ps         |     2116758 | 17.49 s       |
*| /data/mysql/var/ark_db/hp_pro_stats_day_oth.ibd  |  3412908 | 00:03:58.03   |          0 | 0 ps         |     3018950 | 26.98 s       |
*| /data/mysql/var/ark_db/hp_pro_click_oth.ibd      |  1101398 | 00:01:12.65   |          0 | 0 ps         |      902427 | 9.63 s        |
*+--------------------------------------------------+----------+---------------+------------+--------------+-------------+---------------+
*10 rows in set (0.01 sec)

*/

CREATE OR REPLACE
  ALGORITHM = MERGE
  DEFINER = 'readonly'@'%' 
  SQL SECURITY INVOKER 
VIEW io_global_by_file_by_latency (
  file,
  total,
  total_latency,
  count_read,
  read_latency,
  count_write,
  write_latency
) AS
SELECT v_monitor.format_path(file_name) AS file, 
       count_star AS total, 
       v_monitor.format_time(sum_timer_wait) AS total_latency,
       count_read,
       v_monitor.format_time(sum_timer_read) AS read_latency,
       count_write,
       v_monitor.format_time(sum_timer_write) AS write_latency
  FROM performance_schema.file_summary_by_instance
 ORDER BY sum_timer_wait DESC;
 
 
 
 
/*
*	IO 相关，classes相关的延迟 ， 事件相关的延迟  Event IO
*   View: io_global_by_wait_by_bytes
* 	使用说明： 统计每个事件的IO使用率，单位bytes，counts。 Top Waits By bytes
*	能解决什么问题？
*	1）专注的不再只是文件一个点，包括服务器层和引擎层。
*	2）如果relaylog非常大，说明同步有问题。
*	3）如果binlog比较大，说明binlog有问题。
*	4）如果sql/FRM 比较大，Tune table_open_cache / table_definition_cache
*	5）如果sql/file_parse比较大，如果在5.5比较高，那就升级mysql到5.6
*	6）如果query_log比较大，那就disable genery log
*	7）如果slow log比较大，那就调整slow阈值。
*   8）还有很多值得挖掘~~
*readonly:v_monitor> select * from io_global_by_wait_by_bytes limit 10;
*+-------------------------+------------+---------------+------------+------------+-------------+---------------+-----------------+
*| event_name              | total      | total_latency | count_read | total_read | count_write | total_written | total_requested |
*+-------------------------+------------+---------------+------------+------------+-------------+---------------+-----------------+
*| innodb/innodb_data_file |  116249025 | 3.14h         |    1179948 | 25.17 GiB  |   100838192 | 2.35 TiB      | 2.37 TiB        |
*| sql/relaylog            | 4401630943 | 4.67h         |  640398925 | 403.44 GiB |  3120571330 | 403.44 GiB    | 806.88 GiB      |
*| innodb/innodb_log_file  |  117730283 | 2.78h         |          0 | 0 bytes    |    58871213 | 43.77 GiB     | 43.77 GiB       |
*| myisam/dfile            |    5077011 | 5.72 s        |    3376135 | 841.29 MiB |       13950 | 1.61 GiB      | 2.43 GiB        |
*| sql/FRM                 |     565451 | 14.43 s       |     231981 | 44.23 MiB  |      111230 | 11.97 MiB     | 56.21 MiB       |
*| sql/binlog_index        |      38898 | 1.89 s        |       5978 | 203.68 KiB |           0 | 0 bytes       | 203.68 KiB      |
*| sql/file_parser         |       1273 | 26.81 ms      |         50 | 83.65 KiB  |          33 | 105.21 KiB    | 188.86 KiB      |
*| myisam/kfile            |       4910 | 65.62 ms      |        342 | 70.79 KiB  |        3421 | 70.17 KiB     | 140.96 KiB      |
*| sql/binlog              |         78 | 111.03 ms     |          7 | 24.23 KiB  |          56 | 34.59 KiB     | 58.82 KiB       |
*| sql/slow_log            |          2 | 10.13 ms      |          0 | 0 bytes    |           2 | 476 bytes     | 476 bytes       |
*+-------------------------+------------+---------------+------------+------------+-------------+---------------+-----------------+
*10 rows in set (0.06 sec)
*/

CREATE OR REPLACE
  ALGORITHM = MERGE
  DEFINER = 'readonly'@'%' 
  SQL SECURITY INVOKER 
VIEW io_global_by_wait_by_bytes (
  event_name,
  total,
  total_latency,
  count_read,
  total_read,
  count_write,
  total_written,
  total_requested
) AS
SELECT SUBSTRING_INDEX(event_name, '/', -2) event_name,
       count_star AS total,
       v_monitor.format_time(sum_timer_wait) AS total_latency,
       count_read,
       v_monitor.format_bytes(sum_number_of_bytes_read) AS total_read,
       count_write,
       v_monitor.format_bytes(sum_number_of_bytes_write) AS total_written,
       v_monitor.format_bytes(sum_number_of_bytes_write + sum_number_of_bytes_read) AS total_requested
  FROM performance_schema.file_summary_by_event_name
 WHERE event_name LIKE 'wait/io/file/%' 
   AND count_star > 0
 ORDER BY sum_number_of_bytes_write + sum_number_of_bytes_read DESC;
 
 
 
 
 
/*
*	IO 相关，classes相关的延迟 ， 事件相关的延迟  Event IO
*   View: io_global_by_wait_by_latency
* 	使用说明： 统计每个事件的IO latency	
*	能解决什么问题？
*	1）和io_global_by_wait_by_bytes一样，只是维度不同。  -- 延迟的维度
*readonly:v_monitor> select * from io_global_by_wait_by_latency limit 10;
*+-------------------------+------------+---------------+--------------+---------------+------------+------------+-------------+---------------+
*| event_name              | total      | total_latency | read_latency | write_latency | count_read | total_read | count_write | total_written |
*+-------------------------+------------+---------------+--------------+---------------+------------+------------+-------------+---------------+
*| sql/relaylog            | 4402876075 | 4.67h         | 00:34:17.72  | 3.56h         |  640580183 | 403.56 GiB |  3121453858 | 403.55 GiB    |
*| innodb/innodb_data_file |  116267316 | 3.14h         | 00:18:01.37  | 00:22:40.06   |    1179948 | 25.17 GiB  |   100854878 | 2.35 TiB      |
*| innodb/innodb_log_file  |  118276625 | 2.79h         | 0 ps         | 00:06:09.20   |          0 | 0 bytes    |    59144386 | 43.97 GiB     |
*| sql/FRM                 |     565457 | 14.43 s       | 11.19 s      | 186.53 ms     |     231983 | 44.23 MiB  |      111230 | 11.97 MiB     |
*| myisam/dfile            |    5077011 | 5.72 s        | 2.47 s       | 2.32 s        |    3376135 | 841.29 MiB |       13950 | 1.61 GiB      |
*| sql/binlog_index        |      38898 | 1.89 s        | 19.19 ms     | 0 ps          |       5978 | 203.68 KiB |           0 | 0 bytes       |
*| sql/binlog              |         78 | 111.03 ms     | 20.85 us     | 671.02 us     |          7 | 24.23 KiB  |          56 | 34.59 KiB     |
*| myisam/kfile            |       4910 | 65.62 ms      | 572.33 us    | 39.10 ms      |        342 | 70.79 KiB  |        3421 | 70.17 KiB     |
*| archive/data            |       6931 | 30.00 ms      | 0 ps         | 0 ps          |          0 | 0 bytes    |           0 | 0 bytes       |
*| sql/file_parser         |       1274 | 26.81 ms      | 189.70 us    | 597.35 us     |         50 | 83.65 KiB  |          33 | 105.21 KiB    |
*+-------------------------+------------+---------------+--------------+---------------+------------+------------+-------------+---------------+
*10 rows in set (0.06 sec) 
*/

CREATE OR REPLACE
  ALGORITHM = MERGE
  DEFINER = 'readonly'@'%' 
  SQL SECURITY INVOKER 
VIEW io_global_by_wait_by_latency (
  event_name,
  total,
  total_latency,
  read_latency,
  write_latency,
  count_read,
  total_read,
  count_write,
  total_written
) AS
SELECT SUBSTRING_INDEX(event_name, '/', -2) AS event_name,
       count_star AS total,
       v_monitor.format_time(sum_timer_wait) AS total_latency,
       v_monitor.format_time(sum_timer_read) AS read_latency,
       v_monitor.format_time(sum_timer_write) AS write_latency,
       count_read,
       v_monitor.format_bytes(sum_number_of_bytes_read) AS total_read,
       count_write,
       v_monitor.format_bytes(sum_number_of_bytes_write) AS total_written
  FROM performance_schema.file_summary_by_event_name 
 WHERE event_name LIKE 'wait/io/file/%'
   AND count_star > 0
 ORDER BY sum_timer_wait DESC;
 
 
 /*
 *	Table IO 相关
 *	View:io_global_by_table_by_latency
 *	使用说明：Top Tables By Latency
 *  能解决什么问题：
 *	1） 从table的角度来衡量DB的压力。
 *  2） 和io_global_by_file_by_latency类似，io_global_by_file_by_latency 考虑的是文件，是物理IO。而io_global_by_table_by_latency更多的是上层的压力分布。
 *	3） 除了能解决io_global_by_file_by_latency的问题外，还可以发现并发的问题。
 *		比如：如果这里table的total很低，但是total_latency 很高，这就能很好的说明，80%是由于这个file的并发访问造成的high latency
 *	4)  它还能做一件非常niubility的事情，那就是查看哪些表已经不被使用，已经下线了。其实很多开发也会问哪些表不被使用了，这下就可以派上用场了。好处：a）优化业务 b）减少磁盘空间。 c）减少备份的压力。
*readonly:v_monitor> select * from io_global_by_table_by_latency limit 10;
*+-----------------+--------------------------------+----------+---------------+-------------+-------------+
*| table_schema    | table_name                     | total    | total_latency | avg_latency | max_latency |
*+-----------------+--------------------------------+----------+---------------+-------------+-------------+
*| anjuke_db       | ajk_propertysale               | 17053410 | 1.11h         | 233.37 us   | 1.40 s      |
*| anjuke_db       | ajk_members                    | 65246324 | 00:33:58.47   | 31.24 us    | 323.66 ms   |
*| anjuke_db       | ajk_brokerextend               | 51277324 | 00:23:31.12   | 27.52 us    | 423.48 ms   |
*| stats_db        | list_acenter_consume_c         | 73892219 | 00:13:44.54   | 11.16 us    | 414.73 ms   |
*| anjuke_db       | log_broker_login_201406        | 25700871 | 00:13:00.67   | 30.38 us    | 514.11 ms   |
*| propertys_sh_db | ajk_propertys                  | 14348854 | 00:12:51.18   | 53.75 us    | 758.49 ms   |
*| stats_db        | list_acenter_charge_c          | 33333810 | 00:11:59.95   | 21.60 us    | 321.49 ms   |
*| anjuke_db       | ajk_private_tag                |  9723376 | 00:10:56.38   | 67.51 us    | 428.58 ms   |
*| anjuke_db       | account_balance_log_sublist_06 | 24463818 | 00:10:38.03   | 26.08 us    | 427.08 ms   |
*| anjuke_db       | ajk_property_data              | 23114971 | 00:09:31.39   | 24.72 us    | 305.56 ms   |
*+-----------------+--------------------------------+----------+---------------+-------------+-------------+
*10 rows in set (0.01 sec)
 */
 
 CREATE OR REPLACE
   ALGORITHM = MERGE
   DEFINER = 'readonly'@'%' 
   SQL SECURITY INVOKER 
 VIEW io_global_by_table_by_latency (
   table_schema,
   table_name,
   total,
   total_latency,
   avg_latency,
   max_latency
 ) AS 
 SELECT object_schema AS table_schema,
             object_name AS table_name,
             count_star AS total,
             v_monitor.format_time(sum_timer_wait) as total_latency,
             v_monitor.format_time(sum_timer_wait / count_star) as avg_latency,
             v_monitor.format_time(max_timer_wait) as max_latency
  FROM performance_schema.objects_summary_global_by_type
       ORDER BY sum_timer_wait DESC;
 
/*
*	Table IO 相关	
*	View:io_global_by_table_detail_breakdown
*	使用说明： Table Usage Detailed Breakdown	  
*	可以解决的问题：
*	1） 可以精确到表级别的IOPS，TPS。为诊断问题性能问题提供可靠的粒度。
*	2） 可以指导通过数据来了解业务并且指导业务开发，为什么IUD很高，为什么S很高。
*	3） 有些表如果只有IDU，或者甚至只有I，那么这些表根本就不适合放入在线DB，so，可以提供在线DB的架构优化。	   
*readonly:v_monitor> select * from io_global_by_table_detail_breakdown limit 10;
*+-----------------+--------------------------------+----------+----------------+---------+----------------+----------+----------------+---------+----------------+
*| table_schema    | table_name                     | selects  | select_latency | inserts | insert_latency | updates  | update_latency | deletes | delete_latency |
*+-----------------+--------------------------------+----------+----------------+---------+----------------+----------+----------------+---------+----------------+
*| anjuke_db       | ajk_propertysale               |  6532225 | 00:56:34.78    | 1105708 | 00:03:03.19    |  1944954 | 00:06:20.39    | 1322582 | 17.20 s        |
*| anjuke_db       | ajk_members                    | 16270425 | 00:11:49.35    |   60983 | 00:01:36.68    | 16267120 | 00:20:05.95    |      59 | 17.76 ms       |
*| anjuke_db       | ajk_brokerextend               | 15377867 | 00:11:36.55    |    4083 | 3.56 s         |  5142498 | 00:11:26.88    |       0 | 0 ps           |
*| stats_db        | list_acenter_consume_c         | 16288296 | 00:03:28.84    | 8260912 | 00:06:12.97    |  8260912 | 00:02:30.94    | 7997084 | 00:01:08.67    |
*| anjuke_db       | log_broker_login_201406        |        0 | 0 ps           | 8568979 | 00:12:47.28    |        0 | 0 ps           |       0 | 0 ps           |
*| propertys_sh_db | ajk_propertys                  |  3963117 | 00:04:44.38    |  366787 | 00:01:46.98    |  2521943 | 00:05:33.12    |  397469 | 41.13 s        |
*| stats_db        | list_acenter_charge_c          |  8292546 | 00:03:34.09    |   56871 | 7.38 s         |  8292546 | 00:08:06.29    |       0 | 0 ps           |
*| anjuke_db       | ajk_private_tag                |  3811793 | 00:09:27.39    |  158063 | 43.71 s        |  3811793 | 44.06 s        |       0 | 0 ps           |
*| anjuke_db       | account_balance_log_sublist_06 |        0 | 0 ps           | 8156298 | 00:10:25.48    |        0 | 0 ps           |       0 | 0 ps           |
*| anjuke_db       | ajk_property_data              |  5598966 | 00:04:29.53    | 1104535 | 00:01:31.36    |  4277478 | 00:02:50.94    | 1321179 | 31.39 s        |
*+-----------------+--------------------------------+----------+----------------+---------+----------------+----------+----------------+---------+----------------+
*10 rows in set (0.01 sec)    
*/ 

CREATE OR REPLACE
	 ALGORITHM = MERGE
	 DEFINER = 'readonly'@'%' 
	 SQL SECURITY INVOKER 
VIEW io_global_by_table_detail_breakdown (
	 table_schema,
	 table_name,
	 selects,
	 select_latency,
	 inserts,
	 insert_latency,
	 updates,
	 update_latency,
	 deletes,
	 delete_latency
	   ) AS 
SELECT object_schema AS table_schema, 
			object_name AS table_name,
	   		count_fetch AS selects, 
			v_monitor.format_time(sum_timer_fetch) AS select_latency,
	   	 	count_insert AS inserts,
			v_monitor.format_time(sum_timer_insert) AS insert_latency,
	   	 	count_update AS updates, 
			v_monitor.format_time(sum_timer_update) AS update_latency,
	   	 	count_delete AS deletes, 
			v_monitor.format_time(sum_timer_delete) AS delete_latency	   
	 FROM performance_schema.table_io_waits_summary_by_table 
	  	ORDER BY sum_timer_wait DESC ;
 
 
 
 
 
 
/*
*	性能调优相关： 全表扫描的schema
*   View: schema_tables_with_full_table_scans
* 	使用说明： 找到全表扫描的表，以扫描的行数降序排列  	
*	能解决什么问题：
*	1）能找到哪些表被全表扫描的多，从而针对性的对这张表优化。
*	2）优化内存使用率。将full_scann减少，更加能够提高内存利用率。能够让更多合理的数据进入内存，从而进一步的减少了slow
*readonly:v_monitor> select * from schema_tables_with_full_table_scans limit 10;
*+---------------+-----------------------------+-------------------+
*| object_schema | object_name                 | rows_full_scanned |
*+---------------+-----------------------------+-------------------+
*| ark_db        | hp_pro_stats_hour_11        |           6961159 |
*| ark_db        | hp_pro_stats_hour_oth       |           5957428 |
*| ark_db        | log_rankprop_update_auction |           3047492 |
*| ark_db        | hp_broker_stats_hour_oth    |            979462 |
*| ark_db        | ajk_propspread              |            935123 |
*| ark_db        | hp_broker_stats_hour_11     |            815424 |
*| ark_db        | hp_comm_stats_hour_oth      |            744698 |
*| ark_db        | hp_comm_stats_hour_11       |            574816 |
*| ark_db        | hp_pro_stats_day_11         |            483393 |
*| ark_db        | hp_pro_stats_day_oth        |            404916 |
*+---------------+-----------------------------+-------------------+
*10 rows in set (0.04 sec)
*/

CREATE OR REPLACE
  ALGORITHM = MERGE
  DEFINER = 'readonly'@'%' 
  SQL SECURITY INVOKER 
VIEW schema_tables_with_full_table_scans (
  object_schema,
  object_name,
  rows_full_scanned
) AS
SELECT object_schema, 
       object_name,
       count_read AS rows_full_scanned
  FROM performance_schema.table_io_waits_summary_by_index_usage 
 WHERE index_name IS NULL
   AND count_read > 0
 ORDER BY count_read DESC;
 
 
 
 /*
 *	性能调优相关： 找出未使用过的index和schema
 *   View: schema_unused_indexes
 * 	 能解决什么问题：
 *	1）找出哪些表的使用有问题。
 *	2）找出哪些索引是从来没有被用过，进而指导DBA&&开发优化没有使用的索引，可以提高写的性能。
 
*readonly:v_monitor> select * from schema_unused_indexes limit 10;
*+---------------+----------------------+--------------------+
*| object_schema | object_name          | index_name         |
*+---------------+----------------------+--------------------+
*| ark_db        | ajk_propspread       | idx_areacode_price |
*| ark_db        | ajk_propspread       | serialnumber       |
*| ark_db        | ajk_propspread       | city_status_type   |
*| ark_db        | ajk_propspread       | updated_datetime   |
*| ark_db        | ajk_propspread       | idx_commId_price   |
*| ark_db        | ajk_propspread       | broker_id          |
*| ark_db        | ajk_propspread       | createtime         |
*| ark_db        | ajk_propspread_queue | stoptime           |
*| ark_db        | ajk_propspread_redo  | plan_id            |
*| ark_db        | ajk_propspread_redo  | createtime         |
*+---------------+----------------------+--------------------+
*10 rows in set (0.05 sec)
 */
 
 CREATE OR REPLACE
   ALGORITHM = MERGE
   DEFINER = 'readonly'@'%' 
   SQL SECURITY INVOKER 
 VIEW schema_unused_indexes (
   object_schema,
   object_name,
   index_name
 ) AS
 SELECT object_schema,
        object_name,
        index_name
   FROM performance_schema.table_io_waits_summary_by_index_usage 
  WHERE index_name IS NOT NULL
    AND count_star = 0
    AND object_schema not in  ('mysql','v_monitor')
	AND index_name <> 'PRIMARY'
  ORDER BY object_schema, object_name;




 /*
  *	语句statment相关
  *   View: statement_analysis
  * 		列出top N 个SQL的详细情况，以latency降序排列 。  兼容Mysql Enterprise Monitor
  *   能解决什么问题：
  *   1）这个能解决的问题就太多了，为什么？ 因为这个就是Mysql Enterprise Monitor中的一个重要功能。
  *   2）exec
  *   3）err && warnings
  *   4）latency
  *   5）lock latency
  *   6）rows sent  && rows examed
  *   7）tmp table ** tmp disk table 
  *   8）rows sort
  *   9）sort merge
*readonly:v_monitor> select * from statement_analysis \G
*************************** 1. row ***************************
*            query: INSERT INTO `hp_pro_stats_hour ... PDATE `disnum` = `disnum` + ?
*               db: ark_db
*        full_scan:
*       exec_count: 97704732
*        err_count: 0
*       warn_count: 0
*    total_latency: 3.34h
*      max_latency: 2.90 s
*      avg_latency: 123.00 us
*     lock_latency: 1.57h
*        rows_sent: 0
*    rows_sent_avg: 0
*    rows_examined: 0
*rows_examined_avg: 0
*       tmp_tables: 0
*  tmp_disk_tables: 0
*      rows_sorted: 0
*sort_merge_passes: 0
*           digest: 4878125158ccfb0239731d889bce8221
*       first_seen: 2014-05-20 10:27:36
*        last_seen: 2014-06-18 16:31:01
 */

 CREATE OR REPLACE
   ALGORITHM = MERGE
   DEFINER = 'readonly'@'%'
   SQL SECURITY INVOKER 
 VIEW statement_analysis (
   query,
   db,
   full_scan,
   exec_count,
   err_count,
   warn_count,
   total_latency,
   max_latency,
   avg_latency,
   lock_latency,
   rows_sent,
   rows_sent_avg,
   rows_examined,
   rows_examined_avg,
   tmp_tables,
   tmp_disk_tables,
   rows_sorted,
   sort_merge_passes,
   digest,
   first_seen,
   last_seen
 ) AS
 SELECT v_monitor.format_statement(DIGEST_TEXT) AS query,
        SCHEMA_NAME AS db,
        IF(SUM_NO_GOOD_INDEX_USED > 0 OR SUM_NO_INDEX_USED > 0, '*', '') AS full_scan,
        COUNT_STAR AS exec_count,
        SUM_ERRORS AS err_count,
        SUM_WARNINGS AS warn_count,
        v_monitor.format_time(SUM_TIMER_WAIT) AS total_latency,
        v_monitor.format_time(MAX_TIMER_WAIT) AS max_latency,
        v_monitor.format_time(AVG_TIMER_WAIT) AS avg_latency,
        v_monitor.format_time(SUM_LOCK_TIME) AS lock_latency,
        SUM_ROWS_SENT AS rows_sent,
        ROUND(IFNULL(SUM_ROWS_SENT / NULLIF(COUNT_STAR, 0), 0)) AS rows_sent_avg,
        SUM_ROWS_EXAMINED AS rows_examined,
        ROUND(IFNULL(SUM_ROWS_EXAMINED / NULLIF(COUNT_STAR, 0), 0))  AS rows_examined_avg,
        SUM_CREATED_TMP_TABLES AS tmp_tables,
        SUM_CREATED_TMP_DISK_TABLES AS tmp_disk_tables,
        SUM_SORT_ROWS AS rows_sorted,
        SUM_SORT_MERGE_PASSES AS sort_merge_passes,
        DIGEST AS digest,
        FIRST_SEEN AS first_seen,
        LAST_SEEN as last_seen
   FROM performance_schema.events_statements_summary_by_digest
 ORDER BY SUM_TIMER_WAIT DESC;



 /*
 *	语句statment相关
 *   View: statements_with_errors_or_warnings
 * 	使用说明： 统计有error或者warnings的top N SQL
 *  能解决的问题：
 *  1) 找出有error 或者 warning 的 SQL
 *  2）有warnin的语句，迟早都会变成error，而且还是隐形的error。-- tom kyte oracle 资深DBA
 *  3）找出频繁warning或者error的SQL，有助于预防SQL注入或者更高级别的SQL攻击。
 
*************************** 5. row ***************************
*     query: SELECT * FROM `events_waits_su ... `sum_timer_wait` DESC LIMIT ?
*        db: sys
*exec_count: 3
*    errors: 3
*  warnings: 0
*first_seen: 2014-06-16 16:41:02
* last_seen: 2014-06-16 17:07:39
*    digest: 3e9e2ddc267ff4ef679a5a49855176ea
 */
 
 CREATE OR REPLACE
   ALGORITHM = MERGE
   DEFINER = 'readonly'@'%' 
   SQL SECURITY INVOKER 
 VIEW statements_with_errors_or_warnings (
   query,
   db,
   exec_count,
   errors,
   warnings,
   first_seen,
   last_seen,
   digest
 ) AS
 SELECT v_monitor.format_statement(DIGEST_TEXT) AS query,
        SCHEMA_NAME as db,
        COUNT_STAR AS exec_count,
        SUM_ERRORS AS errors,
        SUM_WARNINGS AS warnings,
        FIRST_SEEN as first_seen,
        LAST_SEEN as last_seen,
        DIGEST AS digest
   FROM performance_schema.events_statements_summary_by_digest
  WHERE SCHEMA_NAME not in ('mysql','v_monitor') and (SUM_ERRORS > 0 OR SUM_WARNINGS > 0)
 ORDER BY SUM_ERRORS DESC, SUM_WARNINGS DESC;
 
 
 /*
 *	语句statment相关
 *   View: statements_with_full_table_scans
 * 		统计哪些SQL是全表扫描，按照扫描latency排序  
 *   能解决什么问题：
 *   1）前面有个view可以找出被全表扫描的表的行数，这个可以找出具体的SQL。
 *   2）同样，这种SQL会浪费内存，IO，cpu，应该立刻，马上制止 （Three star system 理论）
 
*************************** 2. row ***************************
*                   query: SELECT SQL_NO_CACHE * FROM `ark_db` . `hp_pro_click_fees_oth`
*                      db: NULL
*              exec_count: 5
*           total_latency: 00:06:08.67
*     no_index_used_count: 5
*no_good_index_used_count: 0
*       no_index_used_pct: 100
*               rows_sent: 36203370
*           rows_examined: 36203370
*           rows_sent_avg: 7240674
*       rows_examined_avg: 7240674
*              first_seen: 2014-05-23 13:02:58
*               last_seen: 2014-05-23 14:35:18
*                  digest: 8042a32250334bff7b5f17eff13ac205
 
 */
 
 CREATE OR REPLACE
   ALGORITHM = MERGE
   DEFINER = 'readonly'@'%' 
   SQL SECURITY INVOKER 
 VIEW statements_with_full_table_scans (
   query,
   db,
   exec_count,
   total_latency,
   no_index_used_count,
   no_good_index_used_count,
   no_index_used_pct,
   rows_sent,
   rows_examined,
   rows_sent_avg,
   rows_examined_avg,
   first_seen,
   last_seen,
   digest
 ) AS
 SELECT v_monitor.format_statement(DIGEST_TEXT) AS query,
        SCHEMA_NAME as db,
        COUNT_STAR AS exec_count,
        v_monitor.format_time(SUM_TIMER_WAIT) AS total_latency,
        SUM_NO_INDEX_USED AS no_index_used_count,
        SUM_NO_GOOD_INDEX_USED AS no_good_index_used_count,
        ROUND(IFNULL(SUM_NO_INDEX_USED / NULLIF(COUNT_STAR, 0), 0) * 100) AS no_index_used_pct,
        SUM_ROWS_SENT AS rows_sent,
        SUM_ROWS_EXAMINED AS rows_examined,
        ROUND(SUM_ROWS_SENT/COUNT_STAR) AS rows_sent_avg,
        ROUND(SUM_ROWS_EXAMINED/COUNT_STAR) AS rows_examined_avg,
        FIRST_SEEN as first_seen,
        LAST_SEEN as last_seen,
        DIGEST AS digest
   FROM performance_schema.events_statements_summary_by_digest
  WHERE SCHEMA_NAME not in ('mysql','v_monitor') and (SUM_NO_INDEX_USED > 0 OR SUM_NO_GOOD_INDEX_USED > 0)
  ORDER BY no_index_used_pct DESC, SUM_TIMER_WAIT DESC;
  
  
 
 /*
 *	语句statment相关
 *   View: statements_with_sorting
 *		统计需要排序的top N SQL
 *	 能解决什么问题：
 *	 1） 找出排序延迟对多的SQL
 *	 2） 这种SQL，会非常好内存和cpu ，应该避免。 （Three star system 理论）
*************************** 1. row ***************************
*            query: SELECT * FROM `innodb_buffer_s ... _SIZE` = ? ) , ? , `ibp` . ...
*               db: ark_db
*       exec_count: 1
*    total_latency: 00:04:58.40
*sort_merge_passes: 0
*sorts_using_scans: 2
* sort_using_range: 0
*      rows_sorted: 1685768
*       first_seen: 2014-06-03 15:18:20
*        last_seen: 2014-06-03 15:18:20
*           digest: 8819ae6337417a82fa5ada32dd5b8de2
 */
 
 CREATE OR REPLACE
   ALGORITHM = MERGE
   DEFINER = 'readonly'@'%' 
   SQL SECURITY INVOKER 
 VIEW statements_with_sorting (
   query,
   db,
   exec_count,
   total_latency,
   sort_merge_passes,
   sorts_using_scans,
   sort_using_range,
   rows_sorted,
   first_seen,
   last_seen,
   digest
 ) AS
 SELECT v_monitor.format_statement(DIGEST_TEXT) AS query,
        SCHEMA_NAME db,
        COUNT_STAR AS exec_count,
        v_monitor.format_time(SUM_TIMER_WAIT) AS total_latency,
        SUM_SORT_MERGE_PASSES AS sort_merge_passes,
        SUM_SORT_SCAN AS sorts_using_scans,
        SUM_SORT_RANGE AS sort_using_range,
        SUM_SORT_ROWS AS rows_sorted,
        FIRST_SEEN as first_seen,
        LAST_SEEN as last_seen,
        DIGEST AS digest
   FROM performance_schema.events_statements_summary_by_digest
  WHERE SUM_SORT_ROWS > 0 and SCHEMA_NAME not in ('mysql','v_monitor')
  ORDER BY SUM_TIMER_WAIT DESC;
 
 /*
 *	语句statment相关
 *   View: statements_with_temp_tables
 * 		统计需要临时表（磁盘，内存）TOP N  SQL
 *   能解决什么问题：
 *	 1） 找出使用临时表最多的SQL
 *   2） 临时表，我想不用多少，可以让性能跌倒谷底（特别是disk 临时表） ，应该避免 （Three star system 理论）
*************************** 1. row ***************************
*                   query: SELECT * FROM `schema_object_o ... MA` , `information_schema` ...
*                      db: sys
*              exec_count: 3
*           total_latency: 8.91 s
*       memory_tmp_tables: 567
*         disk_tmp_tables: 99
*avg_tmp_tables_per_query: 189
*  tmp_tables_to_disk_pct: 17
*              first_seen: 2014-06-03 15:40:44
*               last_seen: 2014-06-04 15:42:36
*                  digest: ccc857fb69a9f151a1b8cb8687697b1a
 */

CREATE OR REPLACE
  ALGORITHM = MERGE
  DEFINER = 'readonly'@'%' 
  SQL SECURITY INVOKER 
VIEW statements_with_temp_tables (
  query,
  db,
  exec_count,
  total_latency,
  memory_tmp_tables,
  disk_tmp_tables,
  avg_tmp_tables_per_query,
  tmp_tables_to_disk_pct,
  first_seen,
  last_seen,
  digest
) AS
SELECT v_monitor.format_statement(DIGEST_TEXT) AS query,
       SCHEMA_NAME as db,
       COUNT_STAR AS exec_count,
       v_monitor.format_time(SUM_TIMER_WAIT) as total_latency,
       SUM_CREATED_TMP_TABLES AS memory_tmp_tables,
       SUM_CREATED_TMP_DISK_TABLES AS disk_tmp_tables,
       ROUND(IFNULL(SUM_CREATED_TMP_TABLES / NULLIF(COUNT_STAR, 0), 0)) AS avg_tmp_tables_per_query,
       ROUND(IFNULL(SUM_CREATED_TMP_DISK_TABLES / NULLIF(SUM_CREATED_TMP_TABLES, 0), 0) * 100) AS tmp_tables_to_disk_pct,
       FIRST_SEEN as first_seen,
       LAST_SEEN as last_seen,
       DIGEST AS digest
  FROM performance_schema.events_statements_summary_by_digest
 WHERE SUM_CREATED_TMP_TABLES > 0 and SCHEMA_NAME not in ('mysql','v_monitor')
ORDER BY SUM_CREATED_TMP_DISK_TABLES DESC, SUM_CREATED_TMP_TABLES DESC;


 /*
 *	 host相关的统计
 *   View: host_summary_by_statement_type
 *   统计每个statment'type 的latency，count，by each host
 *   能解决什么问题：
 *	 1）首先，这个是按照host来分类的。我们的需求，很多都是针对业务IP来的，比如：二手房，API，DFS，JOB。
 *	 2）可以清楚的知道来自那个IP，哪类业务的statment的情况，从而可以很轻松的从业务角度来衡量使用好坏。我想，这应该是代价最低，最精确的做法。
 
*readonly:v_monitor> select * from host_summary_by_statement_type limit 10;
*+------------+-------------------+-------+---------------+-------------+--------------+------------+---------------+---------------+------------+
*| host       | statement         | total | total_latency | max_latency | lock_latency | rows_sent  | rows_examined | rows_affected | full_scans |
*+------------+-------------------+-------+---------------+-------------+--------------+------------+---------------+---------------+------------+
*| localhost | select            |  7890 | 00:59:57.61   | 00:02:41.89 | 4.97 s       | 1215285385 |    1215285385 |             0 |       7820 |
*| localhost | show_table_status |    34 | 7.33 s        | 3.46 s      | 4.18 ms      |      14191 |         14191 |             0 |         34 |
*| localhost | show_create_table |  7890 | 3.98 s        | 14.00 ms    | 0 ps         |          0 |             0 |             0 |          0 |
*| localhost | flush             |    13 | 103.95 ms     | 17.02 ms    | 0 ps         |          0 |             0 |             0 |          0 |
*| localhost | Binlog Dump       |     9 | 70.03 ms      | 25.89 ms    | 0 ps         |          0 |             0 |             0 |          0 |
*| localhost | set_option        |   351 | 16.92 ms      | 267.39 us   | 0 ps         |          0 |             0 |             0 |          0 |
*| localhost | show_binlogs      |     1 | 15.62 ms      | 15.62 ms    | 0 ps         |          0 |             0 |             0 |          0 |
*| localhost | show_databases    |     7 | 8.25 ms       | 3.95 ms     | 788.00 us    |         42 |            42 |             0 |          7 |
*| localhost | begin             |    91 | 7.25 ms       | 682.23 us   | 0 ps         |          0 |             0 |             0 |          0 |
*| localhost | Quit              |    92 | 2.46 ms       | 113.67 us   | 0 ps         |          0 |             0 |             0 |          0 |
*+------------+-------------------+-------+---------------+-------------+--------------+------------+---------------+---------------+------------+
*10 rows in set (0.01 sec)
 */

CREATE OR REPLACE
  ALGORITHM = MERGE
  DEFINER = 'readonly'@'%' 
  SQL SECURITY INVOKER 
VIEW host_summary_by_statement_type (
  host,
  statement,
  total,
  total_latency,
  max_latency,
  lock_latency,
  rows_sent,
  rows_examined,
  rows_affected,
  full_scans
) AS
SELECT host,
       SUBSTRING_INDEX(event_name, '/', -1) AS statement,
       count_star AS total,
       v_monitor.format_time(sum_timer_wait) AS total_latency,
       v_monitor.format_time(max_timer_wait) AS max_latency,
       v_monitor.format_time(sum_lock_time) AS lock_latency,
       sum_rows_sent AS rows_sent,
       sum_rows_examined AS rows_examined,
       sum_rows_affected AS rows_affected,
       sum_no_index_used + sum_no_good_index_used AS full_scans
  FROM performance_schema.events_statements_summary_by_host_by_event_name
 WHERE host IS NOT NULL
   AND sum_timer_wait != 0
 ORDER BY host, sum_timer_wait DESC;
 
 

 /*
 *	 global 相关的statment级别的统计，包括延迟，exec count，rows scann
 *   View: global_summary_by_statement_type
 *   统计每个statment'type 的latency，count，by total
 *   可以解决什么问题：
 *   1) 上面说了按照业务分，那么很明显这个就是总体的一个情况。
 *   2） 可以分清楚的知道这台机器IOPS，TPS，甚至可以知道每年，每月这台DB的DDL变更的数量。
 *   3） 最主要的还是延迟，如果show_status ， show variables 的延迟很大，那么就要想办法优化。 为什么show status那么多，延迟那么高？
*readonly:v_monitor> select * from global_summary_by_statement_type limit 10;
*+----------------+-----------+---------------+-------------+--------------+------------+---------------+---------------+------------+
*| statement      | total     | total_latency | max_latency | lock_latency | rows_sent  | rows_examined | rows_affected | full_scans |
*+----------------+-----------+---------------+-------------+--------------+------------+---------------+---------------+------------+
*| insert         | 891988701 | 36.21h        | 6.30 s      | 15.59h       |          0 |             0 |    2008411261 |          0 |
*| update         |  79182572 | 3.35h         | 2.62 s      | 1.25h        |          0 |      80241508 |      79084166 |          0 |
*| begin          | 971583219 | 2.50h         | 37.90 ms    | 0 ps         |          0 |             0 |             0 |          0 |
*| select         |    177367 | 1.40h         | 00:05:28.72 | 22.07 s      | 1215746513 |    1262891559 |             0 |      50531 |
*| delete         |    320751 | 00:09:52.35   | 442.94 ms   | 28.86 s      |          0 |      18367238 |      18365896 |          0 |
*| show_status    |    463635 | 00:09:29.23   | 36.06 ms    | 48.18 s      |  158098899 |     158098899 |             0 |     463635 |
*| truncate       |        82 | 00:01:24.88   | 15.45 s     | 4.17 s       |          0 |             0 |             0 |          0 |
*| drop_db        |         2 | 00:01:12.38   | 45.16 s     | 00:01:12.36  |          0 |             0 |          3100 |          0 |
*| show_variables |     84340 | 56.17 s       | 43.63 ms    | 7.35 s       |      94226 |         94226 |             0 |      84340 |
*| create_table   |      3787 | 26.76 s       | 108.38 ms   | 0 ps         |          0 |             0 |             0 |          0 |
*+----------------+-----------+---------------+-------------+--------------+------------+---------------+---------------+------------+
*10 rows in set (0.00 sec)
 */

CREATE OR REPLACE
  ALGORITHM = MERGE
  DEFINER = 'readonly'@'%' 
  SQL SECURITY INVOKER 
VIEW global_summary_by_statement_type (
  statement,
  total,
  total_latency,
  max_latency,
  lock_latency,
  rows_sent,
  rows_examined,
  rows_affected,
  full_scans
) AS
SELECT 
       SUBSTRING_INDEX(event_name, '/', -1) AS statement,
       count_star AS total,
       v_monitor.format_time(sum_timer_wait) AS total_latency,
       v_monitor.format_time(max_timer_wait) AS max_latency,
       v_monitor.format_time(sum_lock_time) AS lock_latency,
       sum_rows_sent AS rows_sent,
       sum_rows_examined AS rows_examined,
       sum_rows_affected AS rows_affected,
       sum_no_index_used + sum_no_good_index_used AS full_scans
  FROM performance_schema.events_statements_summary_global_by_event_name
 WHERE 
    sum_timer_wait != 0
 ORDER BY  sum_timer_wait DESC;




 /*
 *	 等待相关的监控 classes
 *   View: wait_classes_global_by_latency
 *    列出Top N 个 class等待event  by latency  
 *   能解决什么问题：
 *	1） 站在更高的角度来衡量，主要是table的io，文件的io，表的lock的wait事件延迟。
 
*readonly:v_monitor> select * from wait_classes_global_by_latency limit 10;
*+-----------------+------------+---------------+-------------+-------------+-------------+
*| event_class     | total      | total_latency | min_latency | avg_latency | max_latency |
*+-----------------+------------+---------------+-------------+-------------+-------------+
*| wait/io/table   | 2217307512 | 11.45h        | 72.29 ns    | 18.59 us    | 2.91 s      |
*| wait/io/file    | 4670586905 | 10.94h        | 0 ps        | 8.43 us     | 746.08 ms   |
*| wait/lock/table | 1402423408 | 00:14:28.26   | 117.97 ns   | 619.11 ns   | 12.23 ms    |
*+-----------------+------------+---------------+-------------+-------------+-------------+
*3 rows in set (0.07 sec)
 */

CREATE OR REPLACE
  ALGORITHM = TEMPTABLE
  DEFINER = 'readonly'@'%' 
  SQL SECURITY INVOKER 
VIEW wait_classes_global_by_latency (
  event_class,
  total,
  total_latency,
  min_latency,
  avg_latency,
  max_latency
) AS
SELECT SUBSTRING_INDEX(event_name,'/', 3) AS event_class, 
       SUM(COUNT_STAR) AS total,
       v_monitor.format_time(SUM(sum_timer_wait)) AS total_latency,
       v_monitor.format_time(MIN(min_timer_wait)) min_latency,
       v_monitor.format_time(IFNULL(SUM(sum_timer_wait) / NULLIF(SUM(COUNT_STAR), 0), 0)) AS avg_latency,
       v_monitor.format_time(MAX(max_timer_wait)) AS max_latency
  FROM performance_schema.events_waits_summary_global_by_event_name
 WHERE sum_timer_wait > 0
   AND event_name != 'idle'
 GROUP BY SUBSTRING_INDEX(event_name,'/', 3) 
 ORDER BY SUM(sum_timer_wait) DESC;


 /*
 *	 等待相关的监控 each host
 *   View: waits_by_host_by_latency
 *    列出Top N 个 class等待event  by latency  by each host
 *   能解决什么问题：
 *	 1） 按照业务ip进行统计，统计每个ip对应的event使用情况和压力情况
 *	 2)  如果wait/synch/mutex/innodb/buf_pool_mutex 比较高，那么需要增加innodb_buffer_pool_instances
 *	 3） 如果wait/synch/mutex/sql/Query_cache::structure_guard_mutex 比较高，那么需要disable query cache
 *	 4） 如果wait/synch/mutex/myisam/MYISAM_SHARE::intern_lock 比较高，那么请使用Myisam
 *	 5） 如果wait/io/file/sql/FRM 比较高，调整table_open_cache / table_definition_cache
 *	 6） 如果wait/io/file/sql/query_log and wait/io/file/sql/slow_log ，调整相应的general log和slow log   
 *	 7） 如果 xxx ， 那就 YYY ， 等等。  对DB底层的知识越了解，那么可以监控的点就更多，这里应有竟有。
 
* readonly:v_monitor> select * from waits_by_host_by_latency limit 10;
* +------------+--------------------------------------+------------+---------------+
* | host       | event                                | total      | total_latency |
* +------------+--------------------------------------+------------+---------------+
* | localhost | wait/io/table/sql/handler            | 1215188725 | 00:30:23.81   |
* | localhost | wait/io/file/innodb/innodb_data_file |     761405 | 00:11:22.06   |
* | localhost | wait/io/file/sql/FRM                 |     385645 | 2.42 s        |
* | localhost | wait/io/file/csv/metadata            |        132 | 633.20 ms     |
* | localhost | wait/io/file/sql/query_log           |      16567 | 199.15 ms     |
* | localhost | wait/io/file/myisam/kfile            |        906 | 67.62 ms      |
* | localhost | wait/io/file/sql/slow_log            |        215 | 62.09 ms      |
* | localhost | wait/io/file/myisam/dfile            |        725 | 41.31 ms      |
* | localhost | wait/io/file/sql/binlog              |         57 | 36.96 ms      |
* | localhost | wait/lock/table/sql/handler          |      15520 | 6.93 ms       |
* +------------+--------------------------------------+------------+---------------+
* 10 rows in set (0.01 sec)
 */

CREATE OR REPLACE
  ALGORITHM = MERGE
  DEFINER = 'readonly'@'%' 
  SQL SECURITY INVOKER 
VIEW waits_by_host_by_latency (
  host,
  event,
  total,
  total_latency
  ) AS
SELECT host,
       event_name AS event,
       count_star AS total,
       v_monitor.format_time(sum_timer_wait) AS total_latency
  FROM performance_schema.events_waits_summary_by_host_by_event_name
 WHERE event_name != 'idle'
   AND host IS NOT NULL
   AND sum_timer_wait > 0
 ORDER BY host, sum_timer_wait DESC;
 
 
 /*
 *	 等待相关的监控 global
 *   View: waits_global_by_latency
 *    列出top n IO相关等待event by latency
 *	能解决什么问题：  请参考waits_by_host_by_latency
 *readonly:v_monitor> select * from waits_global_by_latency limit 10;
 *+--------------------------------------+------------+---------------+-------------+-------------+
 *| events                               | total      | total_latency | avg_latency | max_latency |
 *+--------------------------------------+------------+---------------+-------------+-------------+
 *| wait/io/table/sql/handler            | 2217608663 | 11.45h        | 18.59 us    | 2.91 s      |
 *| wait/io/file/sql/relaylog            | 4419075002 | 4.69h         | 3.82 us     | 554.50 ms   |
 *| wait/io/file/innodb/innodb_data_file |  121477770 | 3.30h         | 97.70 us    | 746.08 ms   |
 *| wait/io/file/innodb/innodb_log_file  |  125421910 | 2.96h         | 84.99 us    | 427.05 ms   |
 *| wait/lock/table/sql/handler          | 1402672902 | 00:14:28.41   | 618.97 ns   | 12.23 ms    |
 *| wait/io/file/sql/FRM                 |     565536 | 14.44 s       | 25.54 us    | 427.89 ms   |
 *| wait/io/file/myisam/dfile            |    5077014 | 5.72 s        | 1.13 us     | 195.42 ms   |
 *| wait/io/file/sql/binlog_index        |      38950 | 1.89 s        | 48.49 us    | 288.94 ms   |
 *| wait/io/file/sql/binlog              |         78 | 111.03 ms     | 1.42 ms     | 110.20 ms   |
 *| wait/io/file/myisam/kfile            |       4910 | 65.62 ms      | 13.36 us    | 11.39 ms    |
 *+--------------------------------------+------------+---------------+-------------+-------------+
 *10 rows in set (0.09 sec)
 */
 
 CREATE OR REPLACE
   ALGORITHM = MERGE
   DEFINER = 'readonly'@'%' 
   SQL SECURITY INVOKER 
 VIEW waits_global_by_latency (
   events,
   total,
   total_latency,
   avg_latency,
   max_latency
 ) AS
 SELECT event_name AS event,
        count_star AS total,
        v_monitor.format_time(sum_timer_wait) AS total_latency,
        v_monitor.format_time(avg_timer_wait) AS avg_latency,
        v_monitor.format_time(max_timer_wait) AS max_latency
   FROM performance_schema.events_waits_summary_global_by_event_name
  WHERE event_name != 'idle'
    AND sum_timer_wait > 0
  ORDER BY sum_timer_wait DESC;



