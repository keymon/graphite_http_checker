#!/bin/sh

# TODO: 
# - close descriptor if needed
# - retry connect if connection to graphite drops? or exit
# 

WORKING_DIR=/tmp/http_checker
CONFIG_FILE=./config
GRAPHITE_PREFIX="http_tester"
GRAPHITE_HOST=localhost
GRAPHITE_PORT=2003

# IMPORTANT, METRIC_FREQUENCY should be more than TIMEOUT
METRIC_FREQUENCY=60
TIMEOUT=30

# Magic function... it just opens a TCP connection to graphite in descriptor 3
connect_graphite() {
	exec 3<>/dev/tcp/$GRAPHITE_HOST/$GRAPHITE_PORT
}

# Send the metrics to descriptor 3
send_metric() {
	#echo "local.random.diceroll 4 `date +%s`" | nc -q0 ${SERVER} ${PORT}
	echo "$GRAPHITE_PREFIX.$1 $2 `date +%s`" | tee /tmp/debug >&3
}

# Main checker
check_url() {
	id=$1; shift
	url=$1; shift
	data=$1; shift
	host=$(echo $url | sed 's|.*//||')

    if [ -z "$id" -o -z "$url" -o -z "$data" ]; then
    	echo "Wrong config syntax, some missing parameter: $id,$url,$data" >&2
    	return 0
    fi


	rm -f $WORKING_DIR/$id.output $WORKING_DIR/$id.headers $WORKING_DIR/$id.http_metrics $WORKING_DIR/$id.a_entries

	a_entries=$(host -t A $host 2> /dev/null | grep 'has address' | wc -l | awk '{print $1}')

	curl \
		--max-time $TIMEOUT \
		-s -o $WORKING_DIR/$id.output -D  $WORKING_DIR/$id.headers \
		-w "time_total=%{time_total}\\n" \
		$url > $WORKING_DIR/$id.http_metrics

	CURL_RET=$?


	[ "$CURL_RET" == 0 ] && \
		page_fetched=1 || \
		page_fetched=0

	test -e $WORKING_DIR/$id.output && \
		grep -q "$data" $WORKING_DIR/$id.output && \
			string_matched=1 || \
			string_matched=0

	[ "$page_fetched" == 1 -a "$string_matched" == 1 ] && \
		succeded=1 || 
		succeded=0


	total_time=$(test -e $WORKING_DIR/$id.http_metrics && cat $WORKING_DIR/$id.http_metrics | sed -n 's/^time_total=\([0-9\.]*\).*/\1/p')
	total_time=${total_time:-0}

	age=$(test -e $WORKING_DIR/$id.headers && cat $WORKING_DIR/$id.headers | sed -n 's/^Age: \([0-9\.]*\).*/\1/p')
	age=${age:-0}

	send_metric $id.page_fetched $page_fetched
	send_metric $id.string_matched $string_matched
	send_metric $id.succeded $succeded
	send_metric $id.total_time $total_time
	send_metric $id.a_entries $a_entries
	send_metric $id.age $age

}

mkdir -p $WORKING_DIR

# Start the connection to graphite
connect_graphite

# Loop endless
while true; do 
	# Spawn several threads for each line in config
	while IFS=, read id url data
	do           
		check_url "$id" "$url" "$data" &
	done < $CONFIG_FILE	
	# Wait for loop to adjust the metric frequency. Just a sleep in background
	sleep $METRIC_FREQUENCY &
	# wait for my friends the threads
	wait
done

