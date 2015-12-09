# MySQL 5.6 中 In 优化的那些事

---

## 背景

这里不准备讲 In 和 Or 的效率和区别。也不会讲 In 和 exist 的效率和区别。只是纯聊 Mysql 中常常会出现的 where xx in （）; 在实际工作中，这种用法很常见，然后再最近一段时间在优化slow query的时候，发现某些有In的查询基本上都rows exam了全表，这又是为什么呢？

## 案例一， 组合条件

---

* **表结构**

```
| ajk_market_analysis_20150212 | CREATE TABLE `ajk_market_analysis_20150212` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `daydate` date DEFAULT NULL COMMENT '日期格式2013-10-11',
  `cityId` int(11) NOT NULL DEFAULT '0' COMMENT '城市id',
  `blockId` varchar(20) NOT NULL DEFAULT '0' COMMENT '板块areacode',
  `commId` int(11) NOT NULL DEFAULT '0' COMMENT '小区id',
  `priceRank` int(11) NOT NULL DEFAULT '0' COMMENT '价格段',
  `averageVPPV` float NOT NULL DEFAULT '0' COMMENT '昨日房均有效VPPV',
  `marketScore` int(11) NOT NULL DEFAULT '0' COMMENT '市场分',
  `scoreRank` int(11) NOT NULL DEFAULT '0' COMMENT '市场分的段,值-1,2,3 3最好',
  `type` int(11) NOT NULL DEFAULT '0' COMMENT '1-定价 2竞价',
  `totalVPPV` int(11) NOT NULL DEFAULT '0' COMMENT '总有效VPPV',
  `spreadPropNum` int(11) NOT NULL DEFAULT '0' COMMENT '昨日推广房源总数',
  `isY` int(11) NOT NULL DEFAULT '0' COMMENT '总房源量是否大于Y',
  PRIMARY KEY (`id`),
  KEY `c_b_t_s_m` (`blockId`,`cityId`,`type`,`scoreRank`,`marketScore`),
  KEY `idx1` (`cityId`,`commId`),
  KEY `c_t_s_i_c` (`cityId`,`type`,`scoreRank`,`isY`,`commId`)
) ENGINE=InnoDB AUTO_INCREMENT=292829 DEFAULT CHARSET=utf8  |


*************************** 1. row ***************************
           Name: ajk_market_analysis_20150212
         Engine: InnoDB
        Version: 10
     Row_format: Compact
           Rows: 291417
 Avg_row_length: 88
    Data_length: 25739264
Max_data_length: 0
   Index_length: 53133312
      Data_free: 7340032
 Auto_increment: 292829
    Create_time: 2015-01-30 11:20:22
    Update_time: NULL
     Check_time: NULL
      Collation: utf8_general_ci
       Checksum: NULL
 Create_options:
1 row in set (0.08 sec)


```

* **执行计划**

```
root:ajk_dw_stats> explain select  `commId` , `spreadPropNum` , `totalVPPV` , `type`  from `ajk_market_analysis_20150212` where `cityId` = '14'  and `type` = '0'  and `scoreRank` in ( '2' , '3' )  and `isY` = '1'  and `commId` in ( '76832' , '76776' , '77562' , '80363' , '121238' , '182922' , '422947' , '51056' , '185557' , '81276' , '80530' , '80534' , '80217' , '76830' , '184396' , '505857' , '567958' , '78911' , '120264' , '122099' , '80401' , '299956' , '430371' , '308830' , '51235' , '81559' , '116149' , '84449' , '656162' , '502933' , '123895' , '50600' , '80535' , '122851' , '246270' , '299003' , '217889' , '186881' , '286019' , '77388' )   #broker-mobiapi: V1_Find_NearbyCommController@HotComm.php (68) 1423704168;
    ->
    -> ;
+----+-------------+------------------------------+------+----------------+------+---------+------+--------+-------------+
| id | select_type | table                        | type | possible_keys  | key  | key_len | ref  | rows   | Extra       |
+----+-------------+------------------------------+------+----------------+------+---------+------+--------+-------------+
|  1 | SIMPLE      | ajk_market_analysis_20150212 | ALL  | idx1,c_t_s_i_c | NULL | NULL    | NULL | 291417 | Using where |
+----+-------------+------------------------------+------+----------------+------+---------+------+--------+-------------+
1 row in set (0.00 sec)

```

## 案例二，单一条件

---

* **表结构**

```

| solly_nh_comm_recomm_lookandlook | CREATE TABLE `solly_nh_comm_recomm_lookandlook` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `comm_id` int(6) NOT NULL DEFAULT '0' COMMENT '楼盘id',
  `comm_id_tj` int(6) NOT NULL DEFAULT '0' COMMENT '推荐楼盘id',
  `city_id` int(2) NOT NULL DEFAULT '0' COMMENT '城市id',
  `city_id_tj` int(2) NOT NULL DEFAULT '0' COMMENT '推荐城市id',
  `tj_cishu` int(4) NOT NULL DEFAULT '0' COMMENT '推荐次数',
  `tj_rate_w` decimal(16,12) NOT NULL DEFAULT '0.000000000000' COMMENT '加权推荐次数',
  `log_dt` varchar(10) NOT NULL DEFAULT '' COMMENT '日期',
  `comm_rank` int(3) NOT NULL DEFAULT '0' COMMENT '排序',
  PRIMARY KEY (`id`),
  KEY `NewIndex1` (`comm_id`)
) ENGINE=InnoDB AUTO_INCREMENT=324992 DEFAULT CHARSET=utf8                           |

1 row in set (0.00 sec)

root:ajk_dw_stats> show table status like 'solly_nh_comm_recomm_lookandlook'\G
*************************** 1. row ***************************
           Name: solly_nh_comm_recomm_lookandlook
         Engine: InnoDB
        Version: 10
     Row_format: Compact
           Rows: 323862
 Avg_row_length: 73
    Data_length: 23642112
Max_data_length: 0
   Index_length: 7880704
      Data_free: 6291456
 Auto_increment: 324992
    Create_time: 2014-12-02 15:31:36
    Update_time: NULL
     Check_time: NULL
      Collation: utf8_general_ci
       Checksum: NULL
 Create_options:
        Comment:
1 row in set (0.07 sec)

```

* **执行计划**

```

root:ajk_dw_stats> explain SELECT * FROM solly_nh_comm_recomm_lookandlook WHERE `comm_id` IN (228955,252368,228744,249444,237337,237869,236838,236834,250955,211207);
+----+-------------+----------------------------------+------+---------------+------+---------+------+--------+-------------+
| id | select_type | table                            | type | possible_keys | key  | key_len | ref  | rows   | Extra       |
+----+-------------+----------------------------------+------+---------------+------+---------+------+--------+-------------+
|  1 | SIMPLE      | solly_nh_comm_recomm_lookandlook | ALL  | NewIndex1     | NULL | NULL    | NULL | 323862 | Using where |
+----+-------------+----------------------------------+------+---------------+------+---------+------+--------+-------------+
1 row in set (0.00 sec)

```


## 分析

---

以上两种案例，其实都是同一种情况，我们现在以第一个例子为案例进行分析

* 有idx1 索引(`cityId`,`commId`) 为啥不用呢？ 我们将 commid in 中的列表变少，看看情况怎么样？


```
root:ajk_dw_stats> explain select  `commId` , `spreadPropNum` , `totalVPPV` , `type`  from `ajk_market_analysis_20150212` where `cityId` = '14'  and `type` = '0'  and `scoreRank` in ( '2' , '3' )  and `isY` = '1'  and `commId` in ( '76832' , '76776' , '77562' , '80363' , '121238' , '182922' , '422947' , '51056' , '1111')   #broker-mobiapi: V1_Find_NearbyCommController@HotComm.php (68) 1423704168;
    -> ;
+----+-------------+------------------------------+-------+----------------+------+---------+------+------+------------------------------------+
| id | select_type | table                        | type  | possible_keys  | key  | key_len | ref  | rows | Extra                              |
+----+-------------+------------------------------+-------+----------------+------+---------+------+------+------------------------------------+
|  1 | SIMPLE      | ajk_market_analysis_20150212 | range | idx1,c_t_s_i_c | idx1 | 8       | NULL |   40 | Using index condition; Using where |
+----+-------------+------------------------------+-------+----------------+------+---------+------+------+------------------------------------+
1 row in set (0.00 sec)

```

不多不少，In 列表小于10 的时候，索引计划调整了。测试过in 后面10个列表的情况，还是很糟糕。

为啥刚好是10呢？ 搜索了一下mysql的参数,eq_range_index_dive_limit 刚好是10

```
root:ajk_dw_stats> show global variables  like '%eq_%';
+---------------------------+-------+
| Variable_name             | Value |
+---------------------------+-------+
| eq_range_index_dive_limit | 10    |
+---------------------------+-------+
1 row in set (0.00 sec)
```
那么eq_range_index_dive_limit 是用来干嘛的呢？这个参数之前有一篇分享有提过，可以参考[Mysql5.6 执行计划出错](http://gitlab.corp.anjuke.com/_dba/blog/blob/master/Keithlan/mysql/ERROR_HANDLE/mysql_group_order_limit.md)


## 解决方案

---

* **解决方案一：将In控制在10以内**
 
```
既然知道为啥了，我们是否可以有相应的措施,首先降低in的数量，用union代替

root:ajk_dw_stats> explain select  `commId` , `spreadPropNum` , `totalVPPV` , `type`  from `ajk_market_analysis_20150212` where `cityId` = '14'  and `type` = '0'  and `scoreRank` in ( '2' , '3' )  and `isY` = '1'  and `commId` in ( '76832' , '76776' , '77562' , '80363' , '121238' , '182922' , '422947' , '51056' , '185557') union select  `commId` , `spreadPropNum` , `totalVPPV` , `type`  from `ajk_market_analysis_20150212` where `cityId` = '14'  and `type` = '0'  and `scoreRank` in ( '2' , '3' )  and `isY` = '1'  and `commId` in ( '50600' , '80535' , '122851' , '246270' , '299003' , '217889' , '186881' , '286019' , '77388' );
+----+--------------+------------------------------+-------+----------------+------+---------+------+------+------------------------------------+
| id | select_type  | table                        | type  | possible_keys  | key  | key_len | ref  | rows | Extra                              |
+----+--------------+------------------------------+-------+----------------+------+---------+------+------+------------------------------------+
|  1 | PRIMARY      | ajk_market_analysis_20150212 | range | idx1,c_t_s_i_c | idx1 | 8       | NULL |   40 | Using index condition; Using where |
|  2 | UNION        | ajk_market_analysis_20150212 | range | idx1,c_t_s_i_c | idx1 | 8       | NULL |   31 | Using index condition; Using where |
| NULL | UNION RESULT | <union1,2>                   | ALL   | NULL           | NULL | NULL    | NULL | NULL | Using temporary                    |
+----+--------------+------------------------------+-------+----------------+------+---------+------+------+------------------------------------+
3 rows in set (0.00 sec)


```

但是这种方式，是否是太愚蠢了呢？ 我们不可能每次都去控制这个长度。

* **解决方案二：rebuild 索引，可能解决**

```
这种方式，我曾测试过，成功的概率10%，所以不可取。
```

* **解决方案三：设置eq_range_index_dive_limit=200，实际上Mysql5.7 已经默认为200**

```
root:(none)> set eq_range_index_dive_limit=200;
Query OK, 0 rows affected (0.00 sec)

root:ajk_dw_stats> explain select  `commId` , `spreadPropNum` , `totalVPPV` , `type`  from `ajk_market_analysis_20150212` where `cityId` = '14'  and `type` = '0'  and `scoreRank` in ( '2' , '3' )  and `isY` = '1'  and `commId` in ( '76832' , '76776' , '77562' , '80363' , '121238' , '182922' , '422947' , '51056' , '185557' , '81276' , '80530' , '80534' , '80217' , '76830' , '184396' , '505857' , '567958' , '78911' , '120264' , '122099' , '80401' , '299956' , '430371' , '308830' , '51235' , '81559' , '116149' , '84449' , '656162' , '502933' , '123895' , '50600' , '80535' , '122851' , '246270' , '299003' , '217889' , '186881' , '286019' , '77388' )   #broker-mobiapi: V1_Find_NearbyCommController@HotComm.php (68) 1423704168;
    ->
    -> ;
+----+-------------+------------------------------+-------+----------------+-----------+---------+------+------+-----------------------+
| id | select_type | table                        | type  | possible_keys  | key       | key_len | ref  | rows | Extra                 |
+----+-------------+------------------------------+-------+----------------+-----------+---------+------+------+-----------------------+
|  1 | SIMPLE      | ajk_market_analysis_20150212 | range | idx1,c_t_s_i_c | c_t_s_i_c | 20      | NULL |  104 | Using index condition |
+----+-------------+------------------------------+-------+----------------+-----------+---------+------+------+-----------------------+
1 row in set (0.06 sec)


root:ajk_dw_stats> explain SELECT * FROM solly_nh_comm_recomm_lookandlook WHERE `comm_id` IN (228955,252368,228744,249444,237337,237869,236838,236834,250955,211207);
+----+-------------+----------------------------------+-------+---------------+-----------+---------+------+------+-----------------------+
| id | select_type | table                            | type  | possible_keys | key       | key_len | ref  | rows | Extra                 |
+----+-------------+----------------------------------+-------+---------------+-----------+---------+------+------+-----------------------+
|  1 | SIMPLE      | solly_nh_comm_recomm_lookandlook | range | NewIndex1     | NewIndex1 | 4       | NULL |  200 | Using index condition |
+----+-------------+----------------------------------+-------+---------------+-----------+---------+------+------+-----------------------+
1 row in set (0.00 sec)


```
