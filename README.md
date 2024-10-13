# sudo-comment
Prompt for comments after certain actions as root

Requires: ttyecho (https://github.com/osospeed/ttyecho).

Requires: entr (https://github.com/eradman/entr). Could probably use inotify instead just fine.

I use systemd, bash, and vim, but it could definitely be rewritten for other setups without too many changes.
With sudo alternatives like doas I'm not sure. It depends on their logging abilities.
You need to make a couple changes to the sudoers file for this to function:

Defaults logfile=/var/log/sudo.log (replace with your preferred path)

Defaults!/usr/bin/bash log_subcmds

The second line above is to get sudo-comment to prompt even when I am editing files under a root shell spawned with sudo -s
or sudo -i.

addcomment and waitcomment should be under /usr/local/bin.
