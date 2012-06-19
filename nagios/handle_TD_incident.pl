#!/usr/bin/perl

# Purpose and features of the program:
#
# - Submitting incidents (trouble tickets) to TOPdesk
#
# - Placing an acknowledge together with a comment containing the indicent number and a 
#   hyperlink to the incident ticket in Nagios. Further notification from nagios will
#   be suppressed
#
# - Can handle more than one TOPdesk server
#
# - Can close/complete incidents
#   - Based on a timeframe
#   - Everytime
#   - Exeption: The file with the timestamp and the TOPdesk UNID has been deleted
#     (see below)
#   - Decision for close/complete is based on the TOPdesk Server
#
# - Default mappings for duration (Severity)
#   - Host:
#     DOWN        = Severity 1
#     UNREACHABLE = Severity 3
#   - Service:
#     CRITICAL = Severity 1
#     WARNING  = Severity 2
#     UNKNOWN  = Severity 3
#
# - Mappings can be overritten with -t
#   - Form:
#     "CRITICAL=1 WARNING=3 down=2"
#   - Lowercase letters will be automatically converted into uppercase ones because Nagios is 
#     delivering uppercase ones.
#   - Everything can be replaced from one mapping (for example CRITICAL) to all mappings
#
#
# History and Changes:
# 
#
# - 28 Feb 2009 Version 1.1
#   - New commandline switch -o or --typeofcall
#     With this switch the default behavior of "Type of Call". Default is Incident.
#     Every type available through the type of call pulldown menu from Topdesk is valid here.
#   - Timestamp in the Request and Action field. Conversion is based on the Perl sprintf
#     function. See "Make the topdesk time stamp" below and change it to your needs
#   - Caller ($TD_USER) handled over the the Request and Action field. So now you will see
#     who has placed the line  in your Topdesk
#   - Some codeblocks moved for better reading
#
#
# How it works:
# 
# Read the code. There is plenty of comment in it.
#
#
# Setup:
# In this script you only have to setup some variables and hashes to fit your requirements.
# 
# $TMP_DIR="/tmp";                           # Directory to store the UNID and the timestamp temporarily
# $NAG_PIPE="/var/spool/nagios/nagios.cmd";  # The nagios command pipe
# $TD_CREATE = 'test\@example.com';     # The caller field - should contain a valid email address
# $TD_STATUS="2";                            # 1 indicates a first line incident, 2 indicates
# 
# Place your login account(s) here:
# %TD_USERNAME = (
#                  "tdserver1.mycompany.com" => "Topdesk Account",	   
#                  "tdserver2.mycompany.com" => "Topdesk Account"	   
#                  ); 
#
# Place your login password(s) here:
# %TD_PASSWORD = (
#                  "tdserver1.mycompany.com" => "place your password here",	   
#                  "tdserver2.mycompany.com" => "place your password here"	   
#                  ); 
#
# Place your caller field(s) here:
# %TD_USER = (
#              "tdserver1.mycompany.com" => "TD, Monitoring",	   
#              "tdserver2.mycompany.com" => "TD, Monitoring"	   
#              ); 
#
# Place your recovery behaviour here:
# %TD_RECOVER = (
#                 "tdserver1.mycompany.com" => "CLOSE",	   
#                 "tdserver2.mycompany.com" => "COMPLETE"	   
#                 ); 
#
# Place here a contact defined in Nagios. This contact is needed for
# acknowledging. It is the contact which will place the comment with 
# the hyperlink to your Topdesk ticket in Nagios:
# %NAG_CONTACT = (
#                 "tdserver1.mycompany.com" => "topdesk",	   
#                 "tdserver2.mycompany.com" => "topdesk_test"	   
#                 ); 
#
#
# In Nagios you have to 
#
# - define one or more notification commands
# - I am not going deep on this one because if you can't make
# - command definitions then you should not be playing with this.
#
#   # 'notify-by-topdesk-test' command definition
#   define command{
#   command_name    notify-by-topdesk-test
#   command_line    handle_TD_incident -U http://tdserver1.mycompany.com -N $NOTIFICATIONTYPE$ -H $HOSTNAME$ -S "$SERVICEDESC$" -C 'Monitoring Tools' -c 'Nagios, Cacti, ...' -s $SERVICESTATE$ -M "$SERVICEOUTPUT$"
#   }
#
# - add a contact for the host/service for TOPDesk
#   define contact{
#           contact_name                        topdesk_test
#           alias                               topdesk_test
#           service_notification_period         24x7
#           host_notification_period            24x7
#           service_notification_options        c,w,u,r
#           host_notification_options           d,u,r
#           service_notification_commands       notify-by-topdesk-test
#           host_notification_commands          host-notify-by-topdesk-test
#           email                               dummy or address from the caller field
#           }

# - add the contact to the appopriate contactgroup for notification
# 
# Synopsis:
# 
# handle_TD_incident -U|--url <TOPdesk base URL> -H|--host <host> -S|--service <service> -N|--notificationtype <Nagios notificationtype> -M|--message <message> -o|--typeofcall <Incident,Security,Alert...> -C|--category <category> -c|--subcategory <subcategory> -s|--state <Nagios state> -o|--typeofcall <Incident or Security...> -T|--time <Time in Minutes> -r|--ready -t|--severity <\"CRITICAL=2 WARNING=3 ...\">
#
#----------------------------------------------------------------------

# For a better understanding:
# All variables belonging to Nagios are starting with NAG_
# All variables belonging to TOPdesk are starting with TD_

use strict;

use Getopt::Long;
use LWP::Simple;
use Time::localtime;
use Date::Calc qw(:all);

#--- Start presets and declarations -------------------------------------

my $PROGNAME="handle_TD_incident";            # Name of program

my $TIMESTAMP=time();                         # Sets the Timestamp
                                              # - for acknowledge in Nagios
                                              # - for to be stored in the tempory file which contains 
                                              #   the timestamp of ack and the unid for the incident

my $TD_TIMESTAMP;                             # Sets the timestamps for the actions in TOPdesk.
                                              # Otherwise you will not know when a message/action
                                              # took place.

my $TD_TIMESTAMP;                             # Sets the timestamps for the actions in TOPdesk.
                                              # Otherwise you will not know when a message/action
                                              # took place.

my $TIME_DIFF="";                             # Difference between actual timestamp and stored timestamp
my $READY="";                                 # Always complete or close an incident
my $HELP="";                                  # For printing the help message

                                              
my $MAX_AGE="";                               # Max. age in minutes for automatic completion or closing
                                              # or closing of a ticket. If a sercvice or host down recovers
                                              # this value handled over by commandline. Than the stored timestamp 
                                              # will be compared with the actual timestamp. The result will be compared 
                                              # with $MAX_AGE. If it is smaller or equal $MAX_AGE a comment will be placed
                                              # into the ticket and the ticket will be closed/completed. The tempfile will
                                              # be removed. Otherwise only the comment will be placed into the ticket
                                              # and the tempfile will be removed.

my $URL="";                                   # Here we store the contructed URL to get
my $TMP_DIR="/tmp";                           # Directory to store the UNID and the timestamp temporarily
my $TMP_FILE_CONTENT="";                      # As it says

my $NOA="";                                   # Number of arguments handled over
                                              # the program

my $NAG_PIPE="/var/spool/nagios/nagios.cmd";  # The nagios command pipe

my $NAG_HOST="";                              # The host causing the alert
my $NAG_SERVICE="";                           # The service causing the alert
my $NAG_MESSAGE="";                           # Message submitted from Nagios
my $NAG_STATE="";                             # The state Nagios delivers

my $NAG_NOTIFICATIONTYPE="";                  # Nagios notification type. Can be:
                                              #
                                              # - PROBLEM (used)
                                              # - RECOVERY (used)
                                              # - ACKNOWLEDGEMENT (used)
                                              # - FLAPPINGSTART (unused)
                                              # - FLAPPINGSTOP (unused)
                                              # - FLAPPINGDISABLED (unused)
                                              # - DOWNTIMESTART (unused)
                                              # - DOWNTIMEEND (unused)
                                              # - DOWNTIMECANCELLED (unused)

my $NAG_CONTACT="";                           # - Nagios Contact for TOPdesk. Will be filled later on
                                              #   automatically in an array of the same name

my $TD_INPUT = 'Web Interface';               # Way of creating the entry in TOPdesk
my $TD_INPUT_TYPE = "";                       # Type of call in TOPdesk
my $TD_CREATE = 'a.broekhof\@stationtostation.nl';     # The caller field

my $NAG_TD_SEV_MAPPING="";                    # Contains an alternative mapping in the form
                                              # "CRITICAL=1 WARNING=3" etc.
                                              # Lowercase letters will be converted to uppercase ones
                                              # You have only to add mappings, which should be 
                                              # different from standard mapping
                                              # Mapping should be handled over as a string so don't
                                              # omit the quotes
                                              
my %NAG_TD_SEV_MAPPING;                       # $NAG_TD_SEV_MAPPING will be convert in a hash. Her
                                              # is it.

my @NAG_TD_SEV_MAPPING;                       # Used in conversion
my $NAG_TD_SEV_MAPPING_KEY="";                # Used in conversion too
my $NAG_TD_SEV_MAPPING_VALUE="";              # Used in conversion too

my $TD_OBJECT='unknown';                      # Quite clear
my $TD_GROUP='';                              # Unused at present
my $TD_NOTICE='';                             # Unused at present
my $TD_PROTOCOL="";                           # http or https - delivered within $TD_URL
my $TD_USERNAME="";                           # Login-Name TopDeskServer
my $TD_PASSWORD="";                           # Password for Login-Name
my $TD_USER="";                               # Shown user - must fit $TD_USERNAME
my $TD_UNID="";                               # Unified identifier - identifies the card
                                              # in Topdesk

my $TD_RECOVER="";                            # Contain the string "close" or "complete" The decision to
                                              # complete or close a ticket is based on the policy used
                                              # on the given server annd therfore it depends on
                                              # the server name.
                                              
my $TD_SEVERITY="";                           # Must contain the string 'Severity 1',
                                              # 'Severity 2','Severity 3' or 'Severity 4'
                                              # Due to the fact the Nagios only nows critical/down,
                                              # warning, unknown/unreachable
                                              # the use of all 4 is very limited.

my $TD_STATUS="2";                            # 1 indicates a first line incident, 2 indicates
                                              # a second line incident.

my $TD_MESSAGE="";                            # Message submitted to Topdesk
my $TD_RESULT="";                             # Result Page from TOPdesk
my $TD_CATEGORY="";                           # Category handled over from nagios
my $TD_SUBCATEGORY="";                        # Subcategory handled over from nagios
my $TD_INCIDENT_ID="";                        # The incident number get back from TOPdesk
my $TD_URL="";                                # TOPdesk server in the form http://servername or https://servername

#--- End presets --------------------------------------------------------


# First we have to fix  the number of arguments

$NOA=$#ARGV;

Getopt::Long::Configure('bundling');
GetOptions
	("h"   => \$HELP,                 "help"               => \$HELP,
	 "r"   => \$READY,                "ready"              => \$READY,
	 "U=s" => \$TD_URL,               "url=s"              => \$TD_URL,
	 "o=s" => \$TD_INPUT_TYPE,        "typeofcall=s"       => \$TD_INPUT_TYPE,
	 "t=s" => \$NAG_TD_SEV_MAPPING,   "severiymapping=s"   => \$NAG_TD_SEV_MAPPING,
	 "C=s" => \$TD_CATEGORY,          "category=s"         => \$TD_CATEGORY,
	 "c=s" => \$TD_SUBCATEGORY,       "subcategory=s"      => \$TD_SUBCATEGORY,
	 "H=s" => \$NAG_HOST,             "host=s"             => \$NAG_HOST,
	 "S=s" => \$NAG_SERVICE,          "service=s"          => \$NAG_SERVICE,
	 "N=s" => \$NAG_NOTIFICATIONTYPE, "notificationtype=s" => \$NAG_NOTIFICATIONTYPE,
	 "M=s" => \$NAG_MESSAGE,          "message=s"          => \$NAG_MESSAGE,
	 "T=s" => \$MAX_AGE,              "time=s"             => \$MAX_AGE,
	 "s=s" => \$NAG_STATE,            "state=s"            => \$NAG_STATE);

# First of all test if it a call give by Nagios problem acknowledge 
# If yes get out of here

if ($NAG_NOTIFICATIONTYPE eq "ACKNOWLEDGEMENT" )
   {
   exit 0;
   }


# Make the topdesk time stamp

(my $YEAR,my $MONTH,my $DAY, my $HOUR,my $MINUTE,my $SEC) = Time_to_Date($TIMESTAMP);

$TD_TIMESTAMP = sprintf("%02d %.3s %s %02d:%02d",$DAY,Month_to_Text($MONTH),$YEAR,$HOUR,$MINUTE);


# So now we check the neccessary arguments given to the script

if ($HELP)
   {
   print_help();
   exit 0;
   }

if ( $NOA == -1 )
   {
   print_usage();
   exit 1;
   }

if (!$TD_URL)
   {
   print "No URL for TOPDesk server given!\n\n";
   print_help();
   exit 1;
   }

if (!$TD_INPUT_TYPE)
   {
   $TD_INPUT_TYPE="Incident";
   }

if (!$TD_CATEGORY)
   {
   print "No category for TOPDesk server given!\n\n";
   print_help();
   exit 1;
   }

if (!$TD_SUBCATEGORY)
   {
   print "No sub category for TOPDesk server given!\n\n";
   print_help();
   exit 1;
   }

if (!$NAG_HOST)
   {
   print "No host from Nagios server given!\n\n";
   print_help();
   exit 1;
   }

if (!$NAG_STATE)
   {
   print "No state from Nagios given!\n\n";
   print_help();
   exit 1;
   }

if (!$NAG_SERVICE)
   {
   if ($NAG_STATE eq 'CRITICAL' || $NAG_STATE eq 'WARNING' || $NAG_STATE eq 'UNKNOWN')
      {
      print "No service from Nagios server given!\n\n";
      print_help();
      exit 1;
      }
   }

if (!$NAG_MESSAGE)
   {
   print "No message from Nagios given!\n\n";
   print_help();
   exit 1;
   }

if ($MAX_AGE)
   {
   # Make seconds from the minutes
   $MAX_AGE = $MAX_AGE * 60;
   }


# Well, well well ... here we set up the array with alternative mappings
# for the severity code. We use it later

if ($NAG_TD_SEV_MAPPING)
   {
   $NAG_TD_SEV_MAPPING = uc($NAG_TD_SEV_MAPPING);
   $NAG_TD_SEV_MAPPING =~ s/=/ /isog;
   $NAG_TD_SEV_MAPPING =~ s/\s+/ /isog;
   @NAG_TD_SEV_MAPPING = split(/ /, $NAG_TD_SEV_MAPPING);
   
   while(@NAG_TD_SEV_MAPPING)
        {

        $NAG_TD_SEV_MAPPING_KEY = shift(@NAG_TD_SEV_MAPPING);
        $NAG_TD_SEV_MAPPING_VALUE = shift(@NAG_TD_SEV_MAPPING);
        
        $NAG_TD_SEV_MAPPING{$NAG_TD_SEV_MAPPING_KEY} = $NAG_TD_SEV_MAPPING_VALUE;

        }
   
   }


# Now we map states from Nagios. If an alternative mapping is in the hash
# it will be used
# 
# Default mappings Host:
#
# DOWN        = Severity 1
# UNREACHABLE = Severity 3
#
# Default mappings Service:
#
# CRITICAL = Severity 1
# WARNING  = Severity 2
# UNKNOWN  = Severity 3


if ($NAG_STATE eq 'CRITICAL' )
   {
   if ($NAG_TD_SEV_MAPPING{$NAG_STATE})
      {
      $TD_SEVERITY="Severity ".$NAG_TD_SEV_MAPPING{$NAG_STATE};
      }
   else
      {
      $TD_SEVERITY="Severity 1";
      }
   }

if ($NAG_STATE eq 'DOWN')
   {
   if ($NAG_TD_SEV_MAPPING{$NAG_STATE})
      {
      $TD_SEVERITY="Severity ".$NAG_TD_SEV_MAPPING{$NAG_STATE};
      }
   else
      {
      $TD_SEVERITY="Severity 1";
      }
   }

if ($NAG_STATE eq 'WARNING')
   {
   if ($NAG_TD_SEV_MAPPING{$NAG_STATE})
      {
      $TD_SEVERITY="Severity ".$NAG_TD_SEV_MAPPING{$NAG_STATE};
      }
   else
      {
      $TD_SEVERITY="Severity 2";
      }
   }

if ($NAG_STATE eq 'UNREACHABLE')
   {
   if ($NAG_TD_SEV_MAPPING{$NAG_STATE})
      {
      $TD_SEVERITY="Severity ".$NAG_TD_SEV_MAPPING{$NAG_STATE};
      }
   else
      {
      $TD_SEVERITY="Severity 3";
      }
   }
   
if ($NAG_STATE eq 'UNKNOWN')
   {
   if ($NAG_TD_SEV_MAPPING{$NAG_STATE})
      {
      $TD_SEVERITY="Severity ".$NAG_TD_SEV_MAPPING{$NAG_STATE};
      }
   else
      {
      $TD_SEVERITY="Severity 3";
      }
   }


# So now we seperate the protocol and server name - we need it seperated for the following arrays

$TD_URL=~s/\/\///isog;
my @URL_BASE=split(/:/, $TD_URL);

$TD_PROTOCOL=$URL_BASE[0];
$TD_URL=$URL_BASE[1];


#The following hashes will add the appropriate user, password etc. to the given servers.

my %TD_USERNAME = (
                  "tdserver1.mycompany.com" => "Topdesk Account",	   
                  "tdserver2.mycompany.com" => "Topdesk Account"	   
                  ); 

my %TD_PASSWORD = (
                  "tdserver1.mycompany.com" => "place your password here",	   
                  "tdserver2.mycompany.com" => "place your password here"	   
                  ); 

my %TD_USER = (
              "tdserver1.mycompany.com" => "TD, Monitoring",	   
              "tdserver2.mycompany.com" => "TD, Monitoring"	   
              ); 

my %TD_RECOVER = (
                 "tdserver1.mycompany.com" => "CLOSE",	   
                 "tdserver2.mycompany.com" => "COMPLETE"	   
                 ); 

my %NAG_CONTACT = (
                  "tdserver1.mycompany.com" => "topdesk",	   
                  "tdserver2.mycompany.com" => "topdesk_test"	   
                  ); 

# Now we fill the variables with the values from the hashes because it is easier to handle 
# variables instead of hashes or arrays

$TD_USERNAME=$TD_USERNAME{$TD_URL};
$TD_USER=$TD_USER{$TD_URL};
$TD_PASSWORD=$TD_PASSWORD{$TD_URL};
$NAG_CONTACT=$NAG_CONTACT{$TD_URL};
$TD_RECOVER=$TD_RECOVER{$TD_URL};


# Now we have to set up the right message to handle over to Topdesk

if ($NAG_STATE eq 'DOWN' || $NAG_STATE eq 'UNREACHABLE')
   {
   $TD_MESSAGE="$TD_TIMESTAMP  $TD_USER:  Host $NAG_HOST reports to be $NAG_STATE. - Message: $NAG_MESSAGE";
   }

if ($NAG_STATE eq 'CRITICAL' || $NAG_STATE eq 'WARNING' || $NAG_STATE eq 'UNKNOWN')
   {
   $TD_MESSAGE="$TD_TIMESTAMP  $TD_USER:  Host $NAG_HOST - Service $NAG_SERVICE reports to be $NAG_STATE. - Message: $NAG_MESSAGE";
   }

# Now enough of the skirmish - let's get real
#--- Begin main -------------------------------------------------------------


# OK or UP means that we have a recovery. Therefore we have to get the 
# previously saved UNID together with the timestamp of saving.


if ($NAG_STATE eq 'OK' || $NAG_STATE eq 'UP' )
   {

   # Well lets do the recovery work
   
   $TMP_FILE_CONTENT=get_unid_tmp_file();
   
   # If NOF (NO File) is returned we have no tempfile. There we have no
   # timestamp and no UNID. Opposite to politicians we can do nothing
   # if we have no information
   
   if ( $TMP_FILE_CONTENT eq "NOF" )
      {
      exit 0;
      }

   # Always complete or close the incident

   if ( $READY )
      {

      # The y in modify_incident("y") means close or complete
      
      modify_incident("y");
      exit 0;
      }
      
   # Well now we at the point where we have a maximum age of an incident
   # where we have a stored file with the incicent time and the UNID
   # and where we are sure that we won't close the incident anyway.
   
   # Now we get back timestamp and UNID from the stored data
   
   $TIME_DIFF=$TMP_FILE_CONTENT;
   $TIME_DIFF =~ s/\s.*$//;

   $TD_UNID=$TMP_FILE_CONTENT;
   $TD_UNID =~ s/^[0-9]*\s//;
   
   # Nesseary due to the fact that $TD_UNID is the last element of a line from a file 
   # and therefore it contains a linefeed
   
   chomp($TD_UNID);
   
   $TIME_DIFF = $TIMESTAMP - $TIME_DIFF;

   # No maximum age set therefor we only add a comment within the incident
   

   if ( !$MAX_AGE )
      {
      modify_incident("n");
      exit 0;
      }
      
   # So now if MAX_AGE handled over via commandline is less or equal $TIME_DIFF
   # we can close or complete the ticket
   # Otherwise we will only add a comment

   if ( $MAX_AGE <= $TIME_DIFF )
      {
      modify_incident("n");
      }
   else
      {
      modify_incident("y");
      }
   exit 0;
   }
else
   {

   # Well now we will generate work for someone at the end of the food chain

   $TD_RESULT=create_incident();

   $TD_INCIDENT_ID=get_incident_id($TD_RESULT);
   $TD_UNID=get_unid($TD_RESULT);

   store_unid();

   set_acknowledge();

   exit;
   }

#--- End main ---------------------------------------------------------------

#--- Begin subroutines ------------------------------------------------------

sub create_incident
    {
    
    my $RESULT="";
	
    if (!$TD_URL)
       {
       die "Error: No hostname given.\n";
       }
		
    $URL = "$TD_PROTOCOL://$TD_URL/tas/secure/incident?action=new";
	
    if ($TD_STATUS)
       {
       $URL = "$URL&status=$TD_STATUS";
       }
    else
       {
       die "Error: No STATUS-information given.\n";
       }
	
    if ($TD_MESSAGE)
       {
       $URL = "$URL&field0=verzoek&value0=$TD_MESSAGE";
       }
    else
       {
       die "Error: No text given!\n";
       }
	
    if ($TD_USER)
       {
       $URL = "$URL&replacefield0=persoonid&searchfield0=ref_dynanaam&searchvalue0=$TD_USER";
       }
    else
       {
       die "Error: Not enough user information provided.\n";
       }
	
    if ($TD_CATEGORY)
       {
       $URL = "$URL&replacefield1=incident_domeinid&searchfield1=naam&searchvalue1=$TD_CATEGORY";
       } 
    else
       {
       die "Error: No category specified!\n";
       }
	
    if ($TD_SUBCATEGORY)
       {
       $URL = "$URL&replacefield2=incident_specid&searchfield2=naam&searchvalue2=$TD_SUBCATEGORY";
       }
    else
       {
       die "Error: No subcategory specified!\n";
       }
	
    if ($TD_USERNAME && $TD_PASSWORD)
       {
       $URL = "$URL&j_username=$TD_USERNAME&j_password=$TD_PASSWORD";
       }
    else
       {
       die "Error: No authentication parameters given.\n";
       }
		
    if ($TD_SEVERITY)
       {
       $URL = "$URL&replacefield3=doorlooptijdid&searchfield3=naam&searchvalue3=$TD_SEVERITY";
       }
	
    if ($TD_NOTICE)
       {
       $URL = "$URL&field4=aantekeningen&value4=$TD_NOTICE";
       }
	
    if ($TD_OBJECT)
       {
       $URL = "$URL&replacefield5=configuratieobjectid&searchfield5=ref_naam&searchvalue5=$TD_OBJECT";
       }
    else
       {
       die "Error: No object parameters given.\n";
       }

    if ($TD_INPUT)
       {
       $URL = "$URL&replacefield6=soortbinnenkomstid&searchfield6=naam&searchvalue6=$TD_INPUT";
       }
    else
       {
       die "Error: No input parameters given.\n";
       }

    if ($TD_INPUT_TYPE)
       {
       $URL = "$URL&replacefield7=soortmeldingid&searchfield7=naam&searchvalue7=$TD_INPUT_TYPE";
       }
    else
       {
       die "Error: No input parameters given.\n";
       }

    if ($TD_CREATE)
       {
       $URL = "$URL&field8=vrijetekst1&value8=$TD_CREATE";
       }
    else
       {
       die "Error: No create parameters given.\n";
       }

    if ($TD_GROUP)
       {
       $URL = "$URL&replacefield9=actiedoorid&searchfield9=naam&searchvalue9=$TD_GROUP";
       }

       $URL = "$URL&save=true&validate=false";
       
       # Now let's get that fu...ing page

       $RESULT = LWP::Simple::get $URL;
       return $RESULT;
       
    }

sub modify_incident
    {

    my $TO_BE_CLOSED=$_[0];
    
    my $RESULT="";
	
    if (!$TD_URL)
       {
       die "Error: No hostname given.\n";
       }
		
    $URL = "$TD_PROTOCOL://$TD_URL/tas/secure/incident?action=edit";

    if (!$NAG_SERVICE)
       {
       $TD_MESSAGE="$TD_TIMESTAMP  $TD_USER:  Host $NAG_HOST - has recovered. Status $NAG_STATE. - Message from Nagios: $NAG_MESSAGE";
       }
    else
       {
       $TD_MESSAGE="$TD_TIMESTAMP  $TD_USER:  Host $NAG_HOST Service $NAG_SERVICE - has recovered. Status: $NAG_STATE. - Message from Nagios: $NAG_MESSAGE";
       }

    if ($TD_USERNAME && $TD_PASSWORD)
       {
       $URL = "$URL&j_username=$TD_USERNAME&j_password=$TD_PASSWORD";
       }
    else
       {
       die "Error: No authentication parameters given.\n";
       }
		
    if ($TD_UNID)
       {
       $URL = $URL."&unid=$TD_UNID&field0=actie&value0=$TD_MESSAGE&append0=true";
       }
    else
       {
       die "Error: No UNID given.\n";
       }

    # If the function is called with y a close or comlete will be done

    if ($TO_BE_CLOSED eq "y")
       {
       if ($TD_RECOVER)
          {
          if ($TD_RECOVER eq "COMPLETE" )
             {
             $URL = "$URL&field1=gereed&value1=1";
             }
          else
             {
             if ($TD_RECOVER eq "CLOSE" )
                {
                $URL = "$URL&field1=gereed&value1=1";
                $URL = "$URL&field2=afgemeld&value2=1";
                }
             else
                {
                die "Error: Wrong condition for completing or closing. Mission impossible.\n";
                }
             }
          }
       }
	
    $URL = "$URL&save=true&validate=false";

    # Now let's get that fu...ing page

    $RESULT = LWP::Simple::get $URL;

    return $RESULT;
       
    }

# Here we filter the incident id out of the received document

sub get_incident_id
    {
    my $INCIDENT_ID=$_[0];
    
    $INCIDENT_ID =~ s/^.*mainfieldvalue=//isog;
    $INCIDENT_ID =~ s/&.*$//isog;  
    
    return $INCIDENT_ID;
    }


# Here we get the unified identifier for each card in TOPdesk

sub get_unid
    {
    my $GET_UNID=$_[0];
    
    $GET_UNID =~ s/^.*name=\"unid\"/name=\"unid\"/isog;
    $GET_UNID =~ s/^.*?value=//isog;
    $GET_UNID =~ s/^\"//isog;
    $GET_UNID =~ s/\".*$//isog;

    return $GET_UNID;
    }


# Here we acknowledge the problem in Nagios

sub set_acknowledge
    {

    my $NAG_ACK_MSG="";

    open(NAG_CMD, ">> $NAG_PIPE");
    
    if (!$NAG_SERVICE)
       {

       $NAG_ACK_MSG="[$TIMESTAMP] ACKNOWLEDGE_HOST_PROBLEM;$NAG_HOST;1;1;1;$NAG_CONTACT;";
       $NAG_ACK_MSG=$NAG_ACK_MSG."An incident in TOPdesk was opened with id: ";
       $NAG_ACK_MSG=$NAG_ACK_MSG."<A HREF=\'$TD_PROTOCOL://$TD_URL/tas/secure/incident?action=show&unid=$TD_UNID\' target=\"_blank\">$TD_INCIDENT_ID</A>\n";
       
       print NAG_CMD "$NAG_ACK_MSG";
       }
    else
       {
       $NAG_ACK_MSG="[$TIMESTAMP] ACKNOWLEDGE_SVC_PROBLEM;$NAG_HOST;$NAG_SERVICE;1;1;1;$NAG_CONTACT;";
       $NAG_ACK_MSG=$NAG_ACK_MSG."An incident in TOPdesk was opened with id: ";
       $NAG_ACK_MSG=$NAG_ACK_MSG."<A HREF=\'$TD_PROTOCOL://$TD_URL/tas/secure/incident?action=show&unid=$TD_UNID\' target=\"_blank\">$TD_INCIDENT_ID</A>\n";
       
       print NAG_CMD "$NAG_ACK_MSG";
       }

    close(NAG_CMD);
    }


# Here we store a temporary file containing the UNID

sub store_unid
    {
    my $STORE_TMPFILE=create_tmpfile_name();
   
    open(TMP_UNID, "> $STORE_TMPFILE");
    
    print TMP_UNID "$TIMESTAMP $TD_UNID\n";

    close(TMP_UNID);
    }

sub get_unid_tmp_file
    {
    my $GET_TMPFILE=create_tmpfile_name();
    my $CONTENT;
   
    if (-e $GET_TMPFILE)
       {
       open(TMP_UNID, "< $GET_TMPFILE");

       while (<TMP_UNID>)
             {
             $CONTENT="$_";
             }

       close(TMP_UNID);
       unlink ($GET_TMPFILE);
       }
    else
       {
       $CONTENT="NOF";
       }
    return $CONTENT;
    }


sub create_tmpfile_name
    {
    my $TMPFILE_SERVICE="";
    my $TMPFILE_NAME="";
    
    # We construct the filename using TD_ as a prefix to make it easier to find the file in the temp directory.
    
    $TMPFILE_NAME = $TMP_DIR."/TD_".$NAG_HOST;

    # If it is a a service problem we filter every whitspace characters out of the service description
    # In case of a host problem we have nothing to do
    
    if ($NAG_SERVICE)
       {
       $TMPFILE_SERVICE=$NAG_SERVICE;
       $TMPFILE_SERVICE =~ s/\s//isog;

       $TMPFILE_NAME = $TMPFILE_NAME."_".$TMPFILE_SERVICE;
       }
    
    return $TMPFILE_NAME;
    
    }

sub print_usage
    {
    print "\nUsage: $PROGNAME -U|--url <TOPdesk base URL> -H|--host <host> -S|--service <service> -N|--notificationtype <Nagios notificationtype> -M|--message <message> -C|--category <category> -c|--subcategory <subcategory> -s|--state <Nagios state> -o|--typeofcall <Incident or Security...> -T|--time <Time in Minutes> -r|--ready -t|--severity <\"CRITICAL=2 WARNING=3 ...\">\n\n";
    print "or\n";
    print "\nUsage: $PROGNAME -h for help.\n\n";
    }


sub print_help
    {
    print "Copyright (c) 2009 Arno Broekhof\n";
    print_usage();
    print "       -U, --url                                     TOPdesk base URL like\n";
    print "                                                     http://topdesk.stationtostation.nl (mandatory)\n";
    print "       -H, --host                                    Host causing the incident from Nagios (mandatory)\n";
    print "       -S, --service                                 Service causing the incident from Nagios (mandatory if a service)\n";
    print "       -N, --notificationtype                        Notificationtype from from Nagios (mandatory)\n";
    print "       -M, --message                                 Message from Nagios (mandatory)\n";
    print "       -C, --category                                Main category in TOPdesk (mandatory)\n";
    print "       -c, --subcategory                             Subcategory in TOPdesk (mandatory)\n";
    print "\n";
    print "       -s, --state=state                             State from Nagios (mandatory)\n";
    print "                                                     UP = Host up - used for closing\n";
    print "                                                     an incident\n";
    print "                                                     DOWN = Host down\n";
    print "                                                     Normally mapped to severity 1\n";
    print "                                                     UNREACHABLE = Host unreachable\n";
    print "                                                     Normally mapped to severity 3\n";
    print "                                                     OK = Service ok - used for closing\n";
    print "                                                     an incident\n";
    print "                                                     WARNING = Service Warning\n";
    print "                                                     Normally mapped to severity 2\n";
    print "                                                     CRITICAL = Service critical\n";
    print "                                                     Normally mapped to severity 1\n";
    print "                                                     UNKNOWN = Service unknown\n";
    print "                                                     Normally mapped to severity 3\n";
    print "\n";
    print "       -o, --typeofcall                              Type of call (Incident,Compliance,Security or whatever\n";
    print "                                                     you see here in your Topdesk based on an incident. If\n";
    print "                                                     the default will take place. (optional).\n";
    print "\n";
    print "       -t, --severity=\"CRITICAL=2 WARNING=3 ...\"     Severity for Topdesk (1,2,3 or 4)(optional)\n";
    print "                                                     With this switch you can overrite\n";
    print "                                                     the default mapping. The alternative mapping\n";
    print "                                                     should be entered as a string in the form\n";
    print "                                                     \"CRITICAL=1 WARNING=3....\" etc.\n";
    print "                                                     Lowercase letters will be converted to uppercase ones\n";
    print "                                                     You have only to add mappings, which should be \n";
    print "                                                     different from standard mapping\n";
    print "                                                     Mapping should be handled over as a string so don't\n";
    print "                                                     omit the quotes\n";
    print "\n";
    print "       -T, --time=time in minutes                    Time in minutes for automatically complete\n";
    print "                                                     or close a ticket. (optional)\n";
    print "\n";
    print "                                                     If a ticket is not older than given timeframe it will be\n";
    print "                                                     closed or completed. The decision to complete or close a ticket\n";
    print "                                                     is based on the policy used on the given server and therfore it\n";
    print "                                                     depends on the server name.\n";
    print "\n";
    print "                                                     If a Ticket should never be closed/copleted you have 3 Methods:\n";
    print "\n";
    print "                                                     - handle over here a 0 or be sure\n";
    print "                                                     - do not to define a line for the server in \%TD_RECOVER\n";
    print "                                                       in the sourcecode.\n";
    print "                                                     - omit the switch.\n";
    print "\n";
    print "       -r, --ready                                   Always complete or close an incident (optional)\n";
    print "\n";
    print "       -h, --help                                    Short help message (mandatory)\n";
    print "\n";
    }

#--- End subroutines --------------------------------------------------------

