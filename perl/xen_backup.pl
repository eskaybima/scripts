#!/usr/bin/perl
#
#XEN Server machine backup, 
# Arno Broekhof | 2009
#

$backupdir = "/mnt/offsite/";				#Directory to backup to, this should be nfs share or something large.

@skip = ('97d0762c-e96a-4503-b2fe-7d69f1d83347');	#add chunks of uuid to skip backing up of a specifc vm 
							#control domain (dom0) should be added to this list!!

$vmlist = `xe vm-list`;                                 #Get the formatted list of guests
@lineList = split(/\n/,$vmlist);                        #Split the list of guests into and array of lines
@uuid = ();                                             #Array to store uuid's in

foreach $line(@lineList){				#for each line in the array
 if (substr($line,0,4) eq "uuid"){			#look for the word uuid at the beginning of the line
  push(@uuid, substr($line,23,36));			#if its there add the uuid to the array
 }
}

$tcurrent = `date`;					#get the current date
print("Beginning backup of virtual machines at ". $tcurrent);

foreach $guest(@uuid){					#for each guest listed in the uuid list
 if (grep $_ eq $guest, @skip){				#is guest on the skip list?
  print("Skipping backup of: ".$guest ."\n");		#yes so just let it be known it is being skipped
 } else {						#otherwise
  $tcurrent = `date`;     		                               #get the current date
  print("Beginning backup of ".$guest ." @ ". $tcurrent);
  
  print("Shutting down: ".$guest ."\n");				#Shutdown the VM
  $status= `xe vm-shutdown vm=$guest`;
  print($status."\n");

  $fdate = `date +%d%m%y`;						#get the current date in a format we can write
  print("Exporting: ".$guest ."\n");					#export the guest
  $exportstring = $backupdir.$guest.".xva-".$fdate;
  $status= `xe vm-export vm=$guest filename=$exportstring`;		
  print($status."\n");

  print("Powering On Guest: ".$guest ."\n");				#Done, start the vm back up
  $status= `xe vm-start vm=$guest`;
  print($status."\n");

  $tcurrent = `date`;                                   #get the current date
  print("Completed backup of ".$guest ." @ ". $tcurrent);
 }

}

$tfinished = `date`;
print("Backup completed at ".$tfinished);
