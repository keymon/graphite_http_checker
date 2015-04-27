#!/bin/sh

WORKING_DIR=/tmp/http_checker

TIMEOUT=30

check_url() {
	id=$1; shift
	url=$1; shift
	data=$1; shift
	host=$(echo $url | sed 's|.*//||')

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

	echo "page_fetched $page_fetched"
	echo "string_matched $string_matched"
	echo "succeded $succeded"
	echo "total_time $total_time"
	echo "a_entries $a_entries"
	echo "age $age"


}

#check_url datasift_main http://localhost:8080 "View live example streams to see how DataSift"
#check_url datasift_main http://datasift.com "View live example streams to see how DataSift"
check_url datasift_main http://datasift.com "SNA enables Dell to monitor"
mkdir -p $WORKING_DIR
