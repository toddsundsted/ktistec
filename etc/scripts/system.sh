# This is a simple shell script that logs system stats to the server
# log.  Output to STDOUT is logged at severity INFO.
#
# To enable this script, make it executable.
#
echo "Disk usage: $(df . | awk 'END {print $4 " free out of " $2 " (" $5 " used)"}')"
