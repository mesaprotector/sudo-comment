# sudo-comment
Prompt for comments after certain actions as root

Requires: ttyecho (https://github.com/osospeed/ttyecho).

Think of this as complementing tools like etckeeper that do versioning control for system files. This
doesn't do versioning control - instead, all it does is bug you for a comment/explanation *every 
time* certain commands are run through sudo. If you ever forgot why you installed a package, or ever
wondered why the hell you made that one-line change to /etc/bluetooth/main.conf, this tool might be
for you! 

Since it depends on sudo, it won't prompt when you're logged in as real root. But it (optionally)
will if you get a root shell with sudo -s or sudo -i (see below). 

The provided files are exactly what I use on my system (minus the license, I guess...). They include a
systemd service to monitor the sudo logfile using entr, and a config file geared towards Arch Linux with
pacman, bash as shell and vim as editor. However it should not be hard to get it to work on other
setups. For my setup, it's "feature-complete" (see issue #4).

With sudo alternatives like doas I'm not sure. It depends on their logging abilities. Would likely
require a major rewrite though.

You need to make a couple changes to the sudoers file for this to function:

Defaults logfile=/var/log/sudo.log (replace with your preferred path)

Defaults!/usr/bin/bash log_subcmds (replace with your preferred shell)

The second line above is to get sudo-comment to prompt even when editing files in a root shell
spawned with commands like sudo -i.

addcomment should be in $PATH, of course. If I ever package this I'll likely put waitcomment.sh in'
/usr/lib instead, as it should never be run manually.
