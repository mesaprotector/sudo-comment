#!/bin/bash
if [ "`/bin/id -u`" != "0" ]; then
    echo "Not running as root"
    exit
fi

# Sets working directories and sources config. Exits if mytmpdir is unset.
tmpdir="/tmp/sudo-comment"
source /etc/sudo-comment.conf
_tmpdir="`echo "$tmpdir" | sed -s 's/\/$//g'`"
tmpdir="$_tmpdir"
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
tail -n10 "$sudolog" > "$mytmpdir"/comment_pre.tmp
tac "$mytmpdir"/comment_pre.tmp | awk '!flag; /TTY/{flag = 1};' \
| tac > "$mytmpdir"/comment.tmp
rm "$mytmpdir"/comment_pre.tmp

# Grabs sections of the last log entry that will be used for checks.
curr_command="`grep -o "COMMAND=.*" "$mytmpdir"/comment.tmp | head -n 1`"
by_user="`head -n1 "$mytmpdir"/comment.tmp | cut -d ':' -f 4-4 \
| awk '{$1=$1;print}'`"
as_user="`grep -o "USER=.*" "$mytmpdir"/comment.tmp | head -n 1 \
| sed 's/ ;$//g' | tail -c +6`"

# Checks if the user who ran sudo, and the user they ran it as, are on the 
# tracking list.
p_by_user="`printf '|%s' "${run_by_user[@]}" | tail -c +2`"
p_as_user="`printf '|%s' "${run_as_user[@]}" | tail -c +2`"
if grep -qE -v "$p_by_user" <<< "$by_user"; then
	echo "User (by) not tracked, ignoring"
	rm "$mytmpdir"/comment.tmp
	rmdir "$mytmpdir"
	exit
fi
if grep -qE -v "$p_as_user" <<< "$as_user"; then
	echo "User (as) not tracked, ignoring"
	rm "$mytmpdir"/comment.tmp
	rmdir "$mytmpdir"
	exit
fi
 
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
  
  		# Create variables and files needed for formatting new entry.
		lines="`cat "$mytmpdir"/comment.tmp | wc -l`"
		sed '1s/^/@@ /' "$mytmpdir"/comment.tmp > "$mytmpdir"/head.tmp
		touch "$mytmpdir"/tail.tmp

		# addcomment normally runs unprivileged so these files need to
		# be world-writable. TODO: assign ownership to run_by_user or
		# run_as_user according to shell process.
		chmod 666 "$mytmpdir"/comment.tmp
		chmod 666 "$tmpdir/$curr_shell"
  
		# Pushes `addcomment` with a newline to the shell.
		ttyecho -n /dev/"$curr_shell" 'addcomment'
  
		# Waits for pipe to be read, then waits on return traffic.
		echo "$mytmpdir" > "$tmpdir/$curr_shell"
		output="`cat "$tmpdir/$curr_shell"`"
  
		# Appends tmpfile to the comment log IF return traffic says to.
		if [ "$output" = "OK" ]; then
			tail -n +$((lines+1)) "$mytmpdir"/comment.tmp \
			| fold -s > "$mytmpdir"/tail.tmp
			sed -i 's/^/# /2g' "$mytmpdir"/tail.tmp
			cat "$mytmpdir"/head.tmp "$mytmpdir"/tail.tmp > \
			"$mytmpdir"/comment.tmp
			cat "$mytmpdir"/comment.tmp >> "$commentlog"
		fi
	fi
fi

# Cleans up. If the process was made to exit by a duplicate process, don't
# delete the pipe.
rm "$mytmpdir"/head.tmp
rm "$mytmpdir"/tail.tmp
rm "$mytmpdir"/comment.tmp
rmdir "$mytmpdir"
if [ "$output" != "EXIT" ]; then
	rm "$tmpdir/$curr_shell"
fi
