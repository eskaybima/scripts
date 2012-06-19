#!/usr/bin/perl -w

#	Dit script zoekt door middel van het vergelijken van md5sums naar de verschillen tussen 2 mappen
#	Aanroep:
#		- Maak een lijst van verschillende bestanden
#		listchanges.pl list /var/www/html /var/www/anderehtml	
#		- Maak een package (tarball) van alle verschillende bestanden
#		listchanges.pl pack /var/www/html /var/www/anderehtml	
#	Globaal gebeurt er het volgende:
#		Plaats de inhoud van 'Map A' (parameter 1) in $filesa
#		Plaats de inhoud van 'Map B' (parameter 2) in $filesb
#		Vergelijk elk bestand in Map A met die van Map B
#			Zijn ze niet gelijk? Print dan een regel
#	Datum:	1 April(echt waar) 2009

if($#ARGV < 2) {
	print "Geen parameter meegegeven, geef 1 commando en twee mappen als parameters mee.\n
		Gebruik: listchanges.pl list nieuweMap oudeMap \n
			 listchanges.pl pack nieuwMap oudeMap \n \n";
	exit 0;
}


my $routine	= $ARGV[0];
my $dira 		= $ARGV[1];
my $dirb 		= $ARGV[2];

@filesa=null;
@filesb=null;

#$files is een tijdelijke 'werk' array
@files=`cd \"$dira\" && find ./ -type f | grep -v .svn | grep -v .tmp | grep -v start/logonui`;

foreach $i (@files) {
	$command = 'md5sum "'.$dira.'/'.$i.'"';
	$command =~ s/\n//g;
	$md5line = `$command`;
	$md5line =~ s/$dira\/\.\///g;
	$md5line =~ s/\n//g;
	push(@filesa,$md5line);
}

@files=`cd \"$dirb\" && find ./ -type f | grep -v .svn | grep -v .tmp | grep -v start/logonui`;

foreach $i (@files) {
	$command = 'md5sum "'.$dirb.'/'.$i.'"';
	$command =~ s/\n//g;
	$md5line = `$command`;
	$md5line =~ s/$dirb\/\.\///g;
	$md5line =~ s/\n//g;
	push(@filesb,$md5line);
}

@tarfiles = null;
foreach $filea (@filesa) {
	$gevonden = 'nee';
	foreach $fileb (@filesb) {
		if($filea eq $fileb ) {
			$gevonden = 'ja';
		}
	}
	if($gevonden eq 'nee') {
		if($routine eq 'list') {
			print "\n".$filea;
		}
		if($routine eq 'pack') {
			$filea =~ s/^[a-f0-9]{1,}[\s]{1,}//ig;
			push(@tarfiles,$filea);
		}
	}
}

if($routine eq 'pack') {
	$command = 'tar cfz changes.tar.gz -C "'.$dira.'" ';
	foreach $file (@tarfiles) {
		if($file ne null && $file ne 'null') {
			$command .= ' "'.$file.'"';
		}
	}
	print `$command`;
}

exit 0;
