#!/usr/bin/env perl

use strict;
use warnings;

use DBI;
use DateTime;
use DateTime::Duration;
use Getopt::Long;
use Pod::Usage;
use IO::Handle;

STDOUT->autoflush(1);
STDERR->autoflush(1);

sub logger {
    my $msg = shift;
    print DateTime->now()->strftime('%Y-%m-%d %H:%M:%S') . " $msg\n";
}

sub import_env {
    my $prefix = shift;
    my %result = ();
    for my $suffix ('ip', 'port', 'user', 'password') {
        my $key = "${prefix}_${suffix}";
        if (!exists $ENV{$key}) {
            logger "Env '$key' not found.";
            exit 2;
        }
        $result{$suffix} = $ENV{$key};
    }
    return \%result;
}

sub db_connect {
    my ($server, $database) = @_;
    my $dbh = DBI->connect(
        "DBI:mysql:$database:$server->{ip}:$server->{port}",
        $server->{user}, $server->{password},
        { AutoCommit => 1}
    );
    if (!$dbh) {
        logger "Unable to connect to $server->{ip}:$server->{port}.";
        exit 2;
    }
    return $dbh;
}

my $help = 0;
my $database;
my $table;
my $pk_field;
my $date_field;
my $date_format = '%Y%m%d';
my $keep_days;
my $per_fetch = 200;
my $sleep_secs = 1;

GetOptions (
    'help|?' => \$help,
    'database=s' => \$database,
    'table=s' => \$table,
    'pk-field=s' => \$pk_field,
    'date-field=s' => \$date_field,
    'date-format=s' => \$date_format,
    'keep-days=i' => \$keep_days,
    'per-fetch=i' => \$per_fetch,
    'sleep-secs=i' => \$sleep_secs
) or pod2usage(2);
pod2usage(1) if ($help || !$database || !$table || !$pk_field || !$date_field || !$date_format || !$keep_days || !$per_fetch || !$sleep_secs);

my $end_day = DateTime->today - DateTime::Duration->new(days => $keep_days);
$end_day = $end_day->strftime($date_format);

logger "Start archiving $database.$table, before $end_day.";

my $backup = import_env('backup');
my $master = import_env('master');

my $dbh_backup = db_connect($backup, $database);
my $dbh_master = db_connect($master, $database);

my $stmt_select = $dbh_backup->prepare(
    "SELECT $pk_field FROM $table WHERE $date_field < '$end_day' LIMIT $per_fetch"
);

while (1) {

    $stmt_select->execute;
    my @id_list = ();
    while (my @row = $stmt_select->fetchrow_array) {
        push @id_list, $row[0];
    }
    my $fetched_rows = scalar(@id_list);
    last if ($fetched_rows == 0);

    my $id_str = join ',', @id_list;
#    logger "Deleting $id_str";
    my $stmt_delete = $dbh_master->prepare(
        "DELETE FROM $table WHERE $pk_field IN ($id_str)"
    );
    my $affected_rows = $stmt_delete->execute;

    logger "Fetched $fetched_rows rows, deleted $affected_rows rows.";

    last if ($fetched_rows < $per_fetch);
    sleep $sleep_secs;
}

$stmt_select->finish;
$dbh_backup->disconnect;
$dbh_master->disconnect;
logger "Job done.";

__END__

=head1 NAME

Archive by date.

=head1 SYNOPSIS

export backup_ip backup_port backup_user backup_password

export master_ip master_port master_user master_password

archive_by_date.pl [options]

  Options:
    --help        brief help message
    --database    database name
    --table       table name
    --pk-field    primary key field name
    --date-field  date field name
    --date-format date field format, default '%Y%m%d'
    --keep-days   keep how many days of data
    --per-fetch   per delete count, default 200
    --sleep-secs  sleep seconds, default 1

=cut
