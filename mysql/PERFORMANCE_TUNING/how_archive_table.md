# 如何缩减数据

---

## 环境

```
OS : RHEL 6.4
disk: SSD s3700 * 6
MySQL : 5.6.16
table size : 5G
```

## 案例一

* **表大小**

```
dbadmin:test> show table status like 'zf_wuba_prop_14_lc'\G
*************************** 1. row ***************************
           Name: zf_wuba_prop_14_lc
         Engine: InnoDB
        Version: 10
     Row_format: Compact
           Rows: 17345602
 Avg_row_length: 213
    Data_length: 3708813312
Max_data_length: 0
   Index_length: 1243611136
      Data_free: 5242880
 Auto_increment: 63405198
    Create_time: 2015-07-21 09:15:26
    Update_time: NULL
     Check_time: NULL
      Collation: utf8_general_ci
       Checksum: NULL
 Create_options:
        Comment: 58房源基础信息
1 row in set (0.00 sec)



```

* **表结构**

```
CREATE TABLE `zf_wuba_prop_14_lc` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT COMMENT 'ajk房源id',
  `58prop_id` bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT '58房源id',
  `city_id` smallint(5) unsigned NOT NULL DEFAULT '0' COMMENT '城市id',
  `source_type` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '房源类型 1:个人,2:经纪人,13:大业主,14:个人抓取,15:经纪人抓取,16:58经纪人房源  17:58个人认证人审房源 18:58个人认证机审房源 19:58个人未认证房源 20:58抓取房源',
  `owner_name` varchar(20) NOT NULL DEFAULT '' COMMENT '发布人名',
  `owner_phone` varchar(20) NOT NULL DEFAULT '0' COMMENT '发布人手机号码',
  `owner_photo` varchar(200) NOT NULL DEFAULT '' COMMENT '发布人头像',
  `community_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '安居客小区id',
  `wuba_community_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '58小区id',
  `title` varchar(200) NOT NULL DEFAULT '' COMMENT '房源标题',
  `use_type_id` int(10) unsigned NOT NULL DEFAULT '5' COMMENT '房屋类型id，分城市，老公房公寓别墅等1:公寓 2:老公房 3:新里洋房 4:别墅 5:其他 6:酒店公寓 7:四合院 8:普通住宅',
  `area_num` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '面积,存放时乘以100 使用时面积/100',
  `rent_type` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '租赁类型，1:整租 2:合租',
  `share_sex` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '合租男女限制，0-2分别表示男女不限、仅限男、仅限女',
  `price` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '租金，单位元',
  `pay_type` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '付款方式,1-7分别代表面议、付3押1、付1押1、付2押1、付1押2、年付不押、半年付不押，不选或多选',
  `room_num` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '房间数量，几室',
  `hall_num` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '客厅数量',
  `toilet_num` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '厕所数量',
  `fitment_id` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '装修情况id 分城市',
  `house_orient` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '房屋朝向,1-11分别代表东、南、西、北、南北、东西、东南、西南、东北、西北、不知道朝向,单选',
  `floor` smallint(5) NOT NULL DEFAULT '0' COMMENT '所在楼层数',
  `floor_num` smallint(5) unsigned NOT NULL DEFAULT '0' COMMENT '总楼层数',
  `default_image` varchar(200) NOT NULL DEFAULT '' COMMENT '默认图',
  `status` tinyint(3) unsigned NOT NULL DEFAULT '1' COMMENT '0:删除 1:正常',
  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '房源更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `unq_58prop_id` (`58prop_id`),
  KEY `idx_updated` (`updated`)
) ENGINE=InnoDB AUTO_INCREMENT=63405198 DEFAULT CHARSET=utf8 COMMENT='58房源基础信息'

```

* **修改表结构**

```
dbadmin:test> alter table zf_wuba_prop_14_lc change community_id community_id bigint;
Query OK, 17293406 rows affected (6 min 42.47 sec)
Records: 17293406  Duplicates: 0  Warnings: 0

dbadmin:test> alter table zf_wuba_prop_14_lc engine = innodb;
Query OK, 17293406 rows affected (7 min 0.79 sec)
Records: 17293406  Duplicates: 0  Warnings: 0

```


* **删除数据**

```
dbadmin:test> delete from zf_wuba_prop_14_lc where id <> 18;
Query OK, 17293405 rows affected (3 min 10.84 sec)

dbadmin:test> select * from zf_wuba_prop_14_lc;
+----+----------------+---------+-------------+------------+-------------+-------------+--------------+-------------------+-------------------------------------------------------------------------------------+-------------+----
------+-----------+-----------+-------+----------+----------+----------+------------+------------+--------------+-------+-----------+--------------------------------------+--------+---------------------+
| id | 58prop_id      | city_id | source_type | owner_name | owner_phone | owner_photo | community_id | wuba_community_id | title                                                                               | use_type_id | are
a_num | rent_type | share_sex | price | pay_type | room_num | hall_num | toilet_num | fitment_id | house_orient | floor | floor_num | default_image                        | status | updated             |
+----+----------------+---------+-------------+------------+-------------+-------------+--------------+-------------------+-------------------------------------------------------------------------------------+-------------+----
------+-----------+-----------+-------+----------+----------+----------+------------+------------+--------------+-------+-----------+--------------------------------------+--------+---------------------+
| 18 | 21343865014421 |      14 |          17 | 张先生     | 18500371009 | null        |            0 |                 0 | 出租业主出租10号线分钟寺地铁站南北通透两室两厅精装修新房                            |           1 |
 9500 |         1 |         0 |  3800 |        4 |        2 |        2 |          1 |          7 |            2 |    10 |        15 | /p1/big/n_t030d9f8f353a080091c9c.jpg |      0 | 2015-03-26 15:33:45 |
+----+----------------+---------+-------------+------------+-------------+-------------+--------------+-------------------+-------------------------------------------------------------------------------------+-------------+----
------+-----------+-----------+-------+----------+----------+----------+------------+------------+--------------+-------+-----------+--------------------------------------+--------+---------------------+
1 row in set (2.40 sec)




dbadmin:test> alter table zf_wuba_prop_14_lc engine=innodb;
Query OK, 1 row affected (17.37 sec)
Records: 1  Duplicates: 0  Warnings: 0

dbadmin:test> show table status like 'zf_wuba_prop_14_lc'\G
*************************** 1. row ***************************
           Name: zf_wuba_prop_14_lc
         Engine: InnoDB
        Version: 10
     Row_format: Compact
           Rows: 1
 Avg_row_length: 16384
    Data_length: 16384
Max_data_length: 0
   Index_length: 32768
      Data_free: 0
 Auto_increment: 63405198
    Create_time: 2015-07-21 09:42:56
    Update_time: NULL
     Check_time: NULL
      Collation: utf8_general_ci
       Checksum: NULL
 Create_options:
        Comment: 58房源基础信息
1 row in set (0.00 sec)

```

* **结论**

```
通过以上案例，可以发现，如果很大的表，通过delete后，虽然表空间没有释放，但是alter的时间大大缩短，是否可以考虑用这种方式归档数据呢?
```