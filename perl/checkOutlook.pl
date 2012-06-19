#!/usr/bin/perl -W


# checkoutlook.pl is a perl script by to check mail on Microsoft's Outlook web access
# based mail reader.
# The script currently only checks for mail, and then logs out, printing the sender and subject 
# of the message, if applicable. The script can be run in daemon mode, in which case it runs 
# in silence until a message is received.  
#
# This script has been tested on one server only. It is at this moment uncertain to me wether
# the script will work for other configurations. Feedback will be appreciated.
#
# For updates check http://ziad.dds.nl/checkoutlook/
#
#
#
# Arguments:
# -d, --daemon      : run in daemon mode
#     --debug       : print some extra debugging info
# -i, --interactive : prompt the user to read or delete the messages interactively  
# -v, --version     : print version information and exit     
#
#
# Requirements:
# Bundle::LWP   
# MIME::Head
# Crypt::SSLeay (for https)
# Term::ReadKey (for safe password entry)
#
#
# All these modules are available at www.cpan.org, or installed automagically 
# using the 'perl -MCPAN -e 'install Bundle::LWP' command.
#
#
#
#
# CHANGELOG
# 1.0.0     02-dec-2007     Initial version 
# 1.0.1     04-dec-2007     URL corruption bugfix 
# 1.0.2     06-dec-2007     Neater mail notification 
# 1.1.0     04-jan-2008     Interactive mode added to retrieve or delete messages 
#
#
#
# THANKS
# This script comes with some functionality based on # functions within FetchYahoo by 
# Ravi Ramkissoon. Refer http://freshmeat.net/projects/fetchyahoo for that program.
#
# Copyright: Feel free to do whatever with this script. Improvements are welcome!


use strict;
use integer;

use HTTP::Request::Common;   
use HTTP::Cookies ();
use LWP::UserAgent ();
use MIME::Head ();
sub GetRedirectUrl($);
sub Logout();
sub get_page();
sub interactive($);
sub GetProps($);
sub print_message($);
sub delete_message($);

my $version = "1.1.0";
my $username = 'username' ;
my $password = "password";
my $outlookloginURL = '';
my $outlookURL = $outlookloginURL;   # two vars in case of daemon mode

my $sleep_time = 450;  # sleep time in seconds if in daemon mode
my $daemon_mode = 0;
my $interactive_mode = 0;
my $debug = 0;    # debug mode prints some messages to the screen if not in daemon mode
my $useReadKey = 1;   # use Term::ReadKey to read the password without echoing it to the screen

my $userAgent = "Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.1.11) Gecko/20071127 Firefox/2.0.0.11";
my $sound_player = '/usr/bin/play';
my $sound_file = '/usr/share/sounds/KDE_Beep_ClockChime.wav' ;
my $has_sound = 1;


# parse arguments
foreach ( @ARGV ) {
    if (( $_ eq "-d" ) || ( $_ eq "--daemon" )) {
        $daemon_mode = 1;
    }
    elsif ( $_ eq "--debug" ) {
        $debug = 1; 
    }
    elsif (( $_ eq "-i" ) || ( $_ eq "--interactive" )) {
        $interactive_mode = 1; 
    }
    elsif (( $_ eq "-v" ) || ( $_ eq "--version" )) {
        print "CheckOutlook $version by Ziad van Beek.\n";
        print "Browser = $userAgent\n";
        exit;
    }
    else {
        die( "Unknown argument $_\n" );
    }
}   
   

# unbuffer STDOUT
select( STDOUT ); 
$| = 1;

if ( -f $sound_player ) { # sound player exists
    if ( -f $sound_file ) { # the sound file exists
        my $has_sound = 1;
    }
    else {
        print "Can't find your sound file $sound_file as defined in \$sound_file.\nThere will be no sound alerts!"; 
        $has_sound = 0;
    }
}
else {
    print "Can't find your sound player $sound_player as defined in \$sound_player.\nThere will be no sound alerts" ;
    $has_sound = 0;
}

$SIG{QUIT} = "sig_handler";
$SIG{TERM} = "sig_handler";
$SIG{KILL} = "sig_handler";
$SIG{INT} = "sig_handler";
$SIG{HUP} = "sig_handler";
$SIG{ALRM} = "sig_handler";

if ( $username eq "" )  {
    print "\nPlease enter your Outlook username: ";
    $username = <STDIN> ;
    chomp( $username );
    $password = "";
}

if ( $password eq "" ) {
    # check for Term::ReadKey
    eval( "use Term::ReadKey" );
    if ( $@ ) {  # something went wrong with eval
        print "Term::ReadKey not installed. Your password will now appear\n" 
            . "on the screen as you type it...\n";
        $useReadKey = 1; 
    }
    else { 
        $useReadKey = 1; 
    }

    print "Please enter your Outlook password: ";
    if ( $useReadKey == 1 ) {
        ReadMode('noecho');          #hide output
        $password = ReadLine(0);     #get input
        ReadMode('normal');          #back to normal mode
    }
    else { # read with echo
        $password = <STDIN>; 
    }
    chomp( $password );
    print "\n";
}

print "Logging in on $outlookURL as $username\n";

# if daemon mode is chosen, fork into the background
if ( $daemon_mode > 0 ) {
    print "Forking into the background.... Checking mail every $sleep_time seconds\n" ;
    my $pid = fork();
    if( $pid ) {
        exit();
    }
    if ( !defined( $pid )) {
        die "Couldn't fork into background: $!";
    }
}



my $ua = LWP::UserAgent->new;
my $cookie_jar = HTTP::Cookies->new();  # empty, temp cookie jar
my $url = "";
my $request;
my $content;



do {
    my %PROPS;
    my $i;
    my $main_page;
    my @main_page = ();
    my $logoutURL;
    my $found = 0;
    
    my $outlookURL = $outlookloginURL;   # reset in case of daemon mode

    if ( $debug == 1 ) {
        print "outlookURL = $outlookURL\n" ;
    }
    # grab login cookies
    
    $ua->cookie_jar($cookie_jar);
    $ua->agent($userAgent);
    $request = GET $outlookURL ;
    $main_page = $ua->request($request);
    if ($main_page->is_error) {
        print "Failed to fetch login page: ", $request->uri, ": ", $main_page->status_line, "\n" ;
    }
    elsif (( $main_page->is_redirect ) || ( $main_page->content =~ /getlogon/i )) { # we are being redirected
        @main_page = split(/\n/, $main_page->content);
        foreach ( @main_page ) {
            if ( /getlogon/i ) {  # this is the path to the logon page
                s/.*src=\"?\/([[:graph:]]+)[[:space:]].*/$1/i;
                s/\"//g;  # get rid of "'s
                $outlookURL =~ s/([^\/]*\/\/[^\/]*).*$/$1\/$_/;
                $request = GET $outlookURL ; # go fetch again with the new URL
                $main_page = $ua->request( $request );
            }
        }
    }

    if ( $debug == 1 ) {
        print "outlookURL = $outlookURL\n" ;
    }
    @main_page = split( /\n/, $main_page->content );

    %PROPS = &GetProps( @main_page );
    $PROPS{'username'} = $username;
    $PROPS{'password'} = $password;
    
    # now, fetch the logon path, and remove it from the PROPS array
    my @PROPS = %PROPS;
    $found = 0;
    $i = 0;
    my $len = @PROPS;
    while ( $i < $len ) {
        if ( $PROPS[$i] eq "logon_path" ) {  
            $outlookURL =~ s/Cook.*/$PROPS[$i+1]/i ;
            splice( @PROPS, $i, 2 );# delete this key and the value   
            $found = 1;
            last;  # no need to look further;
        }
        $i++;
    }
    if ( $found == 0 ) {
        die( "no logon redirect found\n" );
    }
    %PROPS = @PROPS;    
    @PROPS= (); 
    
    if ( $debug == 1 ) { 
        print "outlookURL = $outlookURL\n";
    }
    
    
    $request = POST( $outlookURL, [ %PROPS ] );
    $request->content_type('application/x-www-form-urlencoded');
    $request->header('Accept' => '*/*');
    $request->header('Allowed' => 'GET HEAD PUT');
    $content = &get_page( $request );
    
    if ( $content =~ /You could not be logged/i ) {
        die ("Failed: Wrong username/password combination entered for $username\n"); 
    }
    

    my @base = split(/\n/, $content );
    foreach $_ (@base) {
        if (/BASE/i ) {
            s/.*<BASE href=\"(.*)\">.*/$1/i;
            $outlookURL = $_;
        }
        if ( /viewer/i ) {
            s/.*src=\"(.*)\" .*/$1/i;
            $outlookURL =  $outlookURL . $_;
        }
    }
   
    if ( $debug == 1 ) { 
        print "outlookURL = $outlookURL\n";
    }
    
    
    $request = GET $outlookURL;
    $request->content_type('application/x-www-form-urlencoded');
    $request->header('Accept' => '*/*');
    $request->header('Allowed' => 'GET HEAD PUT');
    $content = &get_page( $request );
    
    # we are now on the main page
    $logoutURL = $outlookURL;
    $logoutURL =~ s/\/[^\/]*(\/\?Cmd=).*/$1logoff/;


    my @table = split( /<\/[tT][dD]>/, $content );
    $i=0;
    $found = 0;
    $len = @table;
    for( $i=0; $i < $len; $i++ ) { 
        if ( $table[ $i ] =~ /class.*list/i ) {
            if ( $table[ $i ] =~ /icon-msg-unread\.gif/i ) {
                if ( $found == 0 ) {
                    $found = 1;
                    print( "\nNew mail on $outlookloginURL:\n");
                }
                if ( $has_sound == 1 ) {
                    `$sound_player $sound_file >& /dev/null`;
                }
                $table[ $i ]   =~ s/.*href=\"?([^\"]+)\"?.*/$1/i ;
                my $messageURL = $outlookURL ;
                $messageURL =~ s/[^\/]+\/[^\/]+$/$table[$i]/;
                $table[ $i+3 ] =~ s/.*<[bB]>(.*)<\/[bB]>.*/$1/;
                $table[ $i+4 ] =~ s/.*<[bB]>(.*)<\/[bB]>.*/$1/;
                printf( "--> %-30.30s    %-40.40s\n", $table[ $i+3 ], $table[ $i+4 ]);
                if ( $interactive_mode == 1 ) {
                    &interactive( $messageURL );
                }
            }
        }
    }

    &logout( $logoutURL );

    if ( $daemon_mode ) {
        if ( $found == 1 ) {
            sleep( $sleep_time * 3 ); # don't check again right away
        }
        else {
            sleep( $sleep_time ); 
        }
    }

    
} while ( $daemon_mode == 1); # end main while loop





# return the URL we're redirected to
sub GetRedirectUrl( $ ) {
    my $response = $_[0];
    my $url = $response->header('Location');

    if ($url =  $response->header('Location')) {
        # the Location URL is sometimes non-absolute which is not allowed, fix it
        local $URI::ABS_ALLOW_RELATIVE_SCHEME = 1;
        my $base = $response->base;
        $url = $HTTP::URI_CLASS->new($url, $base)->abs($base);
    } 
    elsif ($response->content =~
           /^<html>\s*<head>\s*<script language=\"/ &&
           #$response->content =~ /<\/html>\s*$/ &&
           $response->content =~
           /<meta http-equiv="Refresh" content="0; url=(http:\/\/.*?)">/) {
        $url = $1;
    }
    else {
        return undef;
    }

    return $url;
}




sub get_page() {
    my $request = $_[0];
    my $response;
    my $content="";

    $response = $ua->simple_request($request);
    while ( $response->is_redirect || ( $response->content =~ /<script language=\"/ )) { 
        $cookie_jar->extract_cookies( $response );
        $url = GetRedirectUrl($response);
        if ( !$url || !defined ( $url )) { 
            next; 
        }
        $request = GET $url;
        $response = $ua->simple_request($request);
    }

    $content =  $response->content;

    if ( $response->is_success ) { 
        return $content; 
    }
    else {
        return "FAILED";
    }
} 


sub logout() {
    my $logoutURL = $_[0];
    if ( $debug == 1 ) {
        print "Logging off using $logoutURL ...";
    }
    elsif ( $daemon_mode == 0 ) {
        print "Logging off ...";
    }
    $request = GET  $logoutURL ;
    $content = &get_page( $request );
    if( $content =~ /you have been logged off/i ) {
        if(( $daemon_mode == 0 ) || ( $debug == 1 )) {
            print " done.\n" ;
        }
    }
    else {
        print "Error logging out.\n" ;
    }
}


sub sig_handler() {
    my $signal = $_[0];
    die ("Received $signal. Quitting ...\n" );
}


sub interactive( $ )
{
    my $messageURL = $_[0];
    my $request;
    my $content;
     

    print ("   Retrieve? " );
    $_ = <STDIN>;
    if ( /(y|yes)/i ) {
        &print_message( $messageURL );
    }

    print ("   Delete? " );
    $_ = <STDIN>;
    if ( /(y|yes)/i ) {
        &delete_message( $messageURL );
    }
}


sub GetProps($)
{
    my @main_page = @_;
    my $i;
    my %PROPS;
    my @PROP_NAME;
    my @PROP_VALUE;

    foreach (@main_page) {
        if ( /^.*<input type=\"?(hidden|text|password|Submit)\"? ([^>]*>).*$/i ) {
            my @TAG = split(/(>|\"[[:space:]])/, $2);
            # print "\nTAG= ", @TAG, "\n";
            for ($i = 0; $i <= $#TAG; $i++) {
                $TAG[$i] =~ s/\"//g;
                my @PROP = split("=", $TAG[$i]);
                if ($PROP[0] eq "name") {
                    push ( @PROP_NAME, $PROP[1] );
                }
                elsif ($PROP[0] eq "value") {
                    push ( @PROP_VALUE, $PROP[1] );
                }
            }
            if ( $#PROP_NAME >  $#PROP_VALUE ) {  # empty value
                push ( @PROP_VALUE, "" );
            }
        }
        elsif ( /FORM action=\"[[:graph:]]+\"[[:space:]]method=\"POST\".+name=\"logonForm\">/i ) {  # the logon URL
            s/.*FORM action=\"\/([[:graph:]]+)\"[[:space:]]method=\"POST\".+name=\"logonForm\".*/$1/i ;   # the logon URL
            push( @PROP_NAME, "logon_path" );
            push( @PROP_VALUE, $_ );
        }
    
    }
    
    
    
    for ($i = 0; $i <= $#PROP_NAME; $i++) {
        $PROPS{$PROP_NAME[$i]} = $PROP_VALUE[$i];
        # print "prop: $PROP_NAME[$i] = $PROPS{$PROP_NAME[$i]}\n";
    }
    

    return( %PROPS );
}

sub print_message($)
{
    my $messageURL = $_[0];
    my $content;
    my $request;

    $request = GET $messageURL;
    $request->content_type('application/x-www-form-urlencoded');
    $request->header('Accept' => '*/*');
    $request->header('Allowed' => 'GET HEAD PUT');
    $content = &get_page( $request );
    $content =~ s/<[^>]+>//g ; # get rid of all tags
    $content =~ s/\&nbsp;//g ; # get rid of some more tags
    print "$content\n";

}


sub delete_message($) 
{
    my $messageURL = $_[0];
    my $content;
    my $request;

    $request = GET $messageURL;
    $request->content_type('application/x-www-form-urlencoded');
    $request->header('Accept' => '*/*');
    $request->header('Allowed' => 'GET HEAD PUT');
    $content = &get_page( $request );
    my @content = split( /\n/, $content );
    my %PROPS = &GetProps( @content );

    if( exists($PROPS{'Cmd'}) ) {
        $PROPS{'Cmd'} = "delete";
    }
    else {
        print STDERR "PROP \'Cmd\' not defined!\n";
    }

    if( $debug == 1 ) {
        my $key;
        print "\n" ;
        foreach  $key ( keys(%PROPS)) {
            print $key . " = " . $PROPS{$key} . "\n";
        }
    }

    # now delete the message
    $messageURL =~ s/\?cmd=open.*//i;
    $request = POST($messageURL, [%PROPS])  ;
    $request->content_type('application/x-www-form-urlencoded');
    $request->header('Accept' => '*/*');
    $request->header('Allowed' => 'GET HEAD PUT');
    $content = &get_page( $request );


}

