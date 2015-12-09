#!/usr/bin/perl

use strict;
use POSIX qw(strftime);
use Time::Local;

use constant GENLOG_DIR => '/data1/Genlog';

my %p_group = (
    'Group1' => '01',
    'Group2' => '02'
);

$ENV{'HADOOP_USER_NAME'} = 'hadoop';

my $interrupted = 0;
sub INTERRUPTER {
    $interrupted = 1;
}
$SIG{TERM} = \&INTERRUPTER;
$SIG{INT} = \&INTERRUPTER;

sub logger {
    my $msg = shift;
    print strftime('%Y-%m-%d %H:%M:%S', localtime) . " $msg\n";
}

sub process_one {

    my $group = shift;
    logger "Start $group";

    my $dirname = GENLOG_DIR . "/$group";
    opendir my $dir, $dirname;

    for my $filename (readdir $dir) {
        last if ($interrupted);
        next if ($filename eq '.');
        next if ($filename eq '..');
        next if (-d $filename);

        my ($year, $month, $day) = $filename =~ /^([0-9]{4})([0-9]{2})([0-9]{2})[0-9]{4}_(dw)?[0-9]+/;
        if (!$year) {
            next;
        }

        my @filestats = stat "$dirname/$filename";
        if (time - $filestats[10] < 300) {
            next;
        }

        logger "Processing '$dirname/$filename'.";

        if ($filename !~ /\.gz$/) {
            logger 'Gzipping...';
            `gzip $dirname/$filename`;
            if ($? != 0) {
                logger 'Gzip failed';
                next;
            }

            $filename .= '.gz';
        }

        logger 'Uploading...';
        my $upload_result = `/home/hadoop/hadoop-1.0.1/bin/hadoop dfs -put $dirname/$filename /user/anjuke/mysql_genlog/p_year=$year/p_month=$month/p_day=$day/p_group=$p_group{$group}/$filename 2>&1`;

        if ($? != 0 && $upload_result !~ /already exists/) {
            logger 'Upload failed.';
            next;
        }

        logger 'Deleting...';
        `rm -f $dirname/$filename`;

        if ($? != 0) {
            logger 'Move or delete failed.';
            next;
        }

    }

    closedir $dir;
}


while (!$interrupted) {

    while (my ($key, $value) = each %p_group) {
        last if ($interrupted);
        process_one $key;
    }

    if (!$interrupted) {
        logger 'Sleeping for 10 min.';
        sleep(600);
    }

}

logger 'Job exits.';
