#!/usr/bin/perl -w

# This script will wait for notifications from a postgres database.
# Upon such notifications, it will iterate through a queue of 
# requests, perform some action and then remove the request from
# the work queue.
#
# When above mentioned packages are installed, we have to start the postgresql server and create a database for testing. 
## echo "postgresql_enable=YES" >>/etc/rc.conf
## /usr/local/etc/rc.d/postgresql initdb
## /usr/local/etc/rc.d/postgresql start
## createdb test -U pgsql
## psql -d test -U pgsql
# Now we create two simple tables :
# CREATE TABLE requests (
#        id SERIAL NOT NULL,
#        package_id INTEGER,
#        project_nr CHARACTER(10),
#        request_date DATE
# );
# CREATE TABLE workqueue (
#        id SERIAL NOT NULL,
#        package_id INTEGER,
#        project_nr CHARACTER(10),
#        request_date DATE
# );
#The idea is to save a history of all requests in the requests table. On receiving a request, some action should be taken by an external perl program though, therefore each new entry should also go in the workqueue table from where it will be deleted when the action has been done. 
#The duplication of new entries to the queue table will be done by a stored procedure and a trigger in the plpgsql language. These will also send a notification to the external perl script. 
#Before we can write anything in plpgsql we may need to add the language:
# CREATE OR REPLACE FUNCTION plpgsql_call_handler () RETURNS OPAQUE AS
# '/usr/local/lib/postgresql/plpgsql.so' LANGUAGE 'C';
#
# CREATE TRUSTED PROCEDURAL LANGUAGE 'plpgsql'
# HANDLER plpgsql_call_handler
# LANCOMPILER 'PL/pgSQL';
# Now we can add the stored procedure and the trigger :
# CREATE FUNCTION queue_request() RETURNS trigger AS '
# BEGIN
# INSERT INTO workqueue ( id, package_id, project_nr, request_date )
#       VALUES ( NEW.id, NEW.package_id, NEW.project_nr, NEW.request_date );
# NOTIFY request;
# RETURN NULL;
# END;
# ' LANGUAGE plpgsql;
#
# CREATE TRIGGER requesttrigger AFTER INSERT ON requests
#  FOR EACH ROW EXECUTE PROCEDURE queue_request();
#  From now on, every insert into the requests table will be duplicated in the workqueue table. Also, postgres will raise a "request" notification. This will be used by an external program written in perl. 

use strict;
use warnings;
use DBI;
use IO::Select;
use Net::Ping;
use File::Basename;
use Fcntl qw(LOCK_EX LOCK_NB);

# log facility
my $logpri = 'user.info';

my $program = basename($0);
open(SELFLOCK, "<$0") or die("Couldn't open $0: $!\n");
flock(SELFLOCK, LOCK_EX | LOCK_NB) or die("Aborting: another $program is already running\n");

# Get ready to daemonize by redirecting our output to syslog, requesting that logger prefix the lines with our program name:
open(STDOUT, "|-", "logger -p $logpri -t $program") or die("Couldn't open logger output stream: $!\n");
open(STDERR, ">&STDOUT") or die("Couldn't redirect STDERR to STDOUT: $!\n");
$| = 1; # Make output line-buffered so it will be flushed to syslog faster

chdir('/'); # Avoid the possibility of our working directory resulting in keeping an otherwise unused filesystem in use

# Double-fork to avoid leaving a zombie process behind:
exit if (fork());
exit if (fork());
sleep 1 until getppid() == 1;

print "PID $$ successfully daemonized\n";

my $dbcon_test = "dbi:Pg:dbname=test;host=127.0.0.1";
my $dbuser = "pgsql";
my $dbpass = "";
my $dbattr = {RaiseError => 1, AutoCommit => 1};

my $dbh = DBI->connect($dbcon_test, $dbuser, $dbpass, $dbattr);
my $select_handle = $dbh->prepare("select id, package_id, project_nr from workqueue");
my $delete_handle = $dbh->prepare("delete from workqueue where id = ?");

$dbh->do("LISTEN request");

my $fd = $dbh->func("getfd");
my $sel = IO::Select->new($fd);

while (1) {
    print "waiting...\n";
    $sel->can_read;
    my $notify = $dbh->func("pg_notifies");
    if ($notify) {
        $select_handle->execute();
        while (my $h = $select_handle->fetchrow_hashref()) {
            my ($id, $package_id, $project_nr) = ($h->{id}, $h->{package_id}, $h->{project_nr});

#####################################################################
#           Here the code to be executed upon each request          #
#####################################################################

            $delete_handle->execute($id);
        }
    }
}
