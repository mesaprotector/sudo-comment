#!/bin/bash
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "Not running as root"
    exit
fi
# Sets up working directories and sources config. Should exit if $mytmpdir is unset.
tmpdir="/tmp/sudo-comment"
source /usr/local/etc/sudo-comment.conf
mkdir $tmpdir 2>/dev/null
mkdir $tmpdir/pts 2>/dev/null
for ((i=0;i<100;i++)); do
	if [ ! -d $tmpdir/$i ]; then
		mkdir $tmpdir/$i
		mytmpdir="$tmpdir/$i"
		break
	fi
done
if [ -z $mytmpdir ]; then 
	exit 1
fi
# Grabs the last ten lines of the sudo logfile (my location) to tmpfile.
# Would be better to search from end of file but I don't know how to do that.
tail -n10 /var/log/sudo.log > $mytmpdir/comment3.tmp
tac $mytmpdir/comment3.tmp | awk '!flag; /TTY/{flag = 1};' | tac > $mytmpdir/comment2.tmp
rm $mytmpdir/comment3.tmp
curr_command="$(grep -o COMMAND=.* $mytmpdir/comment2.tmp)"
curr_shell="$(head -n1 $mytmpdir/comment2.tmp | cut -c 31-35)"
# Creates a named pipe to communicate with 'child' addcomment process. Completely unnecessary
# but I've never used named pipes before and thought I might as well learn how.
mkfifo $tmpdir/$curr_shell
# List of commands to be commented. Can be customized. Will soon be grabbed from config file rather than this mess. 
if grep -qE '=/usr/bin/visudo|=/usr/bin/vim|=/usr/bin/rm|=/usr/bin/rmdir|=/usr/bin/mkdir|=/usr/bin/trash-put|=/usr/bin/cp|=/usr/bin/touch|=/usr/bin/mv|=/usr/bin/chmod|=/usr/bin/chown|=/usr/bin/chgrp|=/usr/bin/systemctl edit|=/usr/bin/pacman -S |=/usr/bin/pacman -R|>' <<< $curr_command; then
	# Keeps sudo-comment from triggering itself in certain situations.
 	# The pacman exclusions are to prevent makepkg from triggering this, because it causes problems (makepkg doesn't maintain a foreground process being that it's a 
  	# shell script calling pacman several times). Use -Run for manual removals instead if you normally remove packages with -Rnu.
	if grep -qE -v 'comment.tmp|comment2.tmp|comment3.tmp|changed.tmp|pacman -Rnu|pacman -S --asdeps' <<< $curr_command; then
		sleep 0.2
		# Waits until no processes running in foreground on given shell except bash or sudo. Causes some problems with files named bash (ex. /etc/bash.bashrc). Should use something
		# other than grep but I'll figure it out later.
		until [ `ps ax | grep -v "bash" | grep -v "sudo -s" | grep -v "sudo -i" | awk '$3 ~ /\+/' | awk -v shell=$curr_shell '$2 ~ shell' | wc -l` == 0 ]
		do 
			sleep 0.1
		done
  		cat $mytmpdir/comment2.tmp > $mytmpdir/comment.tmp
		chmod 666 $mytmpdir/comment.tmp
		chmod 666 $tmpdir/$curr_shell
		# Pushes "addcomment" with a newline to the shell.
		ttyecho -n /dev/$curr_shell 'addcomment'
		# Waits until addcomment reads pipe, then waits for return traffic.
  		echo $mytmpdir > $tmpdir/$curr_shell
		output=`cat $tmpdir/$curr_shell`
		# Appends tmpfile to the comment log IF return traffic says to.
		if [ $output = "OK" ]; then
			cat $mytmpdir/comment.tmp >> /var/log/comment.log
		fi
		rm $mytmpdir/comment.tmp
	fi
fi	
rm $mytmpdir/comment2.tmp
rmdir $mytmpdir
rm $tmpdir/$curr_shell
