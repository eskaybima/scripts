#
#
# ESXi 3.5 Backup Script
#
# Autor: Christian Gruetzner
#
#
#############################################################################
#
#2008-08-22  V 1.0 Basic Script
#            Functions:     - create snapshots of all local VM's
#                           - get files from ESX-Datastore to local Store
#                           - exclude unneccessary files from backup
#                           - remove all created snapshots
#                           - actual time in log
#
#############################################################################




my $url = "https://IP-Address:Port/sdk/vimService";     #URL to your ESX Host, default: <https://IP-Address:Port/sdk/vimService>
my $username = "user";                                  #Username
my $password = "pw";                                    #User password
my $snapshotname = "BackupSnap";                        #Name of your Snapshot
my $DSPath = "[datastore]";                             #Datastore name on ESX Host, example [datastore]
my @VMNames;
$VMNames[0] = "ServerDisplayName";                      #Uncomment the next lines if you like to backup more vm's
#$VMNames[1] = "";
#$VMNames[2] = "";
#$VMNames[3] = "";
#$VMNames[4] = "";
#$VMNames[5] = "";
#$VMNames[6] = "";
#$VMNames[7] = "";
#$VMNames[8] = "";
#$VMNames[9] = "";
my $RCLIPath = "C:/Progra~1/VMware/VM9270~1";           #VI Remote CLI Path (Windows: Use ONLY Short Folder Names!!!!)
my $DestPath = "D:/";                                   #Destination Path you like to copy to (Windows: Use ONLY Short Folder Names!!!!)

#IMPORTANT!!! -- Under DestPath must exist the VMNames Folder 
#(For Example if your VMNames[0] = "ServerA" and your DestPath = "D:/": D:/ServerA/)
#--------------------------------------------------------
# For the short folder name use "dir /X"










#call the sub function (at the bottom)
&actualtime();
print " ***** Script Start *************************\n\n";

&actualtime();
print " ----- Create Snapshots of running VM's -----";
print "\n\n";
system("perl $RCLIPath/Perl/apps/vm/snapshotmanager.pl --url $url --username $username --password $password --operation create --powerstatus poweredOn --snapshotname $snapshotname");
print "\n\n";





&actualtime();
print " ----- Copy VM files to local storage   -----";
print "\n\n";
my $i = 0;
#special loop for arrays. run as long the array has data
foreach (@VMNames)
{
    #read all available files and save filenames in the cache-array
	my @cache = `perl $RCLIPath/bin/vifs.pl --url $url --username $username --password $password --dir \"$DSPath $VMNames[$i]\"`;
	#run as long the cache array has data and save the value everytime in $filename
	foreach my $filename (@cache)
	{
		#exclude uninterresting files from backup to save backup space
	 	if($filename !~ /.log/ && $filename !~ /.vswp/ && $filename !~ /.vmsn/ && $filename !~ /-delta/)
	 	{
	 		#remove the "\n" at the end of $filename to prevent a error massage in log
			chomp($filename)
			&actualtime();
			print " ----- Copy File: ";
	 		print $filename;
	 		#get files from VM Datastore to a local Storage
			system("perl $RCLIPath/bin/vifs.pl --url $url --username $username --password $password --get \"$DSPath $VMNames[$i]/$filename\" \"$DestPath$VMNames[$i]/$filename\"");
			print "\n";
		}
	}
	$i++;
}
print "\n\n";





&actualtime();
print " ----- Remove Snapshots of running VM's -----";
print "\n\n";
system("perl $RCLIPath/Perl/apps/vm/snapshotmanager.pl --url $url --username $username --password $password --operation remove --powerstatus poweredOn --snapshotname $snapshotname --children 1");
print "\n\n";

&actualtime();
print " ***** Script End ***************************";










#sub function to print the actual time in the log
sub actualtime
{
	my ($Sekunden, $Minuten, $Stunden, $Monatstag, $Monat,
	    $Jahr, $Wochentag, $Jahrestag, $Sommerzeit) = localtime(time);
	my $CTIME_String = localtime(time);
	$Monat+=1;
	$Jahrestag+=1;
	$Monat = $Monat < 10 ? $Monat = "0".$Monat : $Monat;
	$Monatstag = $Monatstag < 10 ? $Monatstag = "0".$Monatstag : $Monatstag;
	$Stunden = $Stunden < 10 ? $Stunden = "0".$Stunden : $Stunden;
	$Minuten = $Minuten < 10 ? $Minuten = "0".$Minuten : $Minuten;
	$Sekunden = $Sekunden < 10 ? $Sekunden = "0".$Sekunden : $Sekunden;
	$Jahr+=1900;
	
	print "$Jahr-$Monat-$Monatstag $Stunden:$Minuten:$Sekunden";
}