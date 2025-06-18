This repo contains configuration setup for sshd on RHEL9 with a hardware security key FIDO2 login for a user. 

Inspiration for this setup comes from instructions for sshd at: https://developers.yubico.com/SSH/Securing_SSH_with_FIDO2.html

A fairly detailed blog on the topic can also be found here: https://swjm.blog/the-complete-guide-to-ssh-with-fido2-security-keys-841063a04252

# SSH client Setup Requirements

You need a client machine with ssh 8.3 or newer. This includes support for hardware security keys, per documentation in [link above](https://developers.yubico.com/SSH/Securing_SSH_with_FIDO2.html). In my testing I used an M1 mac with MacOS Sequoia 15.5, and installed OpenSSH just like those instructions indicate:
```
brew install openssh
```

It was important to create a new terminal window after doing this to ensure the PATH was setup properly.

My Hardware Security Key is a Yubikey 5 Nano, and I already had a FIDO2 PIN set.

I then created my own hardware security key backed FIDO2 credential for ssh with:
```
ssh-keygen -t ed25519-sk -O resident -O verify-required -C "Shane Weeden"
```
Sample output:
```
$ ssh-keygen -t ed25519-sk -O resident -O verify-required -C "Shane Weeden"
Generating public/private ed25519-sk key pair.
You may need to touch your authenticator to authorize key generation.
Enter PIN for authenticator: <ENTERED MY FIDO2 PIN HERE>
You may need to touch your authenticator again to authorize key generation.
A resident key scoped to 'ssh:' with user id 'null' already exists.
Overwrite key in token (y/n)? y
You may need to touch your authenticator again to authorize key generation.
Enter file in which to save the key (/Users/sweeden/.ssh/id_ed25519_sk): 
Enter passphrase for "/Users/sweeden/.ssh/id_ed25519_sk" (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in /Users/sweeden/.ssh/id_ed25519_sk
Your public key has been saved in /Users/sweeden/.ssh/id_ed25519_sk.pub
The key fingerprint is:
SHA256:buIw6WrE0mq6cDIieLzFKFb9s9272+eVGGKsZDh7PUM Shane Weeden
The key's randomart image is:
+[ED25519-SK 256]-+
|                 |
|                 |
|                 |
|    .   . .      |
| o . . oSo E .   |
|o.=o ...= = . o .|
|O== * .+oo + . ..|
|*B.+ + o= . +  ..|
|=oo.. .. . =+.o. |
+----[SHA256]-----+
```

I used an empty passphrase (i.e. just hit enter when prompted for a passphrase). This resulted in two files in my own home directory `/home/sweeden/.ssh`:

```
$ ls -l ~/.ssh/id_ed25519_sk*
-rw-------  1 sweeden  staff  407 18 Jun 10:17 /Users/sweeden/.ssh/id_ed25519_sk
-rw-r--r--  1 sweeden  wheel  141 18 Jun 10:17 /Users/sweeden/.ssh/id_ed25519_sk.pub
```



# BEFORE building the docker image

After cloning the repository complete the following steps:

1. Create a `.env` file and populate it with a username and displayname. You could just:
```
cp dotenv .env
```
The sample instructions below use the `testuser` account as indicated in `dotenv`.

2. Copy your `~/.ssh/id_ed25519_sk.pub` file to the `resources` folder of this repository.
```
cp ~/.ssh/id_ed25519_sk.pub ./resources/id_ed25519_sk.pub
```

# Building the Docker image

Look at the `build.sh` script to see how to build the container, and the `Dockerfile` to see everything that is established. Note that the `resources/setup_sshd.sh` script is set up as a one-shot service (called `very-last`) to be run when the container starts, which creates the testuser and completes the configuration of the sshd server. This is done as a runtime operation so that the username and displayname can be read from environment variables rather than burned into an image instance.

# Deploying the image

After building it, you could run it directly with docker (see `rundocker.sh`), or (as I prefer) run it on a Kubernetes cluster as a POD/svc. A secret is used to hold environment variables.

Ensure you have a kubernetes config set up, and kubectl is in your path and ready to run against your cluster.

Verify your `.env` file in the same directory as the `deploy.sh` script with real values for the following (samples shown, and skeleton file provided as `dotenv`):

```
USERNAME="testuser"
DISPLAYNAME="Test User"
```

These are only used to create the user that you can ssh to the container as. 

Edit the `sshfido2.yaml` file, and update the image location to your own docker registry - somewhere you've made your built image available. 

Deploy the secret, pod, and NodePort service to kubernetes with:

```
./deploy.sh
```

Make sure the pod starts cleanly:

```
$ kubectl get pod
NAME                                       READY   STATUS    RESTARTS   AGE
sshfido2                                   1/1     Running   0          10m
```

There is a `cleanup.sh` script to remove all artifacts as well.

# Testing ssh to the container

After the script is run, from an external shell try:

```
ssh -l <USERNAME> -p 30222 <localhost or worker node IP address>
```

In this example I am using the kubernetes deployment and port 30222 is the NodePort service exposed (see `sshfido2.yaml`). You can use `localhost` if running with the `rundocker.sh` script, or if on the worker node where the pod is deployed. This would be a different IP/hostname if your kubectl client is remote from the cluster.

You should be prompted to enter your hardware security key FIDO2 PIN, and perform user presence to the HSK. Then you should have a successful login, as shown here:
```
$ ssh -l testuser -p 30222 52.116.156.203 
Warning: Permanently added '[52.116.156.203]:30222' (ED25519) to the list of known hosts.
######################################################
#
# This server requires SSH with a FIDO2 security key
#
######################################################
Confirm user presence for key ED25519-SK SHA256:buIw6WrE0mq6cDIieLzFKFb9s9272+eVGGKsZDh7PUM
Enter PIN for ED25519-SK key /Users/sweeden/.ssh/id_ed25519_sk:  <ENTER FIDO2 PIN FOR HSK HERE>
Confirm user presence for key ED25519-SK SHA256:buIw6WrE0mq6cDIieLzFKFb9s9272+eVGGKsZDh7PUM
<TOUCH HSK HERE>
User presence confirmed
Last login: Wed Jun 18 01:03:32 2025 from 10.176.226.76
[testuser@sshfido2 ~]$ 
```
The last prompt is me logged in to the image!

# Debugging tips

On a shell inside the container, you can see sshd logs with:
```
journalctl _COMM=sshd
```
or also try:
```
journalctl -u sshd
```

You can also configure sshd for debug logging by updating `/etc/ssh/sshd_config` to have:
```
LogLevel DEBUG3
```
Restart the sshd after doing this:
```
systemctl restart sshd
```
Use the above `journalctl -u sshd` command to see the debug output after attemptig ssh from a client, or combine it with `-f` to follow in real time while you attempt a client ssh:
```
journalctl -u sshd -f
```

If you ran the kubernetes setup, you should check that initialisation happened successfully:

```
kubectl exec -t sshfido2 -- systemctl status very-last
```

These steps are generally are enough to find common server-side problems.

From the client side, you can also run the ssh client in verbose mode with the `-vvv` switch, for example:
```
ssh -vvv -l testuser -p 30222 localhost
```
