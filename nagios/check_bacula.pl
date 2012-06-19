#!/usr/bin/perl -w

# Bacula check script looks in the database if a job is succesful

# Written by Arno Broekhof | 2009



use strict;
use POSIX;
use File::Basename;
use DBI;
use Getopt::Long;
use vars qw(
       $opt_help
           $opt_job
           $opt_critical
           $opt_warning
           $opt_hours
           $opt_usage
           $opt_version
           $out
           $sql
           $date_start
           $date_stop
           $state
           $count
           );
           
sub print_help();
sub print_usage();
sub get_now();
sub get_date;

my $progname = basename($0);
my $progVers = "0.0.3";
my $sqlDB = "bacula";
my $sqlUsername = "bacula";
my $sqlPassword = "";

my %ERRORS = (  'UNKNOWN'       =>      '-1',
                'OK'            =>      '0',
                'WARNING'       =>      '1',
                'CRITICAL'      =>      '2');

Getopt::Long::Configure('bundling');
GetOptions
        (
        "c=s"   =>      \$opt_critical, "critical=s"    =>      \$opt_critical,
        "w=s"   =>      \$opt_warning,  "warning=s"     =>      \$opt_warning,
        "H=s"   =>      \$opt_hours,    "hours=s"       =>      \$opt_hours,
        "j=s"   =>      \$opt_job,      "job=s"         =>      \$opt_job,
        "h"     =>      \$opt_help,     "help"          =>      \$opt_help,
                                        "usage"         =>      \$opt_usage,
        "V"     =>      \$opt_version,  "version"       =>      \$opt_version
        ) || die "Try '$progname --help' for more information.\n";

sub print_help() {
 print "\n";
 print "If Bacula holds its MySQL-data behind password, you have to manually enter the password into the script as variable \$sqlPassword.\n";
 print "And be sure to prevent everybody from reading it!\n";
 print "\n";
 print "Options:\n";
 print "H	check successful jobs within <hours> period\n";
 print "c	number of successful jobs for not returning critical\n";
 print "w	number of successful jobs for not returning warning\n";
 print "j	name of the job to check (case-sensitive)\n";
 print "h	show this help\n";
 print "V	print script version\n";
}

sub print_usage() {
 print "Usage: $progname -H <hours> -c <critical> -w <warning> -j <job-name> [ -h ] [ -V ]\n";
}

sub get_now() {
 my $now  = defined $_[0] ? $_[0] : time;
 my $out = strftime("%Y-%m-%d %X", localtime($now));
 return($out);
}

sub get_date {
 my $day = shift;
 my $now  = defined $_[0] ? $_[0] : time;
 my $new = $now - ((60*60*1) * $day);
 my $out = strftime("%Y-%m-%d %X", localtime($new));
 return ($out);
}

if ($opt_help) {
 print_usage();
 print_help();
 exit $ERRORS{'UNKNOWN'};
}

if ($opt_usage) {
 print_usage();
 exit $ERRORS{'UNKNOWN'};
}

if ($opt_version) {
 print "$progname $progVers\n";
 exit $ERRORS{'UNKNOWN'};
}


if ($opt_job && $opt_warning && $opt_critical) {
 my $dsn = "DBI:mysql:database=$sqlDB;host=localhost";
 my $dbh = DBI->connect( $dsn,$sqlUsername,$sqlPassword ) or die "Error connecting to: '$dsn': $DBI::errstr\n";
 
 if ($opt_hours)
 {
  $date_stop = get_date($opt_hours);
 }
  else
  {
   $date_stop = '1970-01-01 01:00:00';
  }
 
 $date_start = get_now();
 
 $sql = "SELECT count(*) as 'count' from Job where (Name='$opt_job') and (JobStatus='T') and (EndTime <> '') and ((EndTime <= '$date_start') and (EndTime >= '$date_stop'));";

 my $sth = $dbh->prepare($sql) or die "Error preparing statemment",$dbh->errstr;
 $sth->execute;
 
 while (my @row = $sth->fetchrow_array()) {
  ($count) = @row;
 }
$state = 'OK';
if ($count<$opt_warning) { $state='WARNING' }
if ($count<$opt_critical) { $state='CRITICAL' }

print "Bacula $state: Found $count successful jobs\n";
exit $ERRORS{$state};
 $dbh->disconnect();
}
 else {
  print_usage();
 }

