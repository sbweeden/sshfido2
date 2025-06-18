#!/bin/bash

# Import our environment variables from systemd since when running as a service we don't get all the env by default
# Inspired by https://unix.stackexchange.com/questions/146995/inherit-environment-variables-in-systemd-docker-container
cat /proc/1/environ | tr "\000" "\n" | sed -e 's/=/="/' -e 's/$/"/' > /tmp/myenv
while IFS= read -r line; do
    # Process each line here
    echo "Setting environment variable: $line"
    eval "export $line"
done < "/tmp/myenv"
rm /tmp/myenv

#
# You need to establish these variables in the environment.
# That might be as simple as defining them here before running the script
# or you might establish them as docker or kubernetes environment
# variables (e.g. from a kubernetes secret) before running the script.
#

#USERNAME=testuser
#DISPLAYNAME="Test User"

if [ -z "$USERNAME" ] ; then echo "USERNAME not defined"; exit 1; fi
if [ -z "$DISPLAYNAME" ] ; then echo "DISPLAYNAME not defined"; exit 1; fi

#
# You should not really need to change anything below for a demo, only perhaps some of the configuration
# options that are passed to the pam_ibm_auth.so library set in the isv-auth-choice file.
#
#

# move to working directory
cd /root/resources

echo "Configuring user and sshd for fido2 authentication"
echo "USERNAME: $USERNAME"
echo "DISPLAYNAME: $DISPLAYNAME"

# Create the user and install the ssh public key as an authorized_keys file
if id "$USERNAME" >/dev/null 2>&1; then
    echo "User: $USERNAME already exists, skipping."
else
  echo "Creating user: $USERNAME"
  useradd -c "$DISPLAYNAME" "$USERNAME"
  mkdir "/home/$USERNAME/.ssh"
  chmod 700 "/home/$USERNAME/.ssh"
  chown "$USERNAME" "/home/$USERNAME/.ssh"
  cp "/root/resources/id_ed25519_sk.pub" "/home/$USERNAME/.ssh/authorized_keys"
  chown "$USERNAME" "/home/$USERNAME/.ssh/authorized_keys"
  chmod 600 "/home/$USERNAME/.ssh/authorized_keys"
fi

#
# Update the sshd_config file
# Inspiration from: https://developers.yubico.com/SSH/Securing_SSH_with_FIDO2.html
#
if ! ls /etc/ssh/sshd_config.orig 1> /dev/null 2>&1
then    
  echo "Creating backup of /etc/sshd_config"
  cp /etc/ssh/sshd_config /etc/ssh/sshd_config.orig
fi

# Start with the original file, and create a new one with the changes
# This makes the script somewhat idempotent but if any manual changes were made
# to sshd_config since the .orig file was created, they will be lost
cat /etc/ssh/sshd_config.orig | \
sed \
  -e "s|.*PubkeyAuthentication.*|PubkeyAuthentication yes\nPubkeyAuthOptions verify-required\n|" \
  -e "s|#PermitRootLogin prohibit-password|PermitRootLogin prohibit-password|" \
  -e "s|#PasswordAuthentication.*|PasswordAuthentication no|" \
  -e "s|#PermitEmptyPasswords.*|PermitEmptyPasswords no|" \
  -e "s|#Banner.*|Banner /root/resources/banner.txt|" \
  > /etc/ssh/sshd_config

# restart sshd
echo "Restarting sshd"
systemctl restart sshd
echo "DONE!"
