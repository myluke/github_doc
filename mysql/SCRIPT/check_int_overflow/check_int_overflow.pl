#!/usr/bin/perl

#######################################################
# Function: check int filed if overflowing
# Usage: Run on any computer with Perl
# require: perl-SQL-Statement,DBI,DBD
########################################################

use DBI;
use DBD::mysql;
use Getopt::Std;
use Data::Dumper;
use Digest::MD5;
use POSIX;


# connect variables

my $dest_db = 'information_schema';
my $dest_ip = 'xx';
my $dest_port = '3306';
my $dest_user = 'xx';
my $dest_passwd = 'xx';

 $LOG = 'dwstats.log';
 $LOG_2 = $LOG . '.log2';
 $LOG_3 = $LOG . '.log3';
open(OUTFILE,">$LOG");

$dbh = DBI->connect(
    "DBI:mysql:$dest_db:$dest_ip:$dest_port", "$dest_user", "$dest_passwd",
    { AutoCommit => 1,RaiseError=>0,PrintError=>1,mysql_auto_reconnect=>1}
    ) or die (print 'conn mysql error'."\n" and print `date`);

my $stmt_sql = $dbh->prepare(qq{

SELECT
	            TABLE_SCHEMA,
	            TABLE_NAME,
	            COLUMNS.COLUMN_NAME,
	            COLUMNS.DATA_TYPE,
	            COLUMNS.COLUMN_TYPE,
	            IF(
	              LOCATE('unsigned', COLUMN_TYPE) > 0,
	              1,
	              0
	            ) AS IS_UNSIGNED,
	            IF(
	              LOCATE('int', DATA_TYPE) > 0,
	              1,
	              0
	            ) AS IS_INT,
	            (
	              CASE DATA_TYPE
	                WHEN 'tinyint' THEN 255
	                WHEN 'smallint' THEN 65535
	                WHEN 'mediumint' THEN 16777215
	                WHEN 'int' THEN 4294967295
	                WHEN 'bigint' THEN 18446744073709551615
	              END >> IF(LOCATE('unsigned', COLUMN_TYPE) > 0, 0, 1)
	            ) AS MAX_VALUE,
	            AUTO_INCREMENT,
		    INDEX_NAME,
		    SEQ_IN_INDEX
	          FROM
	            INFORMATION_SCHEMA.COLUMNS
	            INNER JOIN INFORMATION_SCHEMA.TABLES USING (TABLE_SCHEMA, TABLE_NAME)
		    INNER JOIN INFORMATION_SCHEMA.STATISTICS USING (TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME)

	          WHERE
	            TABLE_SCHEMA not IN ('INFORMATION_SCHEMA','mysql','performance_schema')
		  AND
		    SEQ_IN_INDEX=1
		  GROUP BY
		    TABLE_SCHEMA,TABLE_NAME,COLUMN_NAME
	          ;

 });


$stmt_sql->execute() or  print "cannot fetch data\n";

while (my $stmt_sql_ref = $stmt_sql->fetchrow_hashref()) {
	$TABLE_SCHEMA = $stmt_sql_ref->{TABLE_SCHEMA};
	$TABLE_NAME = $stmt_sql_ref->{TABLE_NAME};
	$COLUMN_NAME = $stmt_sql_ref->{COLUMN_NAME};
	$DATA_TYPE = $stmt_sql_ref->{DATA_TYPE};
	$COLUMN_TYPE = $stmt_sql_ref->{COLUMN_TYPE};
	$IS_UNSIGNED = $stmt_sql_ref->{IS_UNSIGNED};
	$IS_INT = $stmt_sql_ref->{IS_INT};
	$INDEX_NAME = $stmt_sql_ref->{INDEX_NAME};
	$SEQ_IN_INDEX = $stmt_sql_ref->{SEQ_IN_INDEX};
	if($IS_INT == 1){
		$MAX_VALUE = $stmt_sql_ref->{MAX_VALUE};

		 $stmt_sql_2 = $dbh->prepare(qq{

			select max(`$COLUMN_NAME`) AS max_real_value from `$TABLE_SCHEMA`.`$TABLE_NAME`;

		});

		$stmt_sql_2->execute();

		$MAX_REAL_VALUE = $stmt_sql_2->fetchrow_hashref()->{max_real_value};

		$INT_RATIO = eval(int($MAX_REAL_VALUE / $MAX_VALUE * 100));


		#print "$INT_RATIO  $TABLE_SCHEMA  $TABLE_NAME  $COLUMN_NAME  $DATA_TYPE  $COLUMN_TYPE  $IS_UNSIGNED  $IS_INT  $MAX_VALUE  $MAX_REAL_VALUE  $INDEX_NAME  $SEQ_IN_INDEX\n";
		print OUTFILE ("$INT_RATIO  $TABLE_SCHEMA  $TABLE_NAME  $COLUMN_NAME  $DATA_TYPE  $COLUMN_TYPE  $IS_UNSIGNED  $IS_INT  $MAX_VALUE  $MAX_REAL_VALUE  $INDEX_NAME  $SEQ_IN_INDEX\n");
	}else{
		next;
	}

}

close OUTFILE;


## sort file

`cat $LOG | sort -nr > $LOG_2 `;



## format to markdown table
open(OUTFILE_1,">$LOG");

print OUTFILE_1 ("INT_RATIO|TABLE_SCHEMA|TABLE_NAME|COLUMN_NAME|DATA_TYPE|COLUMN_TYPE|IS_UNSIGNED|IS_INT|MAX_VALUE|MAX_REAL_VALUE|INDEX_NAME|SEQ_IN_INDEX\n");
print OUTFILE_1 ("----|----|----|----|----|----|----|----|----|----|----|----|\n");

foreach $line(`cat $LOG_2`){
        chomp ($line);
        @fields=split(/  /,$line);
        $new_line = '';
        foreach $f_field(@fields){
                $new_line = $new_line  . "$f_field" . "|" ;
        }
        print OUTFILE_1 ("$new_line\n");
}
close OUTFILE_1;

`rm -f $LOG_2`;
