#!/bin/bash
#----------------------------------------------------------------------------------------------- 
# The Dizwell-Oracle Reliable Installation Script (DORIS) version 1.1d
# Copyright (c) 2007,2008 Howard Rogers, Dizwell Informatics
#
# This script helps install Oracle onto the following 32-bit Linux distros: Redhat4, Redhat5, 
# OpenSuse 10.3, OpenSuse 11.0, Fedora 8, Fedora 9, Ubtunu 7.10, Ubuntu 8.04, Debian 4 and PCLinux OS; 
#
# ...and onto the following 64-bit distros: Redhat4, Redhat5, OpenSuse 10.3, Fedora 8, OpenSuse 11.0
#
# The script is supplied "as-is" with no warranties or guarantees of fitness of 
# use or otherwise. Neither Dizwell Informatics nor Howard Rogers accepts 
# any responsibility whatsoever for any damage caused by the use or misuse of
# this script.
#
# This script should be used in conjunction with the instructions available
# in the Dizwell Informatics DORIS installation guide.
# 
# Specifically, Note Numbers listed in this script are cross-referenced to
# detailed explanations in that guide.
#-----------------------------------------------------------------------------------------------

PREREQS="0"
ROOT_UID="0"
VALIDOS="0"
VALIDORA="0"
OSCHOICE=$1
ORACLECHOICE=$2
ARCHITECTURE="`/bin/uname -m`"
ORACLEUSER="oracle"

#----------------------------------------------------------------------------------------------- 
# A number of prerequisites must be checked and evaluated first.
#----------------------------------------------------------------------------------------------- 

#Start off by checking we're running as root
if [ "$UID" -ne "$ROOT_UID" ] 
 then
   clear
   echo "+-------------------------------------------------------------------------+"   
   echo "| You have to run this script either as root or with sudo privileges!     |"
   echo "+-------------------------------------------------------------------------+"
   exit 1
fi

#And check two arguments have been supplied
if [ $# -ne 2 ] 
 then
  clear
   echo "+-------------------------------------------------------------------+"   
   echo "|  You have to invoke this script with TWO supplied arguments:      |"
   echo "|                                                                   |"   
   echo "|  The name of the operating system you are installing onto and     |"
   echo "|  the version of Oracle's RDBMS you intend installing.             |"   
   echo "|                                                                   |"
   echo "|  The script won't run unti you get both arguments right.          |"
   echo "+-------------------------------------------------------------------+"
  exit 1
fi

#And only go ahead if both arguments have valid values
if [[ $OSCHOICE = "redhat4" || $OSCHOICE = "redhat5" || $OSCHOICE = "suse103" || $OSCHOICE = "fedora8" || $OSCHOICE = "ubuntu7" || $OSCHOICE = "ubuntu8" || $OSCHOICE = "pclinux" || $OSCHOICE = "debian-etch" || $OSCHOICE = "mandriva2008" || $OSCHOICE="fedora9" || $OSCHOICE="suse11" ]]; then 
  VALIDOS="1"
else
  VALIDOS="0"
fi

if [[ $ORACLECHOICE = "10g" || $ORACLECHOICE = "11g" ]]; then
  VALIDORA="1"
else
  VALIDORA="0"
fi 

if [[ $ORACLECHOICE = "11g" ]]; then
  if [[ $OSCHOICE = "mandriva2008" ]]; then
  VALIDOS="0"
fi
fi

if [[ $VALIDOS = "0" || $VALIDORA = "0" ]] 
then
   clear
   echo "+--------------------------------------------------------------+"
   echo "|  You need to supply a valid OS and database version!         |"
   echo "|  Valid OSes are: redhat4, redhat5, ubuntu7, ubuntu8          |" 
   echo "|                  debian-etch, fedora8, fedora9, suse103,     |"
   echo "|                  suse11, pclinux or mandriva2008.            |"
   echo "|                                                              |"
   echo "|  Valid Oracle versions are: 10g or 11g                       |"
   echo "|                                                              |"
   echo "|  Unfortunately, 11g won't install on Mandriva 2008, so that  |"
   echo "|  combination is unacceptable (at least for now).             |" 
   echo "+--------------------------------------------------------------+"
  exit 1
fi

# Only certain combinations of ARCHITECTURE, OS and Oracle are allowed, however: 
if [ $ARCHITECTURE = 'x86_64' ]
 then
  if [[ $OSCHOICE  = "ubuntu7" || $OSCHOICE = "ubuntu8" || $OSCHOICE = "pclinux" || $OSCHOICE = "debian-etch" ]]
 then
   clear
   echo "+-------------------------------------------------------------------------+" 
   echo "|  You are running a 64-bit Operating System. This script only works      |"
   echo "|  for 64-bit versions of Red Hat 4, Red Hat 5, Fedora 8 or               |" 
   echo "|  OpenSuse 10.3 or 11. Your specified O/S, $OSCHOICE, is not             |"
   echo "|  yet supported. You'll have to try manual installation methods instead. |"
   echo "+-------------------------------------------------------------------------+"
  exit 1
fi
fi
 
# And if you've made it through all that lot, then you're running an OK OS and proposing 
# an OK choice of Oracle version, so enable the rest of the script to go ahead:

PREREQS="1"

#-----------------------------------------------------------------------------------------------
# Ubuntu 8.04 works and behaves exactly the same as Ubuntu 7.10, at least as far as Oracle
# installations are concerned. Therefore, if 'ubuntu8' has been specified as the user's OS
# choice, we simply force that to be read as 'ubuntu7'.
#-----------------------------------------------------------------------------------------------
[ "$OSCHOICE" = "ubuntu8" ] && OSCHOICE='ubuntu7'

#----------------------------------------------------------------------------------------------- 
# The start of the script doing something useful
#----------------------------------------------------------------------------------------------- 

if [ $PREREQS = "1" ]
 then

#And establish the current settings for the kernel parameters, so we can work out
#whether we need to change them later on
SMSML=`cat /proc/sys/kernel/sem | awk '{print $1}'`
SMMNS=`cat /proc/sys/kernel/sem | awk '{print $2}'`
SMOPM=`cat /proc/sys/kernel/sem | awk '{print $3}'`
SMMNI=`cat /proc/sys/kernel/sem | awk '{print $4}'`
MEMSZ=`cat /proc/meminfo | grep MemTotal | awk '{print $2}'`
let "MEMSZ *= 1024"
let "MEMSZ /= 2"
let "MEMSZ += 16777216"
SHMAX=`cat /proc/sys/kernel/shmmax`
SHMAL=`cat /proc/sys/kernel/shmall`
SHMNI=`cat /proc/sys/kernel/shmmni` 
PRMIN=`cat /proc/sys/net/ipv4/ip_local_port_range | awk '{print $1}'`
PRMAX=`cat /proc/sys/net/ipv4/ip_local_port_range | awk '{print $2}'`
FSMAX=`cat /proc/sys/fs/file-max`
RMEMD=`cat /proc/sys/net/core/rmem_default`
RMEMM=`cat /proc/sys/net/core/rmem_max`
WMEMD=`cat /proc/sys/net/core/wmem_default`
WMEMM=`cat /proc/sys/net/core/wmem_default`

#-----------------------------------------------------------------------------------------------
# Groups, Users and Installation Directories  -see DORIS Installation Note 3
#-----------------------------------------------------------------------------------------------
#Common Actions First
clear
   echo "+-------------------------------------------------------------------------+" 
   echo "|  A user must be created to own the Oracle installation software.        |"
   echo "|  By default, this user will be called 'oracle', but you can specify     |" 
   echo "|  your own choice of username now. This should NOT be the account you    |"
   echo "|  are currently using to log on to this server, nor can it be the        |"
   echo "|  root account.                                                          |"
   echo "|                                                                         |"
   echo "|  What username would you like to have own the installation?             |"
   echo "+-------------------------------------------------------------------------+" 
echo
echo "Propose a software owner name:"
read ORACLEUSER
LENGTHORAUSER=`echo -n $ORACLEUSER | wc -m | sed -e s/^\s+//`

if [ $ORACLEUSER = "root" ]; then
   echo "+-------------------------------------------------------------------------+" 
   echo "| You cannot use the root account for this purpose. Using the default     |"
   echo "| account 'oracle' instead                                                |"
   echo "+-------------------------------------------------------------------------+" 
   ORACLEUSER="oracle"
fi


if [ "$LENGTHORAUSER" -eq 0 ]; then
   echo "+-------------------------------------------------------------------------+" 
   echo "|  No username has been specified, so the default user 'oracle' will now  |"
   echo "|  be created as the owner of the Oracle installation.                    |" 
   echo "+-------------------------------------------------------------------------+"
   ORACLEUSER="oracle"
fi 

groupadd dba
groupadd oinstall
useradd -m $ORACLEUSER -g oinstall -G dba -s /bin/bash

if [ $ORACLECHOICE = "10g" ]; then
mkdir /u01
mkdir /u01/app
mkdir /u01/app/oracle
mkdir /u01/app/oracle/product
mkdir /u01/app/oracle/product/10.2.0
mkdir /u01/app/oracle/product/10.2.0/db_1
mkdir /osource
chown -R $ORACLEUSER:oinstall /u01/app/oracle
chmod -R 775 /u01/app/oracle
chown -R $ORACLEUSER:oinstall /osource
chmod -R 775 /osource
elif [ $ORACLECHOICE = "11g" ]; then
mkdir /u01
mkdir /u01/app
mkdir /u01/app/oracle
mkdir /u01/app/oracle/product
mkdir /u01/app/oracle/product/11.1.0
mkdir /u01/app/oracle/product/11.1.0/db_1
mkdir /osource
chown -R $ORACLEUSER:oinstall /u01/app/
chmod -R 775 /u01/app/
chown -R $ORACLEUSER:oinstall /osource
chmod -R 775 /osource
fi

#-----------------------------------------------------------------------------------------------
# Common Kernel parameter value computation  -see DORIS Installation Note 5
#-----------------------------------------------------------------------------------------------
if [ $SMSML -lt "250" ]; then
  SMSML="250"
fi

if [ $SMMNS -lt "32000" ]; then
  SMMNS="32000"
fi

if [ $SMOPM -lt "100" ]; then
  SMOPM="100"
fi

if [ $SMMNI -lt "128" ]; then
  SMMNI="128"
fi

result=`echo $SHMAX \< $MEMSZ | bc`
if [ "$result" -ne 0 ]; then
   SHMAX=$MEMSZ
fi

if [ $SHMAL -lt "2097152" ]; then
  SHMAL="2097152"
fi

if [ $SHMNI -lt "4096" ]; then
  SHMNI="4096"
fi

if [ $PRMIN -gt "1024" ]; then
  PRMIN="1024"
fi


if [ $PRMAX -lt "65000" ]; then
  PRMAX="65000"
fi

if [ $FSMAX -lt "65536" ]; then
  FSMAX="65536"
fi

if [ $WMEMD -lt "262144" ]; then
  WMEMD="262144"
fi

if [ $WMEMM -lt "262144" ]; then
  WMEMM="262144"
fi

#-----------------------------------------------------------------------------------------------
# Version-specific Kernel parameter value computation  -see DORIS Installation Note 5
#-----------------------------------------------------------------------------------------------

if [ $ORACLECHOICE = "10g" ]; then
  if [ $RMEMD -lt "1048567" ]; then
    RMEMD="1048567"
  fi

  if [ $RMEMM -lt "1048567" ]; then
    RMEMM="1048567"
  fi
elif [ $ORACLECHOICE = "11g" ]; then
  if [ $RMEMD -lt "4194304" ]; then
    RMEMD="4194304"
  fi
  if [ $RMEMM -lt "4194304" ]; then
    RMEMM="4194304"
  fi
fi

cat >> /etc/sysctl.conf << EOF
#Added for fresh Oracle $2 Installation 
kernel.shmall = $SHMAL
kernel.shmmax = $SHMAX
kernel.shmmni = $SHMNI
kernel.sem = $SMSML $SMMNS $SMOPM $SMMNI
fs.file-max = $FSMAX
net.ipv4.ip_local_port_range = $PRMIN $PRMAX
net.core.rmem_default = $RMEMD
net.core.wmem_default = $WMEMD
net.core.rmem_max = $RMEMM
net.core.wmem_max = $WMEMM
EOF
echo
echo "Kernel Parameters are now configured as follows:"
echo "------------------------------------------------"
/sbin/sysctl -p


#-----------------------------------------------------------------------------------------------
# Environment Variables  -see DORIS Installation Note 4
#-----------------------------------------------------------------------------------------------

if [[ $OSCHOICE = "redhat4" || $OSCHOICE = "redhat5" || $OSCHOICE = "fedora8" || $OSCHOICE = "fedora9" || $OSCHOICE = "suse103" || $OSCHOICE = "pclinux" || $OSCHOICE = "mandriva2008" || $OSCHOICE = "suse11" ]]; then
  ENVFILE="/home/$ORACLEUSER/.bash_profile"
fi

if [[ $OSCHOICE = "ubuntu7" ]]; then
  ENVFILE="/etc/profile"
fi

if [[ $OSCHOICE = "debian-etch" ]]; then
  ENVFILE="/home/$ORACLEUSER/.bashrc"
fi

clear
   echo "+-------------------------------------------------------------------------+"
   echo "| You now need to provide a name for the starter database that gets       |"
   echo "| created as part of the Oracle software installation. The name you       |"
   echo "| provide must be no more than 8 characters long and cannot start         |" 
   echo "| with a number.                                                          |"
   echo "|                                                                         |"
   echo "| If you just press ENTER, you'll be accepting the default database       |"
   echo "| names, which are 'lin10' for 10g installations or 'lin11' for 11g ones. |"
   echo "|                                                                         |"
   echo "| Your answer merely sets the *default* value for the ORACLE_SID          |"
   echo "| environment variable: you can always override that setting by exporting |"          
   echo "| your own environment variables later on, of course.                     |"
   echo "+-------------------------------------------------------------------------+"
   echo
NAMEGOOD=0

while [ "$NAMEGOOD" != 1 ]; do
echo "Propose a database name:"
read DBNAME
LENGTHDBNAME=`echo -n $DBNAME | wc -m | sed -e s/^\s+//`
NUMCHECK=`echo $DBNAME | sed -e s/^[0-9]//`

if [[ $LENGTHDBNAME = 0 ]]; then
  if [[ $ORACLECHOICE = "10g" ]]; then
   echo "+-------------------------------------------------------------------------+" 
   echo "|  No database name was provided, therefore the default database name     |"
   echo "|  ('lin10') will apply.                                                  |" 
   echo "+-------------------------------------------------------------------------+"
    DBNAME="lin10"
    INSTPATH="10.2.0"
    NAMEGOOD=1
  fi

  if [[ $ORACLECHOICE = "11g" ]]; then
   echo "+-------------------------------------------------------------------------+" 
   echo "|  No database name was provided, therefore the default database name     |"
   echo "|  ('lin11') will apply.                                                  |" 
   echo "+-------------------------------------------------------------------------+"
    DBNAME="lin11"
    INSTPATH="11.1.0"
    NAMEGOOD=1
  fi
fi


if [ "$LENGTHDBNAME" -gt 8 ]; then
   echo "+-------------------------------------------------------------------------+" 
   echo "|  Your proposed database name is too long! Please provide one that is    |"
   echo "|  less than 8 characters long and which doesn't start with a number!     |" 
   echo "+-------------------------------------------------------------------------+"
   NAMEGOOD=0
fi 

if [ "$LENGTHDBNAME" -gt 0 ]; then
if [ "$DBNAME" != "$NUMCHECK" ]; then
   echo "+-------------------------------------------------------------------------+" 
   echo "|  Your proposed database name starts with a number! Please provide one   |"
   echo "|  that does NOT start with a number and is less than 8 characters long!  |" 
   echo "+-------------------------------------------------------------------------+"
   NAMEGOOD=0
fi
fi

if [ "$LENGTHDBNAME" -gt 0 ]; then
  if [ "$LENGTHDBNAME" -lt 9 ]; then
     if [ "$DBNAME" = "$NUMCHECK" ]; then
     NAMEGOOD=1
     fi
  fi
fi
done

echo
echo "User Environment now configured as follows..."
echo "---------------------------------------------"
echo
cat >> $ENVFILE << EOF

#Added for fresh Oracle $ORACLECHOICE Installation
ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=/u01/app/oracle/product/$INSTPATH/db_1
ORACLE_SID=$DBNAME
export ORACLE_BASE ORACLE_HOME ORACLE_SID
PATH=\$ORACLE_HOME/bin:\$PATH:.
export PATH
LD_LIBRARY_PATH=\$ORACLE_HOME/lib:/lib:/usr/lib
CLASSPATH=\$ORACLE_HOME/JRE:\$ORACLE_HOME/jlib:\$ORACLE_HOME/rdbms/jlib
export LD_LIBRARY_PATH CLASSPATH
EOF

cat $ENVFILE

#-----------------------------------------------------------------------------------------------
# OS Identification - See DORIS Installation Note 1
#-----------------------------------------------------------------------------------------------
if [ -f /etc/redhat-release ]
then 
mv /etc/redhat-release /etc/redhat-release.original
fi
cat >> /etc/redhat-release << EOF
Red Hat Enterprise Linux AS release 4 (Nahant)
EOF

#-----------------------------------------------------------------------------------------------
# Security Limits  -see DORIS Installation Note 2
#-----------------------------------------------------------------------------------------------
cat /etc/security/limits.conf | sed /'# End of file'/d > /tmp/limits.wrk
cat >> /tmp/limits.wrk << EOF
*       soft    nproc    2047
*       hard    nproc   16384
*       soft    nofile   1024
*       hard    nofile  65536
# End of file
EOF

rm /etc/security/limits.conf
mv /tmp/limits.wrk /etc/security/limits.conf

cat >> /etc/pam.d/login << EOF
session    required     /lib/security/pam_limits.so
session    required     pam_limits.so
EOF

#-----------------------------------------------------------------------------------------------
# Distro-specific package fetching. Do the x86_64 ARCHITECTUREs first
#-----------------------------------------------------------------------------------------------
if [ "$ARCHITECTURE" = 'x86_64' ]; then

#-----------------------------------------------------------------------------------------------
# Suse 10.3-like (OpenSuse 10.3 in particular)
# In theory, this script would be usable with "proper" Suse Enterprise Edition, but
# it's not been tested on that and so no guarantees are made. For OpenSuse 10.3, however,
# it works fine.
#-----------------------------------------------------------------------------------------------

case "$OSCHOICE" in
suse103)
#-----------------------------------------------------------------------------------------------
# Automating Startup -see DORIS Installation Note 6
#-----------------------------------------------------------------------------------------------
if [ -f /etc/init.d/dboraz ]; then
mv /etc/init.d/dboraz /etc/init.d/dboraz.original
fi

echo
echo "Creating a database auto-startup script..."
echo "------------------------------------------"
cat >> /etc/init.d/dboraz << EOF
### BEGIN INIT INFO
# Provides: dboraz
# Required-Start:
# Required-Stop:
# Default-Start: 3 5
# Default-Stop: 0 1 2 6
# Description: Automatic startup and shutdown of Oracle instances and databases
### END INIT INFO
#!/bin/bash
export ORACLE_HOME=/u01/app/oracle/product/$INSTPATH/db_1
export ORACLE_SID=$DBNAME
export PATH=\$ORACLE_HOME/bin:\$PATH:.

case "\$1" in
start)
	su $ORACLEUSER -c \$ORACLE_HOME/bin/dbstart
	su $ORACLEUSER -c "\$ORACLE_HOME/bin/emctl start dbconsole"
	touch /var/lock/oracle
	echo "OK"
	;;
stop)
	echo -n "Shutdown Oracle: "
	su $ORACLEUSER -c \$ORACLE_HOME/bin/dbshut
	rm -f /var/lock/oracle
	echo "OK"
	;;
*)
	echo "Usage: '/etc/init.d/dboraz start|stop"
	exit 1
	;;

esac
exit 0
EOF

chmod 775 /etc/init.d/dboraz
insserv /etc/init.d/dboraz

cat >> $ENVFILE << EOF
#Added to deal with a Java bug in later distros
LIBXCB_ALLOW_SLOPPY_LOCK=1
export LIBXCB_ALLOW_SLOPPY_LOCK
EOF

case "$ORACLECHOICE" in
10g)
echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
zypper sa http://download.opensuse.org/distribution/10.3/repo/oss/ oss
yast -i libaio libaio-32bit libaio-devel libaio-devel-32bit gcc gcc-32bit gcc-c++ gcc42 gcc42-32bit glibc-devel glibc-devel-32bit openmotif sysstat unixODBC libstdc++ libstdc++-32bit libstdc++-devel libstdc++42 libstdc++42-32bit libstdc++42-devel libstdc++42-devel-32bit 
;;
 
11g)
echo 
echo "Cloaking the OS version..."
echo "--------------------------"
cat >> $ENVFILE << EOF
export DISTRIB_RELEASE=4
EOF

echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
zypper sa http://download.opensuse.org/distribution/10.3/repo/oss/ oss
yast -i libaio libaio-devel libaio-devel-32bit gcc gcc-c++ gcc42-32bit glibc-devel glibc-devel-32bit openmotif sysstat unixODBC libstdc++ libstdc++-devel libstdc++-32bit
;;
esac

#-----------------------------------------------------------------------------------------------
# The next set of semi-colons end the Suse103 Section
#-----------------------------------------------------------------------------------------------
;;


#-----------------------------------------------------------------------------------------------
# Suse 11-like (OpenSuse 11 in particular)
#-----------------------------------------------------------------------------------------------

suse11)
#-----------------------------------------------------------------------------------------------
# Automating Startup -see DORIS Installation Note 6
#-----------------------------------------------------------------------------------------------
if [ -f /etc/init.d/dboraz ]; then
mv /etc/init.d/dboraz /etc/init.d/dboraz.original
fi

echo
echo "Creating a database auto-startup script..."
echo "------------------------------------------"
cat >> /etc/init.d/dboraz << EOF
### BEGIN INIT INFO
# Provides: dboraz
# Required-Start:
# Required-Stop:
# Default-Start: 3 5
# Default-Stop: 0 1 2 6
# Description: Automatic startup and shutdown of Oracle instances and databases
### END INIT INFO
#!/bin/bash
export ORACLE_HOME=/u01/app/oracle/product/$INSTPATH/db_1
export ORACLE_SID=$DBNAME
export PATH=\$ORACLE_HOME/bin:\$PATH:.

case "\$1" in
start)
	su $ORACLEUSER -c \$ORACLE_HOME/bin/dbstart
	su $ORACLEUSER -c "\$ORACLE_HOME/bin/emctl start dbconsole"
	touch /var/lock/oracle
	echo "OK"
	;;
stop)
	echo -n "Shutdown Oracle: "
	su $ORACLEUSER -c \$ORACLE_HOME/bin/dbshut
	rm -f /var/lock/oracle
	echo "OK"
	;;
*)
	echo "Usage: '/etc/init.d/dboraz start|stop"
	exit 1
	;;

esac
exit 0
EOF

chmod 775 /etc/init.d/dboraz
insserv /etc/init.d/dboraz

cat >> $ENVFILE << EOF
#Added to deal with a Java bug in later distros
LIBXCB_ALLOW_SLOPPY_LOCK=1
export LIBXCB_ALLOW_SLOPPY_LOCK
EOF

case "$ORACLECHOICE" in
10g)
echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
zypper sa http://download.opensuse.org/distribution/11.0/repo/oss/ oss
yast -i libaio libaio-32bit libaio-devel libaio-devel-32bit gcc gcc-32bit gcc-c++ gcc43 gcc43-32bit glibc-devel glibc-devel-32bit openmotif sysstat unixODBC libstdc++ libstdc++-32bit libstdc++-devel libstdc++43 libstdc++43-32bit libstdc++43-devel libstdc++43-devel-32bit make
;;
 
11g)
echo 
echo "Cloaking the OS version..."
echo "--------------------------"
cat >> $ENVFILE << EOF
export DISTRIB_RELEASE=4
EOF

echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
zypper sa http://download.opensuse.org/distribution/11.0/repo/oss/ oss
yast -i libaio libaio-devel libaio-devel-32bit gcc gcc-c++  glibc-devel glibc-devel-32bit gcc43-32bit openmotif sysstat unixODBC libstdc++ libstdc++-devel libstdc++-32bit make
;;
esac

#-----------------------------------------------------------------------------------------------
# The next set of semi-colons end the Suse 11.0 Section
#-----------------------------------------------------------------------------------------------
;;

#-----------------------------------------------------------------------------------------------
# Redhat 5-like distros next (Centos 5.1, in particular).
# Note the download of additional software may not work in 'proper'
# Red Hat or Oracle Enterprise Linux distros, since it is possible to install those 
# distros but not pay for updates. If you have paid, however, then the commands should work OK.
#-----------------------------------------------------------------------------------------------

redhat5)
#-----------------------------------------------------------------------------------------------
# Automating Startup -see DORIS Installation Note 6
#-----------------------------------------------------------------------------------------------
if [ -f /etc/init.d/dboraz ]; then
mv /etc/init.d/dboraz /etc/init.d/dboraz.original
fi

echo
echo "Creating a database auto-startup script..."
echo "------------------------------------------"
cat >> /etc/init.d/dboraz << EOF
#!/bin/bash
# chkconfig: 345 99 10
# description: Startup Script for Oracle Databases
# /etc/init.d/dboraz

export ORACLE_HOME=/u01/app/oracle/product/$INSTPATH/db_1
export ORACLE_SID=$DBNAME
export PATH=\$ORACLE_HOME/bin:\$PATH:.

case "\$1" in
start)
	su $ORACLEUSER -c \$ORACLE_HOME/bin/dbstart
	su $ORACLEUSER -c "\$ORACLE_HOME/bin/emctl start dbconsole"
	touch /var/lock/oracle
	echo "OK"
	;;
stop)
	echo -n "Shutdown Oracle: "
	su $ORACLEUSER -c \$ORACLE_HOME/bin/dbshut
	rm -f /var/lock/oracle
	echo "OK"
	;;
*)
	echo "Usage: '/etc/init.d/dboraz start|stop"
	exit 1
	;;

esac
exit 0
EOF
chmod 775 /etc/init.d/dboraz
cd /etc/init.d
chkconfig --level 345 dboraz on	 		   

case "$ORACLECHOICE" in 
10g)
echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
yum -y install libaio libaio-devel gcc libXp compat-libstdc++-33 compat-db gcc-c++ glibc-devel sysstat glibc-headers glibc glibc-common 
;;
	
11g)
echo 
echo "Cloaking the OS version..."
echo "--------------------------"
cat >> $ENVFILE << EOF
export DISTRIB_RELEASE=4
EOF

echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
yum -y install libaio.i386 libaio libaio-devel.i386 libaio-devel gcc unixODBC unixODBC-devel sysstat elfutils-devel libstdc++-devel compat-libstdc++-33.i386 elfutils-libelf.i386 libstdc++.i386 libstdc++.x86_64 gcc-c++ glibc glibc-common glibc-headers glibc-devel.i386 glibc-devel compat-libstdc++-33

;;
esac

#-----------------------------------------------------------------------------------------------
# The next set of semi-colons end the Redhat5 Section
#-----------------------------------------------------------------------------------------------
;;

#-----------------------------------------------------------------------------------------------
# Redhat 4-like distros next (Centos 4.5 and above, in particular).
# Note the download of additional software may not work in 'proper'
# Red Hat or Oracle Enterprise Linux distros, since it is possible to install those 
# distros but not pay for updates. If you have paid, however, then the commands should work OK.
#-----------------------------------------------------------------------------------------------

redhat4)
#-----------------------------------------------------------------------------------------------
# Automating Startup -see DORIS Installation Note 6
#-----------------------------------------------------------------------------------------------
if [ -f /etc/init.d/dboraz ]; then
mv /etc/init.d/dboraz /etc/init.d/dboraz.original
fi

echo
echo "Creating a database auto-startup script..."
echo "------------------------------------------"
cat >> /etc/init.d/dboraz << EOF
#!/bin/bash
# chkconfig: 345 99 10
# description: Startup Script for Oracle Databases
# /etc/init.d/dboraz

export ORACLE_HOME=/u01/app/oracle/product/$INSTPATH/db_1
export ORACLE_SID=$DBNAME
export PATH=\$ORACLE_HOME/bin:\$PATH:.

case "\$1" in
start)
	su $ORACLEUSER -c \$ORACLE_HOME/bin/dbstart
	su $ORACLEUSER -c "\$ORACLE_HOME/bin/emctl start dbconsole"
	touch /var/lock/oracle
	echo "OK"
	;;
stop)
	echo -n "Shutdown Oracle: "
	su $ORACLEUSER -c \$ORACLE_HOME/bin/dbshut
	rm -f /var/lock/oracle
	echo "OK"
	;;
*)
	echo "Usage: '/etc/init.d/dboraz start|stop"
	exit 1
	;;

esac
exit 0
EOF
chmod 775 /etc/init.d/dboraz
cd /etc/init.d
chkconfig --level 345 dboraz on	 		   

case "$ORACLECHOICE" in 
10g)
echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
yum -y install libaio libaio-devel gcc compat-libstdc++-33 compat-db gcc-c++ glibc-devel sysstat glibc-headers glibc glibc-common xorg-x11-deprecated-libs
;;
	
11g)
echo 
echo "Cloaking the OS version..."
echo "--------------------------"
cat >> $ENVFILE << EOF
export DISTRIB_RELEASE=4
EOF

echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
yum -y install libaio.i386 libaio-devel libaio gcc unixODBC unixODBC-devel sysstat elfutils-devel libstdc++-devel compat-libstdc++-33.i386 elfutils-libelf.i386 libstdc++.i386 libstdc++.x86_64 gcc-c++ glibc glibc-common glibc-headers glibc-devel.i386 glibc-devel compat-libstdc++-33

;;
esac

#-----------------------------------------------------------------------------------------------
# The next set of semi-colons end the Redhat4 Section
#-----------------------------------------------------------------------------------------------
;;

#-----------------------------------------------------------------------------------------------
# Fedora 8 next. This is a completely non-supported distro from Oracle Corporation's 
# point of view, of course. 
#-----------------------------------------------------------------------------------------------

fedora8)
#-----------------------------------------------------------------------------------------------
# Automating Startup -see DORIS Installation Note 6
#-----------------------------------------------------------------------------------------------
if [ -f /etc/init.d/dboraz ]; then
mv /etc/init.d/dboraz /etc/init.d/dboraz.original
fi

echo
echo "Creating a database auto-startup script..."
echo "------------------------------------------"
cat >> /etc/init.d/dboraz << EOF
#!/bin/bash
# chkconfig: 345 99 10
# description: Startup Script for Oracle Databases
# /etc/init.d/dboraz

export ORACLE_HOME=/u01/app/oracle/product/$INSTPATH/db_1
export ORACLE_SID=$DBNAME
export PATH=\$ORACLE_HOME/bin:\$PATH:.

case "\$1" in
start)
	su $ORACLEUSER -c \$ORACLE_HOME/bin/dbstart
	su $ORACLEUSER -c "\$ORACLE_HOME/bin/emctl start dbconsole"
	touch /var/lock/oracle
	echo "OK"
	;;
stop)
	echo -n "Shutdown Oracle: "
	su $ORACLEUSER -c \$ORACLE_HOME/bin/dbshut
	rm -f /var/lock/oracle
	echo "OK"
	;;
*)
	echo "Usage: '/etc/init.d/dboraz start|stop"
	exit 1
	;;

esac

EOF
chmod 775 /etc/init.d/dboraz
cd /etc/init.d
chkconfig --level 345 dboraz on	 

cat >> $ENVFILE << EOF
#Added to deal with a Java bug in later distro
LIBXCB_ALLOW_SLOPPY_LOCK=1
export LIBXCB_ALLOW_SLOPPY_LOCK
EOF

case "$ORACLECHOICE" in
10g)
echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
yum -y install libaio libaio-devel gcc libXp compat-libstdc++-33 compat-db gcc-c++ glibc-devel sysstat gnome-libs
yum --enablerepo=development -y install libxcb
yum -y install glibc-devel.i386 libstdc++-devel
yum 
;;

11g)
echo 
echo "Cloaking the OS version..."
echo "--------------------------"
cat >> $ENVFILE << EOF
export DISTRIB_RELEASE=4
EOF

echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
yum -y update glibc glibc-common glibc-headers glibc-devel
yum -y install gnome-libs libaio.i386 libaio libaio-devel.i386 libaio-devel gcc unixODBC unixODBC-devel sysstat elfutils-devel libstdc++-devel compat-libstdc++-33.i386 elfutils-libelf.i386 gcc-c++ glibc-devel compat-libstdc++-33
yum --enablerepo=development -y install libxcb
;;
esac

#-----------------------------------------------------------------------------------------------
# The next set of semi-colons end the Fedora8 Section
#-----------------------------------------------------------------------------------------------
;;

esac
fi 

#-----------------------------------------------------------------------------------------------
# Distro-specific package fetching. Now we do the x86 (32-bit) distros...
#-----------------------------------------------------------------------------------------------
if [ "$ARCHITECTURE" != 'x86_64' ]; then

#-----------------------------------------------------------------------------------------------
# Redhat 4-like distros next (Centos 4.5 and above, in particular).
# Note the download of additional software may not work in 'proper'
# Red Hat or Oracle Enterprise Linux distros, since it is possible to install those 
# distros but not pay for updates. If you have paid, however, then the commands should work OK.
#-----------------------------------------------------------------------------------------------
case $OSCHOICE in
redhat4)
#-----------------------------------------------------------------------------------------------
# Automating Startup -see DORIS Installation Note 6
#-----------------------------------------------------------------------------------------------
if [ -f /etc/init.d/dboraz ]; then
mv /etc/init.d/dboraz /etc/init.d/dboraz.original
fi

echo
echo "Creating a database auto-startup script..."
echo "------------------------------------------"
cat >> /etc/init.d/dboraz << EOF
#!/bin/bash
# chkconfig: 345 99 10
# description: Startup Script for Oracle Databases
# /etc/init.d/dboraz

export ORACLE_HOME=/u01/app/oracle/product/$INSTPATH/db_1
export ORACLE_SID=$DBNAME
export PATH=\$ORACLE_HOME/bin:\$PATH:.

case "\$1" in
start)
  su $ORACLEUSER -c \$ORACLE_HOME/bin/dbstart
  su $ORACLEUSER -c "\$ORACLE_HOME/bin/emctl start dbconsole"
  touch /var/lock/oracle
  echo "OK"
  ;;
stop)
  echo -n "Shutdown Oracle: "
  su $ORACLEUSER -c \$ORACLE_HOME/bin/dbshut
  rm -f /var/lock/oracle
  echo "OK"
  ;;

*)
	echo "Usage: '/etc/init.d/dboraz start|stop"
	exit 1
	;;

esac
exit 0
EOF

chmod 775 /etc/init.d/dboraz
cd /etc/init.d
chkconfig --level 345 dboraz on	   

case "$ORACLECHOICE" in 
10g)
echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
yum -y install libaio gcc
;;
	
11g)
echo 
echo "Cloaking the OS version..."
echo "--------------------------"
cat >> $ENVFILE << EOF
export DISTRIB_RELEASE=4
EOF

echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
yum -y install libaio gcc libaio-devel unixODBC unixODBC-devel sysstat elfutils-devel libstdc++-devel
;;
esac

#-----------------------------------------------------------------------------------------------
# The next set of semi-colons end the Redhat4 Section
#-----------------------------------------------------------------------------------------------
;;

#-----------------------------------------------------------------------------------------------
# Redhat 5-like distros next (Centos 5.1, in particular).
# Note the download of additional software may not work in 'proper'
# Red Hat or Oracle Enterprise Linux distros, since it is possible to install those 
# distros but not pay for updates. If you have paid, however, then the commands should work OK.
#-----------------------------------------------------------------------------------------------

redhat5)
#-----------------------------------------------------------------------------------------------
# Automating Startup -see DORIS Installation Note 6
#-----------------------------------------------------------------------------------------------
if [ -f /etc/init.d/dboraz ]; then
mv /etc/init.d/dboraz /etc/init.d/dboraz.original
fi

echo
echo "Creating a database auto-startup script..."
echo "------------------------------------------"
cat >> /etc/init.d/dboraz << EOF
#!/bin/bash
# chkconfig: 345 99 10
# description: Startup Script for Oracle Databases
# /etc/init.d/dboraz

export ORACLE_HOME=/u01/app/oracle/product/$INSTPATH/db_1
export ORACLE_SID=$DBNAME
export PATH=\$ORACLE_HOME/bin:\$PATH:.

case "\$1" in
start)
	su $ORACLEUSER -c \$ORACLE_HOME/bin/dbstart
	su $ORACLEUSER -c "\$ORACLE_HOME/bin/emctl start dbconsole"
	touch /var/lock/oracle
	echo "OK"
	;;
stop)
	echo -n "Shutdown Oracle: "
	su $ORACLEUSER -c \$ORACLE_HOME/bin/dbshut
	rm -f /var/lock/oracle
	echo "OK"
	;;
*)
	echo "Usage: '/etc/init.d/dboraz start|stop"
	exit 1
	;;

esac
exit 0
EOF
chmod 775 /etc/init.d/dboraz
cd /etc/init.d
chkconfig --level 345 dboraz on	 		   

case "$ORACLECHOICE" in 
10g)
echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
yum -y install libaio gcc libXp compat-libstdc++-33
;;
	
11g)
echo 
echo "Cloaking the OS version..."
echo "--------------------------"
cat >> $ENVFILE << EOF
export DISTRIB_RELEASE=4
EOF

echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
yum -y install libaio gcc libaio-devel unixODBC unixODBC-devel sysstat elfutils-devel libstdc++-devel
;;
esac

#-----------------------------------------------------------------------------------------------
# The next set of semi-colons end the Redhat5 Section
#-----------------------------------------------------------------------------------------------
;;

#-----------------------------------------------------------------------------------------------
# Ubuntu 7.10-like distros next (hence Xubuntu, Kubuntu and so on are also OK)
# Note that only the Desktop edition of 7.10 or 8.04 is supported here: installations onto the 
# Server versions of Ubuntu are do-able but in a very different manner, so this script won't
# work there. Remember that Ubuntu 8.04 is treated exactly as Ubuntu 7.10 (and has been tested
# to behave as such), so this code is run in either case, thanks to the earlier forced
# assignment of 'ubuntu7' to the "$OSCHOICE" variable.
#-----------------------------------------------------------------------------------------------

ubuntu7)
#-----------------------------------------------------------------------------------------------
# Automating Startup -see DORIS Installation Note 6
#-----------------------------------------------------------------------------------------------
if [ -f /etc/init.d/dboraz ]; then
mv /etc/init.d/dboraz /etc/init.d/dboraz.original
fi

echo
echo "Creating a database auto-startup script..."
echo "------------------------------------------"
cat >> /etc/init.d/dboraz << EOF
#!/bin/bash
# description: Startup Script for Oracle Databases
# /etc/init.d/dboraz

# Set the environment variables for the invoker of the dbstart/dbshut scripts
. /etc/profile

case "\$1" in
start)
  echo -n "Starting Oracle"
  sudo su - $ORACLEUSER -c \$ORACLE_HOME/bin/dbstart
  sudo su - $ORACLEUSER -c "\$ORACLE_HOME/bin/emctl start dbconsole"
  echo "OK"
;;

stop)
  echo -n "Shutting down Oracle" 
  sudo su - $ORACLEUSER -c \$ORACLE_HOME/bin/dbshut
  echo "OK"
;;

*)
  echo "Usage: /etc/init.d/dboraz start|stop"
  exit 1
  ;;

esac
exit 0
EOF

chmod 750 /etc/init.d/dboraz
sudo update-rc.d dboraz defaults 99

#-----------------------------------------------------------------------------------------------
# Creating needed symbolic links  -see DORIS Installation Note 7
#-----------------------------------------------------------------------------------------------
echo
echo "Creating necessary symbolic links..."
echo "------------------------------------"
ln -s /usr/bin/awk /bin/awk
ln -s /usr/bin/rpm /bin/rpm
ln -s /lib/libgcc_s.so.1 /lib/libgcc_s.so
ln -s /usr/bin/basename /bin/basename
groupadd nobody

case "$ORACLECHOICE" in
10g)
echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
cat >> /etc/apt/sources.list <<EOF
#Added for Oracle Installation..."
deb http://archive.ubuntu.com/ubuntu gutsy universe main
EOF
aptitude update
aptitude -y install gcc libaio1 lesstif2 lesstif2-dev make rpm libc6 libstdc++5
;;

11g)
echo 
echo "Cloaking the OS version..."
echo "--------------------------"
cat >> $ENVFILE << EOF
export DISTRIB_RELEASE=4
EOF

echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
cat >> /etc/apt/sources.list <<EOF
#Added for Oracle Installation..."
deb http://archive.ubuntu.com/ubuntu gutsy universe main
EOF
apt-get update
apt-get -y install gcc libaio1 lesstif2 lesstif2-dev make rpm libc6 libstdc++5
;;
esac

#-----------------------------------------------------------------------------------------------
# The next set of semi-colons end the Ubuntu7 Section
#-----------------------------------------------------------------------------------------------
;;

mandriva2008)
#-----------------------------------------------------------------------------------------------
# Automating Startup -see DORIS Installation Note 6
#-----------------------------------------------------------------------------------------------
if [ -f /etc/init.d/dboraz ]; then
mv /etc/init.d/dboraz /etc/init.d/dboraz.original
fi

echo
echo "Creating a database auto-startup script..."
echo "------------------------------------------"
cat >> /etc/init.d/dboraz << EOF
#!/bin/bash
# chkconfig: 345 99 10
# description: Startup Script for Oracle Databases
# /etc/init.d/dboraz

export ORACLE_HOME=/u01/app/oracle/product/$INSTPATH/db_1
export ORACLE_SID=$DBNAME
export PATH=\$ORACLE_HOME/bin:\$PATH:.

case "\$1" in
start)
  su $ORACLEUSER -c \$ORACLE_HOME/bin/dbstart
  su $ORACLEUSER -c "\$ORACLE_HOME/bin/emctl start dbconsole"
  touch /var/lock/oracle
  echo "OK"
  ;;
stop)
  echo -n "Shutdown Oracle: "
  su $ORACLEUSER -c \$ORACLE_HOME/bin/dbshut
  rm -f /var/lock/oracle
  echo "OK"
  ;;

*)
	echo "Usage: '/etc/init.d/dboraz start|stop"
	exit 1
	;;

esac
exit 0
EOF

chmod 775 /etc/init.d/dboraz
cd /etc/init.d
chkconfig --level 345 dboraz on

groupadd nobody

case "$ORACLECHOICE" in 
10g)
echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
REL=`cut -b 6 /etc/version`
urpmi.addmedia --wget "2008."$REL"_contrib.release" 'http://www.gtlib.cc.gatech.edu/pub/mandrake/official/2008.'$REL'/i586/media/contrib/release/' with media_info/hdlist.cz
urpmi --auto kernel-`uname -r | cut -d- -f2`-devel-`uname -r | cut -d- -f1`
urpmi --auto libaio1 libaio1-devel libstdc++5 libstdc++5-devel
;;
	
11g)
echo 
echo "Cloaking the OS version..."
echo "--------------------------"
cat >> $ENVFILE << EOF
export DISTRIB_RELEASE=4
EOF

echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
REL=`cut -b 6 /etc/version`
urpmi.addmedia --wget "2008."$REL"_contrib.release" 'http://www.gtlib.cc.gatech.edu/pub/mandrake/official/2008.'$REL'/i586/media/contrib/release/' with media_info/hdlist.cz
urpmi --auto kernel-`uname -r | cut -d- -f2`-devel-`uname -r | cut -d- -f1`
urpmi --auto libaio1 libaio1-devel libstdc++5 libstdc++5-devel unixODBC sysstat elfutils gcc
;;
esac

#-----------------------------------------------------------------------------------------------
# The next set of semi-colons end the Mandriva Section
#-----------------------------------------------------------------------------------------------
;;

#-----------------------------------------------------------------------------------------------
# Suse 10.3-like distros next (OpenSuse 10.3 in particular)
# In theory, this script would be usable with "proper" Suse Enterprise Edition, but
# it's not been tested on that and so no guarantees are made. For OpenSuse 10.3, however,
# it works fine.
#-----------------------------------------------------------------------------------------------

suse103)
#-----------------------------------------------------------------------------------------------
# Automating Startup -see DORIS Installation Note 6
#-----------------------------------------------------------------------------------------------
if [ -f /etc/init.d/dboraz ]; then
mv /etc/init.d/dboraz /etc/init.d/dboraz.original
fi

echo
echo "Creating a database auto-startup script..."
echo "------------------------------------------"
cat >> /etc/init.d/dboraz << EOF
### BEGIN INIT INFO
# Provides: dboraz
# Required-Start:
# Required-Stop:
# Default-Start: 3 5
# Default-Stop: 0 1 2 6
# Description: Automatic startup and shutdown of Oracle instances and databases
### END INIT INFO
#!/bin/bash
export ORACLE_HOME=/u01/app/oracle/product/$INSTPATH/db_1
export ORACLE_SID=$DBNAME
export PATH=\$ORACLE_HOME/bin:\$PATH:.

case "\$1" in
start)
	su $ORACLEUSER -c \$ORACLE_HOME/bin/dbstart
	su $ORACLEUSER -c "\$ORACLE_HOME/bin/emctl start dbconsole"
	touch /var/lock/oracle
	echo "OK"
	;;
stop)
	echo -n "Shutdown Oracle: "
	su $ORACLEUSER -c \$ORACLE_HOME/bin/dbshut
	rm -f /var/lock/oracle
	echo "OK"
	;;
*)
	echo "Usage: '/etc/init.d/dboraz start|stop"
	exit 1
	;;

esac
exit 0
EOF

chmod 775 /etc/init.d/dboraz
insserv /etc/init.d/dboraz

cat >> $ENVFILE << EOF
#Added to deal with a Java bug in later distros
LIBXCB_ALLOW_SLOPPY_LOCK=1
export LIBXCB_ALLOW_SLOPPY_LOCK
EOF

case "$ORACLECHOICE" in
10g)
echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
zypper sa http://download.opensuse.org/distribution/10.3/repo/oss/ oss
yast -i libaio gcc
;;
 
11g)
echo 
echo "Cloaking the OS version..."
echo "--------------------------"
cat >> $ENVFILE << EOF
export DISTRIB_RELEASE=4
EOF

echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
zypper sa http://download.opensuse.org/distribution/10.3/repo/oss/ oss
yast -i libaio libaio-devel libstdc++ gcc sysstat libgcc libstdc++-devel unixODBC unixODBC-devel libebl
;;
esac

#-----------------------------------------------------------------------------------------------
# The next set of semi-colons end the Suse103 Section
#-----------------------------------------------------------------------------------------------
;;


#-----------------------------------------------------------------------------------------------
# Suse 11-like distros next (OpenSuse 11.0 in particular)
#-----------------------------------------------------------------------------------------------

suse11)
#-----------------------------------------------------------------------------------------------
# Automating Startup -see DORIS Installation Note 6
#-----------------------------------------------------------------------------------------------
if [ -f /etc/init.d/dboraz ]; then
mv /etc/init.d/dboraz /etc/init.d/dboraz.original
fi

echo
echo "Creating a database auto-startup script..."
echo "------------------------------------------"
cat >> /etc/init.d/dboraz << EOF
### BEGIN INIT INFO
# Provides: dboraz
# Required-Start:
# Required-Stop:
# Default-Start: 3 5
# Default-Stop: 0 1 2 6
# Description: Automatic startup and shutdown of Oracle instances and databases
### END INIT INFO
#!/bin/bash
export ORACLE_HOME=/u01/app/oracle/product/$INSTPATH/db_1
export ORACLE_SID=$DBNAME
export PATH=\$ORACLE_HOME/bin:\$PATH:.

case "\$1" in
start)
	su $ORACLEUSER -c \$ORACLE_HOME/bin/dbstart
	su $ORACLEUSER -c "\$ORACLE_HOME/bin/emctl start dbconsole"
	touch /var/lock/oracle
	echo "OK"
	;;
stop)
	echo -n "Shutdown Oracle: "
	su $ORACLEUSER -c \$ORACLE_HOME/bin/dbshut
	rm -f /var/lock/oracle
	echo "OK"
	;;
*)
	echo "Usage: '/etc/init.d/dboraz start|stop"
	exit 1
	;;

esac
exit 0
EOF

chmod 775 /etc/init.d/dboraz
insserv /etc/init.d/dboraz

cat >> $ENVFILE << EOF
#Added to deal with a Java bug in later distros
LIBXCB_ALLOW_SLOPPY_LOCK=1
export LIBXCB_ALLOW_SLOPPY_LOCK
EOF

case "$ORACLECHOICE" in
10g)
echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
zypper sa http://download.opensuse.org/distribution/11.0/repo/oss/ oss
yast -i libaio gcc make
;;
 
11g)
echo 
echo "Cloaking the OS version..."
echo "--------------------------"
cat >> $ENVFILE << EOF
export DISTRIB_RELEASE=4
EOF

echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
zypper sa http://download.opensuse.org/distribution/11.0/repo/oss/ oss
yast -i libaio libaio-devel libstdc++ gcc sysstat libgcc libstdc++-devel unixODBC unixODBC-devel libebl make libelf-devel
;;
esac

#-----------------------------------------------------------------------------------------------
# The next set of semi-colons end the Suse11 Section
#-----------------------------------------------------------------------------------------------
;;

#-----------------------------------------------------------------------------------------------
# Debian 4.0 ("Etch") distro next 
#-----------------------------------------------------------------------------------------------

debian-etch)
#-----------------------------------------------------------------------------------------------
# Automating Startup -see DORIS Installation Note 6
#-----------------------------------------------------------------------------------------------
if [ -f /etc/init.d/dboraz ]; then
mv /etc/init.d/dboraz /etc/init.d/dboraz.original
fi

echo
echo "Creating a database auto-startup script..."
echo "------------------------------------------"
cat >> /etc/init.d/dboraz << EOF
#!/bin/bash
# description: Startup Script for Oracle Databases
# /etc/init.d/dboraz

# Set the environment variables for the invoker of the dbstart/dbshut scripts
export ORACLE_HOME=/u01/app/oracle/product/$INSTPATH/db_1
export ORACLE_SID=$DBNAME
export PATH=\$ORACLE_HOME/bin:\$PATH:.

case "\$1" in
start)
  echo -n "Starting Oracle"
  /bin/su $ORACLEUSER -c \$ORACLE_HOME/bin/dbstart
  /bin/su $ORACLEUSER -c "\$ORACLE_HOME/bin/emctl start dbconsole"
  echo "OK"
;;

stop)
  echo -n "Shutting down Oracle" 
  sudo su - $ORACLEUSER -c \$ORACLE_HOME/bin/dbshut
  echo "OK"
;;

*)
  echo "Usage: /etc/init.d/dboraz start|stop"
  exit 1
  ;;

esac
exit 0
EOF

chmod 750 /etc/init.d/dboraz
sudo update-rc.d dboraz defaults 99

#-----------------------------------------------------------------------------------------------
# Creating needed symbolic links  -see DORIS Installation Note 7
#-----------------------------------------------------------------------------------------------
echo
echo "Creating necessary symbolic links..."
echo "------------------------------------"
ln -s /usr/bin/awk /bin/awk
ln -s /usr/bin/rpm /bin/rpm
ln -s /lib/libgcc_s.so.1 /lib/libgcc_s.so
ln -s /usr/bin/basename /bin/basename
groupadd nobody

case "$ORACLECHOICE" in
10g)
apt-get update
apt-get -y install gcc libaio1 lesstif2 lesstif2-dev make rpm libc6 libstdc++5
;;

11g)
echo 
echo "Cloaking the OS version..."
echo "--------------------------"
cat >> $ENVFILE << EOF
export DISTRIB_RELEASE=4
EOF

apt-get update
apt-get -y install gcc libaio1 lesstif2 lesstif2-dev make rpm libc6 libstdc++5
;;
esac

#-----------------------------------------------------------------------------------------------
# The next set of semi-colons end the Debian-etch Section
#-----------------------------------------------------------------------------------------------
;;

#-----------------------------------------------------------------------------------------------
# Fedora Core 8 next. 
# Fedora ships with a version of Java which causes great problems for the JRE included in 
# the Oracle software. Therefore, this script has to take steps to get around those
# Java incompatibilities -and thus the script should defintely NOT be run on Fedora 7 or earlier
# platforms.
#-----------------------------------------------------------------------------------------------

fedora8)
#-----------------------------------------------------------------------------------------------
# Automating Startup -see DORIS Installation Note 6
#-----------------------------------------------------------------------------------------------
if [ -f /etc/init.d/dboraz ]; then
mv /etc/init.d/dboraz /etc/init.d/dboraz.original
fi

echo
echo "Creating a database auto-startup script..."
echo "------------------------------------------"
cat >> /etc/init.d/dboraz << EOF
#!/bin/bash
# chkconfig: 345 99 10
# description: Startup Script for Oracle Databases
# /etc/init.d/dboraz

export ORACLE_HOME=/u01/app/oracle/product/$INSTPATH/db_1
export ORACLE_SID=$DBNAME
export PATH=\$ORACLE_HOME/bin:\$PATH:.

case "\$1" in
start)
	su $ORACLEUSER -c \$ORACLE_HOME/bin/dbstart
	su $ORACLEUSER -c "\$ORACLE_HOME/bin/emctl start dbconsole"
	touch /var/lock/oracle
	echo "OK"
	;;
stop)
	echo -n "Shutdown Oracle: "
	su $ORACLEUSER -c \$ORACLE_HOME/bin/dbshut
	rm -f /var/lock/oracle
	echo "OK"
	;;
*)
	echo "Usage: '/etc/init.d/dboraz start|stop"
	exit 1
	;;

esac

EOF
chmod 775 /etc/init.d/dboraz
cd /etc/init.d
chkconfig --level 345 dboraz on	 

cat >> $ENVFILE << EOF
#Added to deal with a Java bug in later distros
LIBXCB_ALLOW_SLOPPY_LOCK=1
export LIBXCB_ALLOW_SLOPPY_LOCK
EOF

case "$ORACLECHOICE" in
10g)
echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
yum install -y libaio gcc libXp compat-libstdc++-33
yum --enablerepo=development -y install libxcb.i386
;;

11g)
echo 
echo "Cloaking the OS version..."
echo "--------------------------"
cat >> $ENVFILE << EOF
export DISTRIB_RELEASE=4
EOF

echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
yum install -y libaio gcc libaio-devel unixODBC unixODBC-devel sysstat elfutils-devel libstdc++-devel
yum --enablerepo=development -y install libxcb.i386
;;
esac

#-----------------------------------------------------------------------------------------------
# The next set of semi-colons end the Fedora 8 Section
#-----------------------------------------------------------------------------------------------
;;

fedora9)
#-----------------------------------------------------------------------------------------------
# Automating Startup -see DORIS Installation Note 6
#-----------------------------------------------------------------------------------------------
if [ -f /etc/init.d/dboraz ]; then
mv /etc/init.d/dboraz /etc/init.d/dboraz.original
fi

echo
echo "Creating a database auto-startup script..."
echo "------------------------------------------"
cat >> /etc/init.d/dboraz << EOF
#!/bin/bash
# chkconfig: 345 99 10
# description: Startup Script for Oracle Databases
# /etc/init.d/dboraz

export ORACLE_HOME=/u01/app/oracle/product/$INSTPATH/db_1
export ORACLE_SID=$DBNAME
export PATH=\$ORACLE_HOME/bin:\$PATH:.

case "\$1" in
start)
	su $ORACLEUSER -c \$ORACLE_HOME/bin/dbstart
	su $ORACLEUSER -c "\$ORACLE_HOME/bin/emctl start dbconsole"
	touch /var/lock/oracle
	echo "OK"
	;;
stop)
	echo -n "Shutdown Oracle: "
	su $ORACLEUSER -c \$ORACLE_HOME/bin/dbshut
	rm -f /var/lock/oracle
	echo "OK"
	;;
*)
	echo "Usage: '/etc/init.d/dboraz start|stop"
	exit 1
	;;

esac

EOF
chmod 775 /etc/init.d/dboraz
cd /etc/init.d
chkconfig --level 345 dboraz on	 

cat >> $ENVFILE << EOF
#Added to deal with a Java bug in later distros
LIBXCB_ALLOW_SLOPPY_LOCK=1
export LIBXCB_ALLOW_SLOPPY_LOCK
EOF

case "$ORACLECHOICE" in
10g)
echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
yum install -y libaio gcc libXp compat-libstdc++-33
;;

11g)
echo 
echo "Cloaking the OS version..."
echo "--------------------------"
cat >> $ENVFILE << EOF
export DISTRIB_RELEASE=4
EOF

echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
yum install -y libaio gcc libaio-devel unixODBC unixODBC-devel sysstat elfutils-devel libstdc++-devel
;;
esac

#-----------------------------------------------------------------------------------------------
# The next set of semi-colons end the Fedora 9 Section
#-----------------------------------------------------------------------------------------------
;;

pclinux)
#-----------------------------------------------------------------------------------------------
# Automating Startup -see DORIS Installation Note 6
#-----------------------------------------------------------------------------------------------
if [ -f /etc/init.d/dboraz ]; then
mv /etc/init.d/dboraz /etc/init.d/dboraz.original
fi

echo
echo "Creating a database auto-startup script..."
echo "------------------------------------------"
cat >> /etc/init.d/dboraz << EOF
#!/bin/bash
# chkconfig: 345 99 10
# description: Startup Script for Oracle Databases
# /etc/init.d/dboraz

export ORACLE_HOME=/u01/app/oracle/product/$INSTPATH/db_1
export ORACLE_SID=$DBNAME
export PATH=\$ORACLE_HOME/bin:\$PATH:.

case "\$1" in
start)
  su $ORACLEUSER -c \$ORACLE_HOME/bin/dbstart
  su $ORACLEUSER -c "\$ORACLE_HOME/bin/emctl start dbconsole"
  touch /var/lock/oracle
  echo "OK"
  ;;
stop)
  echo -n "Shutdown Oracle: "
  su $ORACLEUSER -c \$ORACLE_HOME/bin/dbshut
  rm -f /var/lock/oracle
  echo "OK"
  ;;

*)
	echo "Usage: '/etc/init.d/dboraz start|stop"
	exit 1
	;;

esac
exit 0
EOF

chmod 775 /etc/init.d/dboraz
cd /etc/init.d
chkconfig --level 345 dboraz on	   
groupadd nobody

case "$ORACLECHOICE" in
10g)
echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
apt-get update
apt-get -y install libaio1 gcc
;;
	
11g)
echo 
echo "Cloaking the OS version..."
echo "--------------------------"
cat >> $ENVFILE << EOF
export DISTRIB_RELEASE=4
EOF

echo
echo "Getting Necessary Software Packages..."
echo "--------------------------------------"
apt-get update
apt-get -y install libaio1 gcc libaio1-devel libunixODBC1 libunixODBC1-devel libelfutils1-devel libstdc++5-devel
;;
esac

#-----------------------------------------------------------------------------------------------
# The next set of semi-colons end the PCLinuxOS Section
#-----------------------------------------------------------------------------------------------
;;

esac
fi

#-----------------------------------------------------------------------------------------------
# Final wrap-up now that all has been configured successfully
#-----------------------------------------------------------------------------------------------
echo "Change the oracle user password..."
passwd $ORACLEUSER

clear
echo "+------------------------------------------------------------------+"
echo "|                                                                  |"   
echo "|  Congratulations!                                                |"
echo "|                                                                  |"   
echo "|  Your server is now properly configured to run Oracle.           |"
echo "|  You just need to obtain the Oracle software and unzip it as     |"
echo "|  the root user (or using sudo commands if running Ubuntu).       |"
echo "|                                                                  |"   
echo "|  The /osource directory has been created so you can unpack the   |"
echo "|  software onto the hard disk, if you would like to do so.        |"
echo "|                                                                  |"   
echo "|  After that, you just need to stop being root, become the Oracle |"
echo "|  user and launch the Oracle Universal Installer program itself   |"
echo "|  (type: /osource/database/runInstaller if installing off the     |"
echo "|  hard disk, for example)                                         |"
echo "|                                                                  |"   
echo "+------------------------------------------------------------------+"

exit 0


# This is the Else condition for the initial check of prerequisites.
# If you fail any of the prerequisites, you should already have been told why with
# appropriate error messages. But just in case, here's the fallback error message 
else
  clear
   echo "+--------------------------------------------------------------+"
   echo "|  You need to supply a valid OS and database version!         |"
   echo "|  Valid OSes are: redhat4, redhat5, ubuntu7, ubuntu8, suse103 |" 
   echo "|                  debian-etch, fedora8, fedora9 or pclinux.   |"
   echo "|  Valid Oracle versions are: 10g or 11g                       |"
   echo "+--------------------------------------------------------------+"
exit 1
fi


# Version History
#----------------
#
# December 7th 2007 : Version 0.9a.... first release, with support for redhat4, redhat5, fedora8
#                     debian-etch, ubuntu7.10, opensuse10.3 and PClinuxOS2007
#                     No support for 64-bit operating systems at all
#
# April 27th 2008   : Version 1.0a.... Rejigged code to be neater and less repetitive -and hopefully
#                     just a tad bit more elegant and efficient (but don't hold your breath!)
#                     Added support for 64-bit versions of redhat4, redhat5, opensuse10.3 and
#                     fedora8 (10g on 64-bit still causes ignorable installation errors to appear
#                     for most of those distros... more work needed to eliminate these altogether).
#                     Added support for 32-bit version of Ubuntu 8.04
#
# May 14th 2008     : Version 1.1a.... Added support for Fedora 9.
#                     Also added a loop to allow the user to supply a starter database name    
#
# June 1st 2008     : Version 1.1b.... Corrected the placement of a line of code that equates Ubuntu 8
#                     with Ubuntu 7. Before the correction, the environment variables were not set correctly in                     
#                     Ubuntu 8, but now Ubuntu 8 installations are fine.
#
# August 2nd 2008   : Version 1.1c.... Added support for OpenSuse 11.0 x86_64
#
# August 3rd 2008   : Version 1.1d.... Added support for OpenSuse 11.0 x86. See, it wasn't so hard after all!
