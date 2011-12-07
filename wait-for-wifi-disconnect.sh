#!/bin/sh -x
function exit_on_string() {
	TXT=
	while ! echo ${TXT} | grep -q $1
	do
		read TXT
		echo "Line: ${TXT}"
	done
	killall dbus-monitor
	exit 0
}

dbus-monitor --system interface=fi.epitest.hostap.WPASupplicant.Interface,member=StateChange | exit_on_string '"DISCONNECTED"'
exit 0
