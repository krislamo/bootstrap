#!/bin/bash

#########################
#### USER EDITABLE ######
#########################

# You should hardcode the base URL for your raw repository files. Set the value
# of REPO_RAW_URL to your fork, replacing the `authorized_keys` file with your own.
# i.e., "https://raw.githubusercontent.com/<GH_USER>/<GH_REPO>/<GH_BRANCH>"
REPO_RAW_URL="https://git.krislamo.org/kris/bootstrap/raw/branch/main"
AUTH_KEY_FILE="/authorized_keys"

# Optional debianzfs install script, accessed with -z
DEBIANZFS="https://git.krislamo.org/kris/debianzfs/raw/branch/main/debianzfs.sh"
DEBIANZFS_BIN="/usr/local/bin/debianzfs"

##############################
######## STOP EDITING ########
##############################

# Root required
if [ $EUID -ne 0 ]; then
	echo "You must run this script as root"
	exit 1
fi

# Clean environment
unset BOOT_CYCLE
unset CDROM_REMOVE
unset ENABLE_SSH
unset FIELD_IP_INDEX
unset GATEWAY_IP
unset NEW_HOSTNAME
unset IP
unset QRCODE_SSH
unset LIVECD
unset REPO
unset SSH_INSTALL
unset TELNUM
unset UPDATE_SYSTEM
unset ZFSINSTALL
unset DATE
unset CUR_HOSTNAME
unset SSH_PUB_KEY
unset SSH_FINGERPRINT
unset MACHINE_IP
unset MESSAGE
unset TEXT_MESSAGE

# Options
while getopts ':bcefg:h:i:lqr:st:uz' OPTION; do
	case "$OPTION" in
		b) BOOT_CYCLE="true";;
		c) CDROM_REMOVE="true";;
		e) ENABLE_SSH="true";;
		f) FIELD_IP_INDEX="$OPTARG";;
		g) GATEWAY_IP="$OPTARG";;
		h) NEW_HOSTNAME="$OPTARG";;
		i) IP="$OPTARG";;
		l) LIVECD="true";;
		q) QRCODE_SSH="true";;
		r) REPO="$OPTARG";;
		s) SSH_INSTALL="true";;
		t) TELNUM="$OPTARG";;
		u) UPDATE_SYSTEM="true";;
		z) ZFSINSTALL="true";;
		?)
			echo "ERROR: Option not recognized"
			exit 1;;
	esac
done

# Use Live session settings
if [ "$LIVECD" == "true" ]; then
	CDROM_REMOVE="true"
	ENABLE_SSH="true"
	QRCODE_SSH="true"
	SSH_INSTALL="true"
	UPDATE_SYSTEM="true"
fi

# Allow override but use default repo if not set
[ -z "$REPO" ] && REPO="$REPO_RAW_URL"

# Get current date and hostname
DATE=$(date '+%Y%m%d')
CUR_HOSTNAME=$(hostname)

# Remove CD sources from sources list
if [ "$CDROM_REMOVE" == "true" ]; then
	echo "NOTICE: Backing up /etc/apt/sources.list => /etc/apt/sources.list.$DATE"
	sed -i."$DATE" '/deb cdrom/d' /etc/apt/sources.list
fi

# Upgrade system software
if [ "$UPDATE_SYSTEM" == "true" ]; then
	echo "NOTICE: Upgrading system"
	apt-get update
	apt-get upgrade -y
fi

# If IP is set, backup interfaces and configure static IP
if [ -n "$IP" ]; then
	if [ -z "$GATEWAY_IP" ]; then
		echo "ERROR: IP set without a GATEWAY address. See option -g"
		exit 1
	fi

	echo "NOTICE: Backing up network interfaces file and installing a new static one"
	sed -i."$DATE" "s/dhcp/static/g" /etc/network/interfaces
	if ! grep -q "address" /etc/network/interfaces; then
		echo "  address $IP" >> /etc/network/interfaces
		echo "  gateway $GATEWAY_IP" >> /etc/network/interfaces
	else
		echo "ERROR: Address already set"
		exit 1
	fi
fi

# If NEW_HOSTNAME is set, configure new hostname and backup /etc/hosts
if [ -n "$NEW_HOSTNAME" ]; then
	hostnamectl set-hostname "$NEW_HOSTNAME"
	echo "NOTICE: Backing up /etc/hosts and setting new hostname to '$NEW_HOSTNAME'"
	sed -i."$DATE" "s/$CUR_HOSTNAME/$NEW_HOSTNAME/g" /etc/hosts
fi

# Install personal SSH keys under root and install the OpenSSH server
if [ "$SSH_INSTALL" == "true" ]; then
	# Does authorized_keys file already exist?
	if [ -f /root/.ssh/authorized_keys ]; then
		echo "ERROR: /root/.ssh/authorized_keys file already exists"
		exit 1
	fi

	echo "NOTICE: Installing root's authorized_keys and the OpenSSH server"
	mkdir -p /root/.ssh/
	chmod 700 /root/.ssh/
	wget "${REPO}${AUTH_KEY_FILE}" -O /root/.ssh/authorized_keys
	chmod 644 /root/.ssh/authorized_keys
	apt-get install openssh-server -y

	if [ "$ENABLE_SSH" == "true" ]; then
		echo "NOTICE: Enabling the OpenSSH server"
		systemctl start ssh
	fi
fi

# Download DebianZFS script
if [ "$ZFSINSTALL" == "true" ]; then
	echo "NOTICE: Installing DebianZFS installation script"
	wget "$DEBIANZFS" -O "$DEBIANZFS_BIN"
	chmod u+x "$DEBIANZFS_BIN"
fi

# Restart or show SSH ECDSA public key fingerprint and IP addresses
if [ "$BOOT_CYCLE" == "true" ]; then
	echo "NOTICE: Restarting the machine in 10 seconds..."
	sleep 9
	echo "NOTICE: Restarting!"
	sleep 1
	systemctl reboot
elif [ "$SSH_INSTALL" == "true" ] && [ "$ENABLE_SSH" == "true" ]; then
	SSH_PUB_KEY="$(ssh-keyscan localhost 2>/dev/null | grep "ecdsa" | cut -f2- -d' ')"
	SSH_FINGERPRINT="$(ssh-keygen -l -f /etc/ssh/ssh_host_ecdsa_key.pub | awk '{print $2}')"
	[ -z "$FIELD_IP_INDEX" ] && FIELD_IP_INDEX=1
	MACHINE_IP="$(hostname -I | cut -f"${FIELD_IP_INDEX}" -d' ')"
	MESSAGE="SSH ECDSA KEY: $SSH_FINGERPRINT and IPs: $MACHINE_IP"
	# Show QR code with a copy and paste secure and verified login script
	if [ "$QRCODE_SSH" == "true" ]; then
		apt-get update
		apt-get install -y qrencode
		[ -z "$TELNUM" ] && read -r -p "Enter SMS number (for QR code): " TELNUM
		TEXT_MESSAGE="TF=\$(mktemp) && echo \"${MACHINE_IP} ${SSH_PUB_KEY}\" > \"\$TF\" && ssh -o \"UserKnownHostsFile \$TF\" root@${MACHINE_IP} && rm \"\$TF\""
		qrencode -t ASCII "smsto:$TELNUM:$TEXT_MESSAGE"
	fi
	echo "$MESSAGE"
fi
