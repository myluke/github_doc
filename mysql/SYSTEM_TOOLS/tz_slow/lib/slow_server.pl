#!/usr/bin/perl

#######################################################
# Function: slow server , slow analysis
# Usage: Run on any computer with Perl
# require: perl-SQL-Statement,DBI,DBD
# /usr/lib/perl5/vendor_perl/5.8.8/SQL/Parser.pm by keith
# /usr/lib/perl5/vendor_perl/5.8.8/SQL/Dialects/ANSI.pm  by keith
# /usr/lib/perl5/vendor_perl/5.8.8/SQL/Dialects/AnyData.pm by keith
########################################################

use DBI;
use DBD::mysql;
use Getopt::Std;
use Data::Dumper;
use SQL::Parser_v2;
use Digest::MD5;
use POSIX;

########################################################
# 全局mysql配置连接参数变量
my $server_db = 'tz_slow';
my $server_ip = 'xx';
my $server_port = '3306';
my $server_user = 'slow_rx';
my $server_passwd = 'xx';
my $server_tb_queue = 'slow_queue';
my $server_tb_slow = 'global_query_review';
my $server_tb_slow_history_prefix = 'global_query_review_history_';
my $server_tb_slow_history= '';

# 全局结果变量
my $f_app_ip = '';
my $f_db_ip = '';
my $f_db_name = '';
my $f_db_port = '';
my $f_tb_name = '';
my $f_checksum = '';
my $f_fingerprint = '';
my $f_query_type = '';
my $f_sample = '';
my $f_ts_min = '';
my $f_ts_max = '';
my $f_ts_cnt = '';
my $f_first_seen = '';
my $f_last_seen = '';
my $f_query_time_pct_95 = '';
my $f_rows_sent_pct_95 = '';
my $f_rows_examined_pct_95 = '';
my $local_time = strftime("%Y-%m-%d %H:%M:%S",localtime());
#  全局中间变量
my %hh_slow_queue = ();
my @h_slow_queue = ();
my @arr_app_2_cnt = ();
my $f_queue_id = '';

my $mysqlsla_bin = '/usr/local/bin/mysqlsla';
my $mysqlsla_dir = '/data1/tz_slow';

#######################################################
# 主程序
#######################################################

# 从队列中获取需要解析的日志
&get_slow_queue();


# 批量解析slow sql file 并且写入数据库
 &parse_sql();

#从slow_queue中获得需要处理的数据信息
sub get_slow_queue() {
    #connect server  
    $dbh = DBI->connect(
        "DBI:mysql:$server_db:$server_ip:$server_port", "$server_user", "$server_passwd",
        { AutoCommit => 1,RaiseError=>0,PrintError=>1,mysql_auto_reconnect=>1}
        ) or die (print 'conn mysql error'."\n" and print `date`);
    $dbh->do("SET character_set_client='utf8'");
    $dbh->do("SET character_set_connection='utf8'");
    $dbh->do("SET character_set_results='utf8'");
    my $stmt_sql = $dbh->prepare(qq{ SELECT id,host_ip,host_name,host_port,file_name,ts_min,ts_max 
					FROM $server_tb_queue 
					 WHERE isParse=0   
					  ORDER BY ts_min });
    $stmt_sql->execute() or  print "cannot fetch data\n";    
    while (my $stmt_sql_ref = $stmt_sql->fetchrow_hashref()) {
        $hh_slow_queue{host_ip}=$stmt_sql_ref->{host_ip};
        $hh_slow_queue{host_name}=$stmt_sql_ref->{host_name};
        $hh_slow_queue{host_port}=$stmt_sql_ref->{host_port};
        $hh_slow_queue{file_name}=$stmt_sql_ref->{file_name};
        $hh_slow_queue{ts_min}=$stmt_sql_ref->{ts_min};
	$hh_slow_queue{ts_max}=$stmt_sql_ref->{ts_max};
        $hh_slow_queue{id}=$stmt_sql_ref->{id};
        push @h_slow_queue , { %hh_slow_queue };
    }
}

#解析所有需要处理的slow log
sub parse_sql() {
    
    #循环处理isParse=0的所有文件
    for $h_ref(@h_slow_queue) {
	$f_ts_min = '';
	$f_ts_max = '';
        #print "$h_ref->{file_name},$h_ref->{ts_max}\n";
        $f_db_ip = $h_ref->{host_ip};
	$f_db_name = $h_ref->{host_name};
	$f_db_port = $h_ref->{host_port};
	my $f_file_name = $mysqlsla_dir . '/' . $h_ref->{file_name};
	$f_ts_min = $h_ref->{ts_min};
	$f_ts_max = $h_ref->{ts_max};
	$f_queue_id = $h_ref->{id};
	$signal = &parse_file($f_file_name); #parse slow log file to sla & analysis sla	
	print "signal=$signal\n";
	if ( $signal ne 1){ #because error,cannot update isParse from 0 to 1;
		print "success file = $f_file_name\n";
		$dbh->do(qq{ UPDATE $server_tb_queue SET isParse=1 WHERE id = $f_queue_id });
	}


	
    }     
}

#详细解析函数，用于sub parse_sql() 中
sub parse_file() {
    my $slow_file = shift;
    
    if( !open (LOG,"$mysqlsla_bin --db-inheritance -sf='-SET' --top 100000  $slow_file 2>&1 |")) {
        print ("parse_slow_logs: cannot open slow log file '$slow_file': $!\n");
	return 1;  #error : cannot open slow log
	last;
    }

	
    while($line = <LOG>){
	$f_db_name = '';
	if($line =~ m/Cannot auto-detect/){
	    return 2; #error : have no slow query
        }
	last if !defined $line;
        next until $line =~ /^___________________________________________________________________/; # Fast-forward to a recognizable header
        $line = <LOG>;
        $line =~ m/Count         : (\d+) .*/;
        chomp($f_ts_cnt = $1);
        chomp($line = <LOG>);
        $line =~ m/.* total,(.*) avg, .*/;
        chomp($f_query_time_pct_95 = $1);
        while($line = <LOG>){
            if($line =~ m/Rows sent\s+: (.*?) avg, .*/){
                $f_rows_sent_pct_95 = $1;
                last;
            }
        }
        $line = <LOG>;
        $line =~ m/Rows examined : (.*?) avg, .*/;
        $f_rows_examined_pct_95 = $1;
        $line = <LOG>;
        $line =~ m/Database\s+: (.*)/;
        $f_db_name = $1;
        $line = <LOG>;
        my $app_2_cnt = '';
        @arr_app_2_cnt = ();
        while($line !~ m/ip sum/){
            if($line =~ m/\@\s?(.*?)\s+:.*?\((\d+)\)/){
                 $app_2_cnt = "$1".'_' ."$2\n";
                 push @arr_app_2_cnt,$app_2_cnt;
            }
            $line = <LOG>;
        }
        $line =~ m/ip sum\s+: (.*)/;
        $ip_sum = $1;
	if($ip_sum =~ m/users/i){
	    $ip_sum = '127.0.0.1'; 
        }
        $line = <LOG>;
        $line = <LOG>;
        $f_fingerprint = <LOG>;
        chomp($f_fingerprint);
        $f_fingerprint .= ';' if($f_fingerprint !~ m/;$/); 
	$f_fingerprint =~ s/;$//g;   #去掉指纹后的分号,SQL::Parser_v2不支持带有分号的sql
        $f_checksum = &create_md5($f_fingerprint);
        $line = <LOG>;
        $line = <LOG>;
        $f_sample = '';
        while($line = <LOG>){
	    $line =~ s/^\s+//go; #remove leading blank space
            chomp($line); #remove last blank space
            if($line =~ /;$/){
                $f_sample .= ' ' . $line;
                last;
            }else{
                $f_sample .= ' ' . $line;
            }
        }

	$f_sample =~ s/^\s+//go; #remove leading blank space
        #去掉``
        #$f_sample =~ s/`//go;
        #去掉特殊字符'^M'
        $f_sample =~ s///go;
        $f_sample =~ s/;$//g; #去掉sample末尾的分号,SQL::Parser_v2不支持带有分号的sql
        chomp($f_sample);
	&get_info_more($f_fingerprint);  #get more information	
        print "
            ts_cnt=$f_ts_cnt
            Query_time_pct_95=$f_query_time_pct_95
            Rows_sent_pct_95=$f_rows_sent_pct_95
            Rows_examined_pct_95=$f_rows_examined_pct_95
            db_name=$f_db_name
            ip_sum=$ip_sum
            finger_print=$f_fingerprint
            checksum=$f_checksum
            sample=$f_sample
	    tb_name=$f_tb_name
	    query_type=$f_query_type
       \n";
       
	&write_to_mysql($f_app_ip); #将解析结果写入mysql
    }
    close LOG;

    return 0; #sucess
}

##生成MD5值
sub create_md5{
    $before_md5 = $_[0];
    $md5= Digest::MD5->new;
    $md5->add($before_md5);
    $md5_value = $md5->hexdigest;
    return $md5_value;
}


##获取table_name，query type，以及更新db_name(Mysql使用者的不规范，如xx.xx,而不是use dbname)
sub get_info_more {
    my $sql = shift;
    my $parser = SQL::Parser_v2->new();
    print "my_sql = $sql\n";
    my $success = $parser->parse($sql);
    my $tables = $parser->structure->{'org_table_names'};
    foreach my $table (@$tables) {
         $f_tb_name = $table;
    }

    $f_query_type = $parser->structure->{'command'};
    if($f_tb_name =~ m/(.*?)\.(.*)/ ){
	$f_db_name = $1;
        $f_tb_name = $2;
    }
}

sub write_to_mysql() {
    $f_app_ip = shift;
    my $stmt_sql = $dbh->prepare(qq{ SELECT id,last_seen,first_seen FROM $server_tb_slow WHERE checksum='$f_checksum'  });
    $stmt_sql->execute() or  print "cannot fetch data\n";
    my $stmt_sql_ref = $stmt_sql->fetchrow_hashref();
    $row_id = $stmt_sql_ref->{id};
    $row_last_seen = $stmt_sql_ref->{last_seen};
    $f_ts_min =~ m/(\d+)-(\d+)-(\d+) .*/;
    $server_tb_slow_history =  $server_tb_slow_history_prefix . "$1$2$3";
    print "my_tb=$server_tb_slow_history\n";
    $f_sample = $dbh->quote($f_sample);  #mysql插入中，去掉特殊引号干扰。
    if($row_id eq ''){ #如果checksum不存在，那么插入新记录
        $dbh->do(qq{ INSERT INTO $server_tb_slow(checksum,fingerprint,sample,first_seen,last_seen)
                        VALUES("$f_checksum","$f_fingerprint",$f_sample,"$f_ts_min","$f_ts_max")
                        });    
        foreach  $one_app_cnt(@arr_app_2_cnt){
	   ( $f_app_ip,$f_ts_cnt)=$one_app_cnt =~ m/(.*?)_(.*)/; 
	   print "one_app_cnt = $one_app_cnt\n";
           $dbh->do(qq{ INSERT INTO $server_tb_slow_history(
                                        db_ip,
                                        app_ip,
                                        db_name,
                                        tb_name,
                                        checksum,
                                        query_type,
                                        sample,
                                        ts_min,
                                        ts_max,
                                        ts_cnt,
                                        query_time_pct_95,
                                        rows_sent_pct_95,
                                        rows_examined_pct_95,
                                        db_port)
                             VALUES(
                                        "$f_db_ip",
                                        "$f_app_ip",
                                        "$f_db_name",
                                        "$f_tb_name",
                                        "$f_checksum",
                                        "$f_query_type",
                                        $f_sample,
                                        "$f_ts_min",
                                        "$f_ts_max",
                                        "$f_ts_cnt",
                                        "$f_query_time_pct_95",
                                        "$f_rows_sent_pct_95",
                                        "$f_rows_examined_pct_95",
                                        "$f_db_port"
                                ) });
        }
    }else{ 
        if( $row_last_seen eq "$f_ts_max"){ #如果checksum已经存在了,但是last seen一样，说明是重复插入，不需要写入history表
		print "insert on duplicate\n";
        }else{ #如果checksum已经存在了 并且 last seen也不一样，那么更新last seen字段，且写入history表

    	    $dbh->do(qq{ UPDATE $server_tb_slow SET last_seen='$f_ts_max' WHERE id = $row_id });

            foreach  $one_app_cnt(@arr_app_2_cnt){   
		( $f_app_ip,$f_ts_cnt)=$one_app_cnt =~ m/(.*?)_(.*)/;
		print "one_app_cnt = $one_app_cnt\n";
                $dbh->do(qq{ INSERT INTO $server_tb_slow_history(
                                        db_ip,
                                        app_ip,
                                        db_name,
                                        tb_name,
                                        checksum,
                                        query_type,
                                        sample,
                                        ts_min,
                                        ts_max,
                                        ts_cnt,
                                        query_time_pct_95,
                                        rows_sent_pct_95,
                                        rows_examined_pct_95,
                                        db_port)
                                 VALUES(
                                        "$f_db_ip",
                                        "$f_app_ip",
                                        "$f_db_name",
                                        "$f_tb_name",
                                        "$f_checksum",
                                        "$f_query_type",
                                        $f_sample,
                                        "$f_ts_min",
                                        "$f_ts_max",
                                        "$f_ts_cnt",
                                        "$f_query_time_pct_95",
                                        "$f_rows_sent_pct_95",
                                        "$f_rows_examined_pct_95",
                                        "$f_db_port"
                                ) });
	    }
	}
    }
    
        
}
