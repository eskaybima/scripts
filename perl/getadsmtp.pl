#!/usr/bin/perl -w

# Version 1.02
#
# Script created by Arno Broekhof

use Net::LDAP;
use Net::LDAP::Control::Paged;
use Net::LDAP::Constant ( "LDAP_CONTROL_PAGED" );

# Enter the path/file for the output
$VALID = "/etc/postfix/ad_recipients";

# Enter the FQDN of your Active Directory domain controllers below
$dc1="pdc@testing.local";
$dc2="pdc2@testing.local";

# Enter the LDAP container for your userbase.
# The syntax is CN=Users,dc=example,dc=com
# This can be found by installing the Windows 2000 Support Tools
# then running ADSI Edit.
# In ADSI Edit, expand the "Domain NC [domaincontroller1.example.com]" &
# you will see, for example, DC=example,DC=com (this is your base).
# The Users Container will be specified in the right pane as
# CN=Users depending on your schema (this is your container).
# You can double-check this by clicking "Properties" of your user
# folder in ADSI Edit and examining the "Path" value, such as:
# LDAP://domaincontroller1.example.com/CN=Users,DC=example,DC=com
# which would be $hqbase="cn=Users,dc=example,dc=com"
# Note:  You can also use just $hqbase="dc=example,dc=com"
$hqbase="dc=stationtostation,dc=nl";

# Enter the username & password for a valid user in your Active Directory
# with username in the form cn=username,cn=Users,dc=example,dc=com
# Make sure the user's password does not expire.  Note that this user
# does not require any special privileges.
# You can double-check this by clicking "Properties" of your user in
# ADSI Edit and examining the "Path" value, such as:
# LDAP://domaincontroller1.example.com/CN=user,CN=Users,DC=example,DC=com
# which would be $user="cn=user,cn=Users,dc=example,dc=com"
# Note: You can also use the UPN login: "user\@example.com"
$user="cn=linux,ou=Service Accounts,dc=stationtostation,dc=nl";
$passwd="station";

# Connecting to Active Directory domain controllers
$noldapserver=0;
$ldap = Net::LDAP->new($dc1) or
   $noldapserver=1;
if ($noldapserver == 1)  {
   $ldap = Net::LDAP->new($dc2) or
      die "Error connecting to specified domain controllers $@ \n";
}

$mesg = $ldap->bind ( dn => $user,
                     password =>$passwd);
if ( $mesg->code()) {
    die ("error:", $mesg->code(),"\n","error name: ",$mesg->error_name(),
        "\n", "error text: ",$mesg->error_text(),"\n");
}

# How many LDAP query results to grab for each paged round
# Set to under 1000 for Active Directory
$page = Net::LDAP::Control::Paged->new( size => 990 );

@args = ( base     => $hqbase,
# Play around with this to grab objects such as Contacts, Public Folders, etc.
# A minimal filter for just users with email would be:
# filter => "(&(sAMAccountName=*)(mail=*))"
         filter => "(&(&(& (mailnickname=*) (| (&(objectCategory=person)(objectClass=user)(!(homeMDB=*))(!(msExchHomeServerName=*)))(&(objectCategory=person)(objectClass=user)(|(homeMDB=*)(msExchHomeServerName=*)))(&(objectCategory=person)(objectClass=contact))(objectCategory=group)(objectCategory=publicFolder)(objectCategory=msExchDynamicDistributionList) )))) ",
          control  => [ $page ],
          attrs  => "proxyAddresses",
);

my $cookie;
while(1) {
  # Perform search
  my $mesg = $ldap->search( @args );

# Filtering results for proxyAddresses attributes  
  foreach my $entry ( $mesg->entries ) {
    my $name = $entry->get_value( "cn" );
    # LDAP Attributes are multi-valued, so we have to print each one.
    foreach my $mail ( $entry->get_value( "proxyAddresses" ) ) {
     # Test if the Line starts with one of the following lines:
     # proxyAddresses: [smtp|SMTP]:
     # and also discard this starting string, so that $mail is only the
     # address without any other characters...
     if ( $mail =~ s/^(smtp|SMTP)://gs ) {
       push(@valid, $mail." OK\n"); 
     }
    }
  }

  # Only continue on LDAP_SUCCESS
  $mesg->code and last;

  # Get cookie from paged control
  my($resp)  = $mesg->control( LDAP_CONTROL_PAGED ) or last;
  $cookie    = $resp->cookie or last;

  # Set cookie in paged control
  $page->cookie($cookie);
}

if ($cookie) {
  # We had an abnormal exit, so let the server know we do not want any more
  $page->cookie($cookie);
  $page->size(0);
  $ldap->search( @args );
  # Also would be a good idea to die unhappily and inform OP at this point
     die("LDAP query unsuccessful");
}
# Only write the file once the query is successful
open VALID, ">$VALID" or die "CANNOT OPEN $VALID $!";
print VALID @valid;
# Add additional restrictions, users, etc. to the output file below.
#print VALID "user\@example.com OK\n";
#print VALID "user1\@example.com 550 User unknown.\n";
#print VALID "bad.example.com 550 User does not exist.\n";

close VALID;
