#!/bin/bash
# Author: Arno Broekhof 
# Date: 6/06/2009
#
# This script is cron'd everyday to run backups on certain set of VMs and will overwite the previous backup if exists

# directory that all VM backups should go (e.g. /vmfs/volumes/SAN_LUN1/mybackupdir)
VM_BACKUP_VOLUME=/vmfs/volumes/VMFS-local-SATA.Storage/BACKUP

# Split VMDK into 2GB sparse files 1=yes, 0=no
ENABLE_2GB_SPARSE=0

# Number of backups for a given VM before deleting
VM_BACKUP_ROTATION_COUNT=3

# Directory naming convention for backup rotations (please ensure there are no spaces!)
VM_BACKUP_DIR_NAMING_CONVENTION="$(date +%F)" 

# Shutdown guestOS prior to running backups and power them back on afterwards
# This feature assumes VMware Tools are installed, else they will not power down and loop forever
# 1=on, 0 =off
POWER_VM_DOWN_BEFORE_BACKUP=1

# enable shutdown code 1=on, 0 = off
ENABLE_HARD_POWER_OFF=1

# if the above flag "ENABLE_HARD_POWER_OFF "is set to 1, then will look at this flag which is the # of iterations
# the script will wait before executing a hard power off, this will be a multiple of 3
# (e.g) = 4, which means this will wait up to 12secs before it just powers off the VM
ITER_TO_WAIT_SHUTDOWN=4

##########################################################
# NON-PERSISTENT NFS-BACKUP ONLY
# 
# ENABLE NON PERSISTENT NFS BACKUP 1=on, 0=off

ENABLE_NON_PERSISTENT_NFS=0

# umount NFS datastore after backup is complete 1=yes, 0=no
UNMOUNT_NFS=0

# IP Address of NFS Server
NFS_SERVER=172.30.0.195

# Path of exported folder residing on NFS Server (e.g. /some/mount/point )
NFS_MOUNT=/nfsshare

# Non-persistent NFS datastore display name of choice
NFS_LOCAL_NAME=nfs_storage_backup

# Name of backup directory for VMs residing on the NFS volume
NFS_VM_BACKUP_DIR=mybackups 

###########################################################

# DO NOT MODIFY PAST THIS LINE # 

DEVEL_MODE=0

printUsage() {
	SCRIPT_PATH=$(basename $0)
	echo -e "\nUsage: ${SCRIPT_PATH} [VM_FILE_INPUT]\n"
	exit
}

checkVMBackupRotation() {
	local BACKUP_DIR_PATH=$1
	local BACKUP_VM_NAMING_CONVENTION=$2
	LIST_BACKUPS=$(ls -tr ${BACKUP_DIR_PATH})

	#default rotation if variable is not defined
	if [ -z ${VM_BACKUP_ROTATION_COUNT} ]; then
		VM_BACKUP_ROTATION_COUNT=1
	fi

	for DIR in ${LIST_BACKUPS};
	do
		TMP_DIR="${BACKUP_DIR_PATH}/${DIR}"
		TMP=$(echo ${TMP_DIR##*--})

	        if [ ${TMP} = "${BACKUP_VM_NAMING_CONVENTION}" ]; then
	                NEW=${TMP}--1
	                mv "${BACKUP_DIR_PATH}/${DIR}" "${NEW}"
	        elif [ $TMP -ge ${VM_BACKUP_ROTATION_COUNT} ]; then
	                rm -rf "${BACKUP_DIR_PATH}/${DIR}"
	        else
			BASE=$(echo ${TMP_DIR%--*})
	                NEW=${BASE}--$((${TMP}+1))
	                mv "${BACKUP_DIR_PATH}/${DIR}" "$NEW"
	        fi
	done	
}

sanityCheck() {
	NUM_OF_ARGS=$1

	if [ ! ${NUM_OF_ARGS} == 1 ]; then
		printUsage
	fi

	if [ -f /usr/bin/vmware-vim-cmd ]; then
        	VMWARE_CMD=/usr/bin/vmware-vim-cmd
	elif [ -f /bin/vim-cmd ]; then
        	VMWARE_CMD=/bin/vim-cmd
	else
	        echo "You're not running ESX 3.5+ or ESXi!"
	        exit
	fi

	if [ ${ENABLE_NON_PERSISTENT_NFS} -eq 1 ]; then
		${VMWARE_CMD} hostsvc/summary/fsvolume | awk '{print $1'} | grep "\"${NFS_LOCAL_NAME}\"" > /dev/null 2>&1
		if [ ! $? -eq 0 ]; then
			#1 = readonly
			#0 = readwrite
			${VMWARE_CMD} hostsvc/datastore/nas_create "${NFS_LOCAL_NAME}" "${NFS_SERVER}" "${NFS_MOUNT}" 0 
		fi
	fi

	if [ ! -f ${FILE_INPUT} ]; then
		echo -e "Error: ${FILE_INPUT} is not a valid VM input file!\n"
		printUsage
	fi

	if [ ! "`whoami`" == "root" ]; then
  		echo "This script needs to be executed by \"root\"!"
        	exit 1
	fi
}

ghettoVCB() {
	VM_INPUT=$1

        START_TIME=`date`
        S_TIME=`date +%s`

	#dump out all virtual machines allowing for spaces now
	${VMWARE_CMD} vmsvc/getallvms | sed 's/[[:blank:]]\{3,\}/   /g' | awk -F'   ' '{print "\""$1"\";\""$2"\";\""$3"\""}' |  sed 's/\] /\]\";\"/g' | sed '1,1d' > /tmp/vms_list

	IFS=$'\n'
	for VM_NAME in `cat "${VM_INPUT}" | sed '/^$/d' | sed -e 's/^[[:blank:]]*//;s/[[:blank:]]*$//'`;
        do
		VM_ID=`grep -E "\"${VM_NAME}\"" /tmp/vms_list | awk -F ";" '{print $1}' | sed 's/"//g'`

		#ensure default value if one is not selected or variable is null
		if [ -z ${VM_BACKUP_DIR_NAMING_CONVENTION} ]; then
			VM_BACKUP_DIR_NAMING_CONVENTION="$(date +%F)"
		fi

		VMFS_VOLUME=`grep -E "\"${VM_NAME}\"" /tmp/vms_list | awk -F ";" '{print $3}' | sed 's/\[//;s/\]//;s/"//g'`
		VMX_CONF=`grep -E "\"${VM_NAME}\"" /tmp/vms_list | awk -F ";" '{print $4}' | sed 's/\[//;s/\]//;s/"//g'`
		VMX_PATH="/vmfs/volumes/${VMFS_VOLUME}/${VMX_CONF}"
		VMX_DIR=`dirname "${VMX_PATH}"`

		#checks to see if we can pull out the VM_ID
		if [ -z ${VM_ID} ]; then
			echo "Error: failed to extract VM_ID for ${VM_NAME}!"

		#devel mode
		elif [ ${DEVEL_MODE} -eq 1 ]; then
			echo "##########################################"
			echo "Virtual Machine: $VM_NAME"
			echo "VM_ID: $VM_ID"
			echo "VMX_PATH: $VMX_PATH"
			echo "VMX_DIR: $VMX_DIR"
			echo "VMX_CONF: $VMX_CONF"
			echo "VMFS_VOLUME: $VMFS_VOLUME"
			echo -e "##########################################\n"

                #checks to see if the VM has any snapshots to start with
                elif ls "${VMX_DIR}" | grep -q delta > /dev/null 2>&1; then
	                echo "Snapshot found for ${VM_NAME}, backup will not take place"

		#checks to see if the VM has an RDM 
		elif ${VMWARE_CMD} vmsvc/device.getdevices ${VM_ID} | grep "RawDiskMapping" > /dev/null 2>&1; then
			echo "RDM was found for ${VM_NAME}, backup will not take place"

                elif [[ -f "${VMX_PATH}" ]] && [[ ! -z "${VMX_PATH}" ]]; then
		 	#nfs case and backup to root path of your NFS mount 	
	                if [ ${ENABLE_NON_PERSISTENT_NFS} -eq 1 ] ; then 
	                	BACKUP_DIR="/vmfs/volumes/${NFS_LOCAL_NAME}/${NFS_VM_BACKUP_DIR}/${VM_NAME}"
                                if [[ -z ${VM_NAME} ]] || [[ -z ${NFS_LOCAL_NAME} ]] || [[ -z ${NFS_VM_BACKUP_DIR} ]]; then
                                        echo "Variable BACKUP_DIR was not set properly, please ensure all required variables for non-persistent NFS backup option has been defined"
                                        exit 1
                                fi

	              	#non-nfs (SAN,LOCAL)  	
	                else
	                	BACKUP_DIR="${VM_BACKUP_VOLUME}/${VM_NAME}"
                                if [[ -z ${VM_BACKUP_VOLUME} ]]; then
                                        echo "Variable VM_BACKUP_DIR was not defined"
                                        exit 1
                                fi
	                fi

			#initial root VM backup directory
			if [ ! -d "${BACKUP_DIR}" ]; then
				mkdir -p "${BACKUP_DIR}"
	                fi

			# directory name of the individual Virtual Machine backup followed by naming convention followed by count
			VM_BACKUP_DIR="${BACKUP_DIR}/${VM_NAME}-${VM_BACKUP_DIR_NAMING_CONVENTION}"
			mkdir -p "${VM_BACKUP_DIR}"

			cp "${VMX_PATH}" "${VM_BACKUP_DIR}"

			#get all VMDKs listed in .vmx file
			VMDKS_FOUND=`grep -i scsi "${VMX_PATH}" | grep -i fileName | awk -F " " '{print $1}'` 

			#loop through each disk and verify that it's currently present and create array of valid VMDKS
			for DISK in ${VMDKS_FOUND};
			do
				#extract the SCSI ID and use it to check for valid vmdk disk
				SCSI_ID=`echo ${DISK%%.*}`
				grep -i "${SCSI_ID}.present" "${VMX_PATH}" | grep -i "true" > /dev/null 2>&1
				#if valid, then we use the vmdk file
				if [ $? -eq 0 ]; then
					DISK=`grep -i ${SCSI_ID}.fileName "${VMX_PATH}" | awk -F "\"" '{print $2}'`
					VMDKS="${DISK}:${VMDKS}"
				fi
			done
		
			#section that will power down a VM prior to taking a snapshot and backup and power it back on
			if [ ${POWER_VM_DOWN_BEFORE_BACKUP} -eq 1 ]; then
				START_ITERATION=0
				echo "Powering off initiated for ${VM_NAME}, backup will not begin until VM is off..."
				${VMWARE_CMD} vmsvc/power.shutdown ${VM_ID} > /dev/null 2>&1
				while ${VMWARE_CMD} vmsvc/power.getstate ${VM_ID} | grep -i "Powered on" > /dev/null 2>&1;
				do
					#enable hard power off code
					if [ ${ENABLE_HARD_POWER_OFF} -eq 1 ]; then
						START_ITERATION=$((START_ITERATION + 1))
						if [ ${START_ITERATION} -gt ${ITER_TO_WAIT_SHUTDOWN} ]; then
							echo "Hard power off occured for ${VM_NAME}, waited for $((ITER_TO_WAIT_SHUTDOWN*3)) seconds" 
							${VMWARE_CMD} vmsvc/power.off ${VM_ID} > /dev/null 2>&1 
							#this is needed for ESXi, even the hard power off did not take affect right away
							sleep 5
							break
						fi
					fi
                                        echo "VM is still on - Iteration: ${START_ITERATION} - waiting 3secs"
                                        sleep 3
				done 
				echo "VM is off"
			fi

			#powered on VMs only
			if [ ! ${POWER_VM_DOWN_BEFORE_BACKUP} -eq 1 ]; then
				echo "################ Taking backup snapshot for ${VM_NAME} ... ################"
				${VMWARE_CMD} vmsvc/snapshot.create ${VM_ID} vcb_snap VCB_BACKUP_${VM_NAME}_`date +%F` > /dev/null 2>&1
			else
				echo "################## Starting backup for ${VM_NAME} ... #####################"
			fi

			OLD_IFS="${IFS}"
			IFS=":"
			for j in ${VMDKS};
			do
				VMDK="${j}"
				if [ ${ENABLE_2GB_SPARSE} -eq 1 ]; then
					vmkfstools -i "${VMX_DIR}/${VMDK}" -d 2gbsparse "${VM_BACKUP_DIR}/${VMDK}"
				else
					vmkfstools -i "${VMX_DIR}/${VMDK}" "${VM_BACKUP_DIR}/${VMDK}"
				fi
			done
			IFS="${OLD_IFS}"

			#powered on VMs only
			if [ ! ${POWER_VM_DOWN_BEFORE_BACKUP} -eq 1 ]; then
				${VMWARE_CMD} vmsvc/snapshot.remove ${VM_ID} > /dev/null 2>&1

				#do not continue until all snapshots have been committed
                    		echo "Removing snapshot from ${VM_NAME} ..."
		        	while ls "${VMX_DIR}" | grep -q delta;
                       		do
                                	sleep 3
                       		done
			else
				#power on vm that was powered off prior to backup
				echo "Powering back on ${VM_NAME}"
				${VMWARE_CMD} vmsvc/power.on ${VM_ID} > /dev/null 2>&1
			fi	

			checkVMBackupRotation "${BACKUP_DIR}" "${VM_BACKUP_DIR}"
			VMDKS=""

			echo -e "#################### Completed backup for ${VM_NAME}! ####################\n"
                else
                        echo "Error: failed to lookup ${VM_NAME}!"
                fi
        done
	unset IFS

        if [[ ${ENABLE_NON_PERSISTENT_NFS} -eq 1 ]] && [[ ${UNMOUNT_NFS} -eq 1 ]] ; then
		${VMWARE_CMD} hostsvc/datastore/destroy ${NFS_LOCAL_NAME}	
	fi

	echo
        END_TIME=`date`
        E_TIME=`date +%s`
        echo "Start time: ${START_TIME}"
        echo "End   time: ${END_TIME}"
        DURATION=`echo $((E_TIME - S_TIME))`

        #calculate overall completion time
        if [ ${DURATION} -le 60 ]; then
                echo "Duration  : ${DURATION} Seconds"
        else
                echo "Duration  : `awk 'BEGIN{ printf "%.2f\n", '${DURATION}'/60}'` Minutes"
        fi

	echo -e "\nCompleted backing up specified Virtual Machines!\n"
}

####################
#		   #
# Start of Script  #
#		   #
####################

#performs a check on the number of commandline arguments + verifies $2 is a valid file
sanityCheck $#

ghettoVCB $1
