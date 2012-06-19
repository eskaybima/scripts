#!/usr/bin/perl

# script by Arno Broekhof | April 2009
# script uses spryng.nl for sending text message to mobile phones

# define command the next command in your nagios configuration
# 'notify-by-sms' command definition
#define command{
#        command_name    notify-by-sms
#        command_line    /usr/lib/nagios/plugins/spryng.pl $CONTACTPAGER$ "$HOSTNAME$ $HOSTSTATE$ AT $LONGDATETIME$"
#} 

# System components
use LWP::UserAgent;
use strict;

# variable
my $username;			# spryng username
my $password;			# spryng password
my $destination;		# cell phone number
my $sender;			# name sender ( max 11 char )
my $body;			# message ( max 160 char )
my $url;			# spryng url



# user defined variable

$username = 'username';		# spryng username
$password = '#######';		# spryng password
$destination = $ARGV[0];	# destionation parameter
$sender ='nagios1';		# text-message name id
$body = $ARGV[1];		# body message
$url = "http://www.spryng.nl/SyncTextService?OPERATION=send&USERNAME=$username&PASSWORD=$password&DESTINATION=$destination&SENDER=$sender&BODY=$body" ;

if ( ! $ARGV ) {
  help();
}



sub error_handling {
	# error handling

	if (not defined $username ) {
			print "No username defined \n";
			help();
	}

	if (not defined $password ) {
			print "No password defined \n \n";
			help();
	}

	if (not defined $destination ) {
			help(); 
	}

	if (not defined $body ) {
			help();
	}

	if ( length($body) > 160 ) {

     		print "The message exceeds the character limit of 160 characters \n \n";
     		help();     
		}

		if ( length($sender) > 11 ) {
			print "The sender id exceeds the character limit of 11 characters \n \n";
	}
}
# show usage function
sub help {
	
	print "Error: \n"; 
	print  "usage: spryng.pl destination message \n \n" ;
	exit 0;
}

# sms function
sub sms	{
	my $ua = LWP::UserAgent->new;
	my $response =  $ua->get($url); 
	print "$response \n";	
}

#send text message
sms();


exit;
