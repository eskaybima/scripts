#!/usr/bin/perl
#
# little perl script to send a wake-up "magic" packet via lan to power-on
# a PC. This is only supported by new BIOS versions, and must be supported
# by the LAN adapter.
#

$IP="255.255.255.255"; # limited broadcast ip (default)
$PORT="9991"; # udp port (default)
$INIT_STREAM="\377\377\377\377\377\377"; # (don't change this)

require 5.002;
use Socket;

if (not defined $ARGV[0]) {
    print "Syntax: $0 ethernet_id [ip-address] [udp-port]\n\n";
    print "Sends a magic wakeup packet to turn on a PC via the LAN\n";
    print "Example: $0 00:80:c9:d1:e0:eb 10.70.82.255 53\n\n";
    exit(1);
}

$ETHERNET_ID = $ARGV[0];
$IP = $ARGV[1] if defined $ARGV[1];
$PORT = $ARGV[2] if defined $ARGV[2];

print STDOUT "Sending to Ethernet-ID $ETHERNET_ID, using destination $IP:$PORT\n";

$protocol = getprotobyname('udp');
socket(S, &PF_INET, &SOCK_DGRAM, $protocol) || die "can't create socket\n";
setsockopt(S, SOL_SOCKET, SO_REUSEADDR, 1);
setsockopt(S, SOL_SOCKET, SO_BROADCAST, 1);
bind(S, sockaddr_in(0, INADDR_ANY)) || die "can't bind\n";
$ipaddr = inet_aton($IP) || die "unknown host: $IP\n";
$paddr = sockaddr_in($PORT, $ipaddr) || die "sockaddr failed\n";

$ETHERNET_ID =~ s/[:-]//g;
$ETHERNET_ID = pack "H12", $ETHERNET_ID;

$WAKE_UP = $INIT_STREAM; $i=0;
while ($i<16) {
    $WAKE_UP = $WAKE_UP . $ETHERNET_ID;
    $i++;
}

# send three times to be sure the system gets the packet
send (S, $WAKE_UP,0,$paddr) || die "send failed.\n";
send (S, $WAKE_UP,0,$paddr);
send (S, $WAKE_UP,0,$paddr); 
