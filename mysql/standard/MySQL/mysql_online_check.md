# MySQL 线上需要check的参数

---

## read_only 参数的检查

```
1) 必须检查所有slave是否都处于read_only=ON的状态。 
	* 如果不是，需要立马修改
```

## 账号的检查

```
1) 每个group的账号密码都要设置一样，这样方便切换。
2）由于master-slave复制的规则过滤了mysql库，所以在master添加账号的时候，必须在每台slave也做一遍
```

## MySQL5.6.x  mysql库的检查
> 在5.6中，mysql库中不仅仅是Myisam引擎，部分表是InnoDB引擎  
> 如果需要拷贝数据，请认真对待mysql库，对待innoDB引擎一样，因为元数据信息都在ibdata中  


* **从innoDB -> Myisam**

```
* 业务场景
	用innoDB实例，copy搭建一个Myisam的MySQL

* 如果想搭建一个纯Myisam引擎的数据库，必须做以下几件事情

mysql库转换引擎>
alter table innodb_index_stats engine=MyISAM;
alter table innodb_table_stats engine=MyISAM;
alter table slave_master_info engine=MyISAM;
alter table slave_relay_log_info engine=MyISAM;
alter table slave_worker_info engine=MyISAM;

添加配置到my.cnf>
	default-tmp-storage-engine=myisam
    
```

* **从Myisam -> InnoDB**

```
* 业务场景：用Myisam实例，copy搭建一个InnoDB的实例

* 一定记住：  除了转换其他库的引擎外，以下mysql库的引擎也要转换，要不然会报错

alter table innodb_index_stats engine=InnoDB;
alter table innodb_table_stats engine=InnoDB;
alter table slave_master_info engine=InnoDB;
alter table slave_relay_log_info engine=InnoDB;
alter table slave_worker_info engine=InnoDB;
```

* **从InnoDB -> InnoDB**

```
* 业务场景： 用InnoDB实例， copy搭建另一个InnoDB实例

* 记住： 要么从InnoDB A实例中copy所有数据文件，千万不能丢掉MySQL库。 以为5.6中，MySQL库中不仅仅是Myisam引擎，部分表是InnoDB引擎 

```
