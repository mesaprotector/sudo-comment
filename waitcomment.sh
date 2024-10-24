#!/bin/bash
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "Not running as root"
    exit
fi
# Grabs the last ten lines of the sudo logfile (my location) to tmpfile.
# Would be better to search from end of file but I don't know how to do that.
tail -n10 /var/log/sudo.log > /tmp/comment.tmp
tac /tmp/comment.tmp | awk '!flag; /TTY/{flag = 1};' | tac > /tmp/comment2.tmp
cat /tmp/comment2.tmp > /tmp/comment.tmp
rm /tmp/comment2.tmp
curr_command="$(grep -o COMMAND=.* /tmp/comment.tmp)"
curr_shell="$(head -n1 /tmp/comment.tmp | cut -c 31-36)"
# List of commands to be commented. Can be customized. There's definitely a more elegant way to do this. 
if grep -qE '=/usr/bin/visudo|=/usr/bin/vim|=/usr/bin/rm|=/usr/bin/rmdir|=/usr/bin/mkdir|=/usr/bin/trash-put|=/usr/bin/cp|=/usr/bin/touch|=/usr/bin/mv|=/usr/bin/chmod|=/usr/bin/chown|=/usr/bin/pacman -S |=/usr/bin/pacman -R|>' <<< $curr_command; then
	# Keeps sudo-comment from triggering itself in certain situations.
	if grep -qE -v 'comment.tmp|changed.tmp' <<< $curr_command; then
		sleep 0.2
		# Waits until no processes running in foreground on given shell except bash or sudo. Causes some problems with files named bash (ex. /etc/bash.bashrc). Should use something
		# other than grep but I'll figure it out later.
		until [ `ps ax | grep -v "bash" | grep -v "sudo -s" | grep -v "sudo -i" | awk '$3 ~ /\+/' | awk -v shell=$curr_shell '$2 ~ shell' | wc -l` == 0 ]
		do 
			sleep 0.1
		done
		chmod 666 /tmp/comment.tmp
		# Pushes "addcomment" with a newline to the shell.
		ttyecho -n /dev/$curr_shell 'addcomment'
		# Waits until addcomment has exited.
		until [ `ps ax | grep "addcomment" | awk '$3 ~ /\+/' | awk -v shell=$curr_shell '$2 ~ shell' | wc -l` == 0 ]
		do
			sleep 0.1
		done
		# Appends tmpfile to the comment log IF changed.tmp exists.
		if test -f "/tmp/changed.tmp"; then
			cat /tmp/comment.tmp >> /var/log/comment.log
			rm /tmp/changed.tmp
		fi
	fi
else
fi
rm /tmp/comment.tmp
