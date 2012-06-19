#!/usr/bin/perl 
use Crypt::SmbHash;

$password = $ARGV[0];

sub trimwhitespace($) { 
	my $string = shift; 
	$string=~ s/^\s+//; 
	$string =~ s/\s+$//; 
	return $string; 
}

if ( !$password ) {
	print "Input secret: "; 
	$password = <STDIN>;
}

$password = trimwhitespace($password);

ntlmgen $password, $smblmhash, $smbnthash;

print $smblmhash. "\n";
