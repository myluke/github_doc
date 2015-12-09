# Mysql 5.6 执行计划错误案例分析

>Depending on the details of your tables, columns, indexes, and the conditions in 
your WHERE clause, the MySQL optimizer considers many techniques to efficiently 
perform the lookups involved in an SQL query. A query on a huge table can be 
performed without reading all the rows; a join involving several tables can be performed without comparing every combination of rows. The set of operations that the optimizer chooses to perform the most efficient query is called the “query execution plan”, also known as the EXPLAIN plan. Your goals are to recognize the aspects of the EXPLAIN plan that indicate a query is optimized well, and to learn the SQL syntax and indexing techniques to improve the plan if you see some inefficient operations.

[Understanding the Query Execution Plan](http://dev.mysql.com/doc/refman/5.5/en/execution-plan-information.html)

## 前提

----------------
Mysql 优化器本就是为了优化SQL语句的查找路径而存在，当优化器足够智能的时候，这是一件美事。但是，如果优化器犯二的时候呢？有的时候执行计划看上去非常好，但是慢的无可救药。有的时候执行计划看上去很差，却跑的很欢。  接下来我们一起来看一下下面的例子：


* **表结构**



```
CREATE TABLE `prop_promotion_data` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `brokerid` int(10) NOT NULL COMMENT '经纪人id',
  `groupid` int(10) NOT NULL COMMENT '组id',
  `cid` int(10) NOT NULL COMMENT '总帐号id',
  `gid` int(10) NOT NULL COMMENT '组帐号id',
  `fix_prop_num` mediumint(6) NOT NULL COMMENT '定价推广房源总数',
  `more_10hours_num` mediumint(6) NOT NULL COMMENT '定价推广超过10小时房源数',
  `new_add_num` mediumint(6) NOT NULL COMMENT '每天新增定价推广房源数',
  `multi_map_num` mediumint(6) NOT NULL COMMENT '多图房源数',
  `fix_clicks` mediumint(6) NOT NULL COMMENT '定价推广房源点击量',
  `fix_consume` float(8,2) NOT NULL COMMENT '定价推广花费',
  `bid_prop_num` mediumint(6) NOT NULL COMMENT '竞价推广房源数',
  `bid_clicks` mediumint(6) NOT NULL COMMENT '竞价点击量',
  `bid_consume` float(8,2) NOT NULL COMMENT '竞价推广花费',
  `report_date` int(6) NOT NULL COMMENT '统计日期',
  `last_update` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '最后更新时间',
  `cst_broker_company_ids` int(10) NOT NULL DEFAULT '0' COMMENT '关联anjuke_db.ajk_brokerextend中的cst_broker_company_id',
  `new_fix_multi_num` mediumint(6) NOT NULL DEFAULT '0' COMMENT '新增定价多图房源',
  `new_bid_num` mediumint(6) NOT NULL DEFAULT '0' COMMENT '新增竞价房源数',
  `bid_multi_num` mediumint(6) NOT NULL DEFAULT '0' COMMENT '竞价多图房源',
  `new_bid_multi_num` mediumint(6) NOT NULL DEFAULT '0' COMMENT '新增竞价多图房源',
  PRIMARY KEY (`id`),
  KEY `cid` (`cid`,`report_date`),
  KEY `gid` (`gid`,`report_date`),
  KEY `report_date` (`report_date`),
  KEY `brokerid` (`brokerid`,`report_date`),
  KEY `cst_date` (`cst_broker_company_ids`,`report_date`)
) ENGINE=InnoDB AUTO_INCREMENT=57230309 DEFAULT CHARSET=utf8 COMMENT='prop_promotion_data'

```
* **total rows**

```
dbadmin:abc> select count(*) from prop_promotion_data;
+----------+
| count(*) |
+----------+
| 52023757 |
+----------+
1 row in set (14.04 sec)

```

* **index**

```
dbadmin:abc> show index from prop_promotion_data;
+---------------------+------------+--------------+--------------+------------------------+-----------+-------------+----------+--------+------+------------+---------+--------------
-+
| Table               | Non_unique | Key_name     | Seq_in_index | Column_name            | Collation | Cardinality | Sub_part | Packed | Null | Index_type | Comment | Index_comment
 |
+---------------------+------------+--------------+--------------+------------------------+-----------+-------------+----------+--------+------+------------+---------+--------------
-+
| prop_promotion_data |          0 | PRIMARY      |            1 | id                     | A         |    51696652 |     NULL | NULL   |      | BTREE      |         |
 |
| prop_promotion_data |          1 | cid          |            1 | cid                    | A         |       47341 |     NULL | NULL   |      | BTREE      |         |
 |
| prop_promotion_data |          1 | cid          |            2 | report_date            | A         |     4308054 |     NULL | NULL   |      | BTREE      |         |
 |
| prop_promotion_data |          1 | gid          |            1 | gid                    | A         |       39016 |     NULL | NULL   |      | BTREE      |         |
 |
| prop_promotion_data |          1 | gid          |            2 | report_date            | A         |     6462081 |     NULL | NULL   |      | BTREE      |         |
 |
| prop_promotion_data |          1 | report_date  |            1 | report_date            | A         |      106591 |     NULL | NULL   |      | BTREE      |         |
 |
| prop_promotion_data |          1 | cst_date     |            1 | cst_broker_company_ids | A         |      181391 |     NULL | NULL   |      | BTREE      |         |
 |
| prop_promotion_data |          1 | cst_date     |            2 | report_date            | A         |    25848326 |     NULL | NULL   |      | BTREE      |         |
 |
| prop_promotion_data |          1 | idx_brokerid |            1 | brokerid               | A         |      555877 |     NULL | NULL   |      | BTREE      |         |
 |
| prop_promotion_data |          1 | idx_brokerid |            2 | report_date            | A         |    51696652 |     NULL | NULL   |      | BTREE      |         |
 |
+---------------------+------------+--------------+--------------+------------------------+-----------+-------------+----------+--------+------+------------+---------+--------------
-+
10 rows in set (0.00 sec)

```

## 问题1
---------------
* **SQL 1**

```
dbadmin:abc> explain select distinct  `brokerid`  from `prop_promotion_data`  where `cst_broker_company_ids` in ( '59494' , '59499' , '59502' , '59727' , '60119' , '93204' )  and `report_date` >= '20141101'  and `report_date` <= '20141126'  order by `brokerid` desc limit 15,15;
+----+-------------+---------------------+-------+-------------------------------+----------+---------+------+----------+-------------+
| id | select_type | table               | type  | possible_keys                 | key      | key_len | ref  | rows     | Extra       |
+----+-------------+---------------------+-------+-------------------------------+----------+---------+------+----------+-------------+
|  1 | SIMPLE      | prop_promotion_data | index | report_date,brokerid,cst_date | brokerid | 8       | NULL | 51696652 | Using where |
+----+-------------+---------------------+-------+-------------------------------+----------+---------+------+----------+-------------+
1 row in set (0.00 sec)

dbadmin:abc> show status like 'Han%';
+----------------------------+----------+
| Variable_name              | Value    |
+----------------------------+----------+
| Handler_commit             | 1        |
| Handler_delete             | 0        |
| Handler_discover           | 0        |
| Handler_external_lock      | 2        |
| Handler_mrr_init           | 0        |
| Handler_prepare            | 0        |
| Handler_read_first         | 0        |
| Handler_read_key           | 1        |
| Handler_read_last          | 1        |
| Handler_read_next          | 0        |
| Handler_read_prev          | 45189200 |  --all index scan
| Handler_read_rnd           | 0        |
| Handler_read_rnd_next      | 1        |
| Handler_rollback           | 0        |
| Handler_savepoint          | 0        |
| Handler_savepoint_rollback | 0        |
| Handler_update             | 0        |
| Handler_write              | 0        |
+----------------------------+----------+
18 rows in set (0.00 sec)

执行时间：15 rows in set (5 min 36.12 sec)

```

* **SQL 2**

```
dbadmin:abc> explain select distinct  `brokerid`  from `prop_promotion_data` force index(brokerid) where `cst_broker_company_ids` in ( '59494' , '59499' , '59502' , '59727' , '60119' , '93204' )  and `report_date` >= '20141101'  and `report_date` <= '20141126'  order by `brokerid` desc limit 15,15
    -> ;
+----+-------------+---------------------+-------+---------------+----------+---------+------+------+-------------+
| id | select_type | table               | type  | possible_keys | key      | key_len | ref  | rows | Extra       |
+----+-------------+---------------------+-------+---------------+----------+---------+------+------+-------------+
|  1 | SIMPLE      | prop_promotion_data | index | brokerid      | brokerid | 8       | NULL | 3300 | Using where |
+----+-------------+---------------------+-------+---------------+----------+---------+------+------+-------------+
1 row in set (0.00 sec)


dbadmin:abc> show status like 'Han%';
+----------------------------+----------+
| Variable_name              | Value    |
+----------------------------+----------+
| Handler_commit             | 1        |
| Handler_delete             | 0        |
| Handler_discover           | 0        |
| Handler_external_lock      | 2        |
| Handler_mrr_init           | 0        |
| Handler_prepare            | 0        |
| Handler_read_first         | 0        |
| Handler_read_key           | 1        |
| Handler_read_last          | 1        |
| Handler_read_next          | 0        |
| Handler_read_prev          | 45189200 |
| Handler_read_rnd           | 0        |
| Handler_read_rnd_next      | 0        |
| Handler_rollback           | 0        |
| Handler_savepoint          | 0        |
| Handler_savepoint_rollback | 0        |
| Handler_update             | 0        |
| Handler_write              | 0        |
+----------------------------+----------+
18 rows in set (0.00 sec)

执行时间：15 rows in set (5 min 38.85 sec)

```
* **总结**

1. 为什么explain中的rows不一样，最终的扫描的Handler_read_prev一样呢？
		
哈哈，只能说explain 中的limit 欺骗了你。。。 [limit optimization](http://dev.mysql.com/doc/refman/5.6/en/limit-optimization.html)


## 问题二

---------------

针对以上案例，为什么Mysql 会选择brokerid 作为索引呢？为什么不用其他的索引呢？我们来强制指定看看

```
dbadmin:abc> explain select distinct  `brokerid`  from `prop_promotion_data` force index(cst_date) where `cst_broker_company_ids` in ( '59494' , '59499' , '59502' , '59727' , '60119' , '93204' )  and `report_date` >= '20141101'  and `report_date` <= '20141126'  order by `brokerid` desc limit 15,15
    -> ;
+----+-------------+---------------------+------+-----------------------+------+---------+------+----------+----------------------------------------------+
| id | select_type | table               | type | possible_keys         | key  | key_len | ref  | rows     | Extra                                        |
+----+-------------+---------------------+------+-----------------------+------+---------+------+----------+----------------------------------------------+
|  1 | SIMPLE      | prop_promotion_data | ALL  | cst_date,idx_brokerid | NULL | NULL    | NULL | 51696652 | Using where; Using temporary; Using filesort |
+----+-------------+---------------------+------+-----------------------+------+---------+------+----------+----------------------------------------------+
1 row in set (0.00 sec)

```

看样子，还是不行？ 强制索引无效。。。怎么办？那我们就应该去看看Mysql到底是如何一步一步选择执行计划的，还好Mysql 5.6 提供了另外一种追踪途径 optimizer_trace

```
mysql> SET optimizer_trace="enabled=on";

SQL1:
select distinct  `brokerid`  from `prop_promotion_data`  where `cst_broker_company_ids` in ( '59494' , '59499' , '59502' , '59727' , '60119' , '93204' )  and `report_date` >= '20141101'  and `report_date` <= '20141126'  order by `brokerid` desc limit 15,15;

mysql> SELECT trace FROM information_schema.OPTIMIZER_TRACE INTO outfile 'trace.json';

最终看到的jason时这样的(截取部分)：
            "clause_processing": {\
              "clause": "GROUP BY",\
              "original_clause": "`prop_promotion_data`.`brokerid` desc",\
              "items": [\
                {\
                  "item": "`prop_promotion_data`.`brokerid`"\
                }\
              ],\
              "resulting_clause_is_simple": true,\
              "resulting_clause": "`prop_promotion_data`.`brokerid` desc"\
            }\
          },\
          {\
            "refine_plan": [\
              {\
                "table": "`prop_promotion_data`",\
                "access_type": "table_scan"\
              }\
            ]\
          },\
          {\
            "reconsidering_access_paths_for_index_ordering": {\
              "clause": "GROUP BY",\
              "index_order_summary": {\
                "table": "`prop_promotion_data`",\
                "index_provides_order": true,\
                "order_direction": "desc",\
                "index": "brokerid",\
                "plan_changed": true,\
                "access_type": "index_scan"\

```

大家可以很清晰的看到，Mysql在之前还是有很多可以选择的索引，但是最后
reconsidering_access_paths_for_index_ordering 中却选择了brokerid，访问路径为index_scan.
奇了个怪了，为啥？google了一把后，发现之前有类似的bug [Bug #70245](http://bugs.mysql.com/
bug.php?id=70245),里面说eq_range_index_dive_limit 会影响range查询计划，官方文档确实也是这
么说的。But，无论我怎么设置eq_range_index_dive_limit的值，丝毫不会影响执行计划

```
dbadmin:abc> select @@session.eq_range_index_dive_limit;
+-------------------------------------+
| @@session.eq_range_index_dive_limit |
+-------------------------------------+
|                                  10 |
+-------------------------------------+
1 row in set (0.00 sec)
以上SQL测试均来自 @@session.eq_range_index_dive_limit。

设置成200（>in(N)）：set @@session.eq_range_index_dive_limit=200;

设置成0(<in(N))，set @@session.eq_range_index_dive_limit=0；

设置成与IN列表中的个数(=in(N))： set @@session.eq_range_index_dive_limit=6；

以上执行计划没有任何变化，跑出来的时间，和上面一样。
```

**那怎么办呢？**

* **首先**

既然brokerid干扰其优化器的选择，如果我将其drop掉,优化器是否能够选择正确的索引呢？

```
dbadmin:abc> alter table prop_promotion_data drop index brokerid;
Query OK, 0 rows affected (0.22 sec)
Records: 0  Duplicates: 0  Warnings: 0

dbadmin:abc> explain select distinct  `brokerid`  from `prop_promotion_data`  where `cst_broker_company_ids` in ( '59494' , '59499' , '59502' , '59727' , '60119' , '93204' )  and `report_date` >= '20141101'  and `report_date` <= '20141126'  order by `brokerid` desc limit 15,15;
+----+-------------+---------------------+-------+----------------------+----------+---------+------+------+--------------------------------------------------------+
| id | select_type | table               | type  | possible_keys        | key      | key_len | ref  | rows | Extra                                                  |
+----+-------------+---------------------+-------+----------------------+----------+---------+------+------+--------------------------------------------------------+
|  1 | SIMPLE      | prop_promotion_data | range | report_date,cst_date | cst_date | 8       | NULL |  780 | Using index condition; Using temporary; Using filesort |
+----+-------------+---------------------+-------+----------------------+----------+---------+------+------+--------------------------------------------------------+
1 row in set (0.00 sec)

dbadmin:abc> flush status;
Query OK, 0 rows affected (0.00 sec)

dbadmin:abc> select distinct  `brokerid`  from `prop_promotion_data`  where `cst_broker_company_ids` in ( '59494' , '59499' , '59502' , '59727' , '60119' , '93204' )  and `report_date` >= '20141101'  and `report_date` <= '20141126'  order by `brokerid` desc limit 15,15;
+----------+
| brokerid |
+----------+
|  2112641 |
|  2111870 |
|  2076429 |
|  2072897 |
|  1988209 |
|  1897956 |
|  1816767 |
|  1767494 |
|  1754405 |
|  1709879 |
|  1628017 |
|  1587473 |
|  1582185 |
|  1574712 |
|  1562055 |
+----------+
15 rows in set (0.11 sec)

dbadmin:abc> show status like 'Hand%';
+----------------------------+-------+
| Variable_name              | Value |
+----------------------------+-------+
| Handler_commit             | 1     |
| Handler_delete             | 0     |
| Handler_discover           | 0     |
| Handler_external_lock      | 2     |
| Handler_mrr_init           | 0     |
| Handler_prepare            | 0     |
| Handler_read_first         | 0     |
| Handler_read_key           | 6     |
| Handler_read_last          | 0     |
| Handler_read_next          | 781   |
| Handler_read_prev          | 0     |
| Handler_read_rnd           | 30    |
| Handler_read_rnd_next      | 36    |
| Handler_rollback           | 0     |
| Handler_savepoint          | 0     |
| Handler_savepoint_rollback | 0     |
| Handler_update             | 0     |
| Handler_write              | 781   |
+----------------------------+-------+
18 rows in set (0.00 sec)
```
**果然，Mysql选择了正确的索引，跑起来还不错。但是那个索引要经常被用到，不能被删除，结果这条道路是走不通的。**

* **其次**

再回头看看trace的选择，里面有关于"clause": "GROUP BY"？  我就再想，是不是由于Group by的原因呢？不清楚，那就试试呗，于是将distinct去掉，试试看

```
dbadmin:abc> explain select   `brokerid`  from `prop_promotion_data` force index(cst_date) where `cst_broker_company_ids` in ( '59494' , '59499' , '59502' , '59727' , '60119' , '93204' )  and `report_date` >= '20141101'  and `report_date` <= '20141126'  order by `brokerid` desc limit 15,15;
+----+-------------+---------------------+-------+---------------+----------+---------+------+------+---------------------------------------+
| id | select_type | table               | type  | possible_keys | key      | key_len | ref  | rows | Extra                                 |
+----+-------------+---------------------+-------+---------------+----------+---------+------+------+---------------------------------------+
|  1 | SIMPLE      | prop_promotion_data | range | cst_date      | cst_date | 8       | NULL |  780 | Using index condition; Using filesort |
+----+-------------+---------------------+-------+---------------+----------+---------+------+------+---------------------------------------+
1 row in set (0.00 sec)


dbadmin:abc> show status like 'Hand%';
+----------------------------+-------+
| Variable_name              | Value |
+----------------------------+-------+
| Handler_commit             | 1     |
| Handler_delete             | 0     |
| Handler_discover           | 0     |
| Handler_external_lock      | 2     |
| Handler_mrr_init           | 0     |
| Handler_prepare            | 0     |
| Handler_read_first         | 0     |
| Handler_read_key           | 6     |
| Handler_read_last          | 0     |
| Handler_read_next          | 781   |
| Handler_read_prev          | 0     |
| Handler_read_rnd           | 0     |
| Handler_read_rnd_next      | 0     |
| Handler_rollback           | 0     |
| Handler_savepoint          | 0     |
| Handler_savepoint_rollback | 0     |
| Handler_update             | 0     |
| Handler_write              | 0     |
+----------------------------+-------+
18 rows in set (0.00 sec)
```

情况貌似好转了，但是这样子是不满足业务逻辑的呀。。。。
于是，再仔细看看SQL语句的，发现order by 和 group by 重合了，，，为啥不利用group by来排序呢？
so，SQL语句这样修改一下

```
dbadmin:abc> explain select   `brokerid`    from     `prop_promotion_data`  where `cst_broker_company_ids` in ( '59494' , '59499' , '59502' , '59727' , '60119' , '93204' )  and `report_date` >= '20141101'  and `report_date` <= '20141126'   group  by `brokerid` desc limit 15,15;
+----+-------------+---------------------+-------+-----------------------------------+----------+---------+------+------+--------------------------------------------------------+
| id | select_type | table               | type  | possible_keys                     | key      | key_len | ref  | rows | Extra                                                  |
+----+-------------+---------------------+-------+-----------------------------------+----------+---------+------+------+--------------------------------------------------------+
|  1 | SIMPLE      | prop_promotion_data | range | report_date,cst_date,idx_brokerid | cst_date | 8       | NULL |  780 | Using index condition; Using temporary; Using filesort |
+----+-------------+---------------------+-------+-----------------------------------+----------+---------+------+------+--------------------------------------------------------+
1 row in set (0.01 sec)

dbadmin:abc> show status like 'Hand%';
+----------------------------+-------+
| Variable_name              | Value |
+----------------------------+-------+
| Handler_commit             | 1     |
| Handler_delete             | 0     |
| Handler_discover           | 0     |
| Handler_external_lock      | 2     |
| Handler_mrr_init           | 0     |
| Handler_prepare            | 0     |
| Handler_read_first         | 0     |
| Handler_read_key           | 6     |
| Handler_read_last          | 0     |
| Handler_read_next          | 781   |
| Handler_read_prev          | 0     |
| Handler_read_rnd           | 15    |
| Handler_read_rnd_next      | 36    |
| Handler_rollback           | 0     |
| Handler_savepoint          | 0     |
| Handler_savepoint_rollback | 0     |
| Handler_update             | 0     |
| Handler_write              | 781   |
+----------------------------+-------+
18 rows in set (0.00 sec)


```

* **从性能上看**

```
优化前的SQL：
dbadmin:abc> select distinct  `brokerid`  from `prop_promotion_data`  where `cst_broker_company_ids` in ( '59494' , '59499' , '59502' , '59727' , '60119' , '93204' )  and `report_date` >= '20141101'  and `report_date` <= '20141126'  order by `brokerid` desc limit 15,15;

+----------+
| brokerid |
+----------+
|  2112641 |
|  2111870 |
|  2076429 |
|  2072897 |
|  1988209 |
|  1897956 |
|  1816767 |
|  1767494 |
|  1754405 |
|  1709879 |
|  1628017 |
|  1587473 |
|  1582185 |
|  1574712 |
|  1562055 |
+----------+
15 rows in set (5 min 42.10 sec)

优化后的SQL：
dbadmin:abc> select  `brokerid`  from `prop_promotion_data`  where `cst_broker_company_ids` in ( '59494' , '59499' , '59502' , '59727' , '60119' , '93204' )  and `report_date` >= '20141101'  and `report_date` <= '20141126' group by `brokerid` desc limit 15,15;
+----------+
| brokerid |
+----------+
|  2112641 |
|  2111870 |
|  2076429 |
|  2072897 |
|  1988209 |
|  1897956 |
|  1816767 |
|  1767494 |
|  1754405 |
|  1709879 |
|  1628017 |
|  1587473 |
|  1582185 |
|  1574712 |
|  1562055 |
+----------+
15 rows in set (0.01 sec)


PS：为了保证SQL的效率的准确性，以上SQL均重启后第一次跑的时间为准。
```

* **总结**

	1. distinct，orderby ，group by，limit 这几个条件放在一起，会给Mysql 优化器带来很大的负担，建议尽量不要这样使用。



