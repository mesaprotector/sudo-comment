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
tail -n10 $sudolog > $mytmpdir/comment_pre.tmp
tac $mytmpdir/comment_pre.tmp | awk '!flag; /TTY/{flag = 1};' | tac > $mytmpdir/comment.tmp
rm $mytmpdir/comment_pre.tmp
curr_command="$(grep -o COMMAND=.* $mytmpdir/comment.tmp)"
curr_shell="$(head -n1 $mytmpdir/comment.tmp | cut -c 31-35)"
# Creates a named pipe to communicate with 'child' addcomment process.
if [ -f $tmpdir/$curr_shell ]; then
	cat $tmpdir/$curr_shell
	echo "EXIT" > $tmpdir/$curr_shell
else
	mkfifo $tmpdir/$curr_shell
fi
# Parses config file options to pass to grep later.
p_track=`printf '%s|' "|${track[@]}" | head -c -2 | sed 's/|/|COMMAND=\/usr\/bin\//g' | tail -c +2`
p_exclude=`printf '%s|' "|${exclude[@]}" | head -c -2 | sed 's/|/|COMMAND=\/usr\/bin\//g' | tail -c +2`
p_shell=`printf '%s|' "${shell[@]}" | head -c -1`
# Tries to match run command to list in config file. ">" is included by default.
if grep -qE "$p_track|>" <<< $curr_command; then
	# Keeps sudo-comment from triggering itself in certain situations.
	# By default this includes all edits to $tmpdir and the specific pacman commands run by makepkg.
	if grep -qE -v "$p_exclude|$tmpdir" <<< $curr_command; then
		sleep 0.2
		# Waits until no processes running in foreground on given shell except the shell itself.
  		until [ `ps ax | awk -v c_shell=$curr_shell '$2 ~ c_shell' | awk '$3 ~ /\+/' | awk '{print $5}' | grep -vE -e "\$p_shell" |  wc -l` == 0 ]
		do 
			sleep 0.1
		done
  		# addcomment runs (normally) as user so these files need be to world-writable.
		chmod 666 $mytmpdir/comment.tmp
		chmod 666 $tmpdir/$curr_shell
		ttyecho -n /dev/$curr_shell 'addcomment'
		echo $mytmpdir > $tmpdir/$curr_shell
		output=`cat $tmpdir/$curr_shell`
		if [ $output = "OK" ]; then
			cat $mytmpdir/comment.tmp >> $commentlog
		fi
		# Pushes "addcomment" with a newline to the shell.
		ttyecho -n /dev/$curr_shell 'addcomment'
		# Waits until addcomment reads pipe, then waits for return traffic.
  		echo $mytmpdir > $tmpdir/$curr_shell
		output=`cat $tmpdir/$curr_shell`
		# Appends tmpfile to the comment log IF return traffic says to.
		if [ $output = "OK" ]; then
			cat $mytmpdir/comment.tmp >> $commentlog
		fi
	fi
fi
# Cleans up. If the process was made to exit by a duplicate process, don't delete the pipe.
rm $mytmpdir/comment.tmp
rmdir $mytmpdir
if [ $output != "EXIT" ]; then
	rm $tmpdir/$curr_shell
fi
