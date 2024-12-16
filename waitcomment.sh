#!/bin/bash
if [ "`/bin/id -u`" != "0" ]; then
    echo "Not running as root"
    exit
fi

# Sets working directories and sources config. Exits if mytmpdir is unset.
tmpdir="/tmp/sudo-comment"
. /etc/sudo-comment.conf
mkdir "$tmpdir" 2>/dev/null
mkdir "$tmpdir"/pts 2>/dev/null
for ((i=0;i<100;i++)); do
	if [ ! -d "$tmpdir/$i" ]; then
		mkdir "$tmpdir/$i"
		mytmpdir="$tmpdir/$i"
		break
	fi
done
if [ -z "$mytmpdir" ]; then 
	echo "Directory not set"
	exit
fi

# Grabs the last ten lines of the sudo logfile (my location) to tmpfile.
# Would be better to search from end of file but I don't know how to do that.
tail -n10 "$sudolog" > "$mytmpdir"/comment_pre.tmp
tac "$mytmpdir"/comment_pre.tmp | awk '!flag; /TTY/{flag = 1};' \
| tac > "$mytmpdir"/comment.tmp
rm "$mytmpdir"/comment_pre.tmp
curr_command="`grep -o "COMMAND=.*" "$mytmpdir"/comment.tmp`"

# Checks if there is more than one `COMMAND=` string in curr_command, which
# indicates that the last push to the sudo log was not associated with a device.
cmdcheck="`echo "$curr_command" | grep -Fo "COMMAND=" | wc -l`"
if [ "$cmdcheck" != "1" ]; then
	echo "Not a valid device, ignoring"
	rm "$mytmpdir"/comment.tmp
	rmdir "$mytmpdir"
	exit
fi 
curr_shell="`head -n1 "$mytmpdir"/comment.tmp | cut -d ';' -f 1-1 \
| grep -o TTY.* | cut -c 5- | tr -d ' '`"

# Creates a named pipe to communicate with addcomment process.
if [ -f "$tmpdir/$curr_shell" ]; then
	cat "$tmpdir/$curr_shell"
	echo "EXIT" > "$tmpdir/$curr_shell"
else
	mkfifo "$tmpdir/$curr_shell" 2>/dev/null
fi

# Parses config file options to pass to grep later, depending on usrbin_prepend.
if [ "$usrbin_prepend" = "yes" ]; then
	p_track="`printf '|%s' "${track[@]}" \
 	| sed 's/|/|COMMAND=\/usr\/bin\//g' | tail -c +2`"
	p_exclude="`printf '|%s' "${exclude[@]}" \
 	| sed 's/|/|COMMAND=\/usr\/bin\//g' | tail -c +2`"
else
	p_track="`printf '|%s' "${track[@]}" \
 	| sed 's/|/|COMMAND=/g' | tail -c +2`"
  	p_exclude="`printf '|%s' "${exclude[@]}" \
 	| sed 's/|/|COMMAND=/g' | tail -c +2`"
fi
p_shell="`printf '|%s' "${shell[@]}" | tail -c +2`"

# Tries to match run command to list in config file. `>` is included by default.
if grep -qE "$p_track|>" <<< "$curr_command"; then

	# Keeps sudo-comment from triggering itself in certain situations.
	# By default this includes all edits to tmpdir and the specific pacman
	# commands run by makepkg.
	if grep -qE -v "$p_exclude|$tmpdir" <<< "$curr_command"; then
		sleep 0.2
  
		# Waits until no processes running in foreground on given shell
		# except the shell itself.
		until [ "`ps ax | awk -v c_shell="$curr_shell" '$2 ~ c_shell' \
		| awk '$3 ~ /\+/' | awk '{print $5}' | grep -vE -e "\$p_shell" \
		|  wc -l`" = "0" ]
		do 
			sleep 0.1
		done
  
  		# addcomment normally runs unprivileged so these files need to be
		# world-writable.
		chmod 777 "$mytmpdir"
		chmod 666 "$mytmpdir"/comment.tmp
		chmod 666 "$tmpdir/$curr_shell"
  
		# Pushes `addcomment` with a newline to the shell.
		ttyecho -n /dev/"$curr_shell" 'addcomment'
  
		# Waits for pipe to be read, then waits on return traffic.
		echo "$mytmpdir" > "$tmpdir/$curr_shell"
		output="`cat "$tmpdir/$curr_shell"`"
  
		# Appends tmpfile to the comment log IF return traffic says to.
		if [ "$output" = "OK" ]; then
			cat "$mytmpdir"/comment.tmp >> "$commentlog"
		fi
	fi
fi

# Cleans up. If the process was made to exit by a duplicate process, don't
# delete the pipe.
rm "$mytmpdir"/comment.tmp
rmdir "$mytmpdir"
if [ "$output" != "EXIT" ]; then
	rm "$tmpdir/$curr_shell"
fi
