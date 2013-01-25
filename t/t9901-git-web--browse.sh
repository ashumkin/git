#!/bin/sh
#

test_description='git web--browse basic tests

This test checks that git web--browse can handle various valid URLs.'

. ./test-lib.sh

test_web_browse () {
	# browser=$1 url=$2 sleep_timeout=$3
	sleep_timeout="$3"
	rm -f fake_browser_ran &&
	git web--browse --browser="$1" "$2" >actual &&
	# if $3 is set
	# as far as Firefox is run in background (it is run with &)
	# we trying to avoid race condition
	# by waiting for "$sleep_timeout" seconds of timeout for 'fake_browser_ran' file appearance
	if test -n "$sleep_timeout"
	then
	    for timeout in $(test_seq $sleep_timeout)
		do
			test -f fake_browser_ran && break
			sleep 1
		done
		test $timeout -ne $sleep_timeout
	fi &&
	tr -d '\015' <actual >text &&
	test_cmp expect text
}

test_expect_success \
	'URL with an ampersand in it' '
	echo http://example.com/foo\&bar >expect &&
	git config browser.custom.cmd echo &&
	test_web_browse custom http://example.com/foo\&bar
'

test_expect_success \
	'URL with a semi-colon in it' '
	echo http://example.com/foo\;bar >expect &&
	git config browser.custom.cmd echo &&
	test_web_browse custom http://example.com/foo\;bar
'

test_expect_success \
	'URL with a hash in it' '
	echo http://example.com/foo#bar >expect &&
	git config browser.custom.cmd echo &&
	test_web_browse custom http://example.com/foo#bar
'

test_expect_success \
	'browser paths are properly quoted' '
	echo fake: http://example.com/foo >expect &&
	write_script "fake browser" <<-\EOF &&
	echo fake: "$@"
	EOF
	chmod +x "fake browser" &&
	git config browser.w3m.path "$(pwd)/fake browser" &&
	test_web_browse w3m http://example.com/foo
'

test_expect_success \
	'Paths are properly quoted for Firefox. Version older then v2.0' '
	echo "fake: http://example.com/foo" >expect &&
	write_script "fake browser" <<-\EOF &&

	if test "$1" = "-version"; then
		echo "Fake Firefox browser version 1.2.3"
	else
		# Firefox (in contrast to w3m) is run in background (with &)
		# so redirect output to "actual"
		echo "fake: ""$@" >actual
	fi
	: >fake_browser_ran
	EOF
	git config browser.firefox.path "$(pwd)/fake browser" &&
	test_web_browse firefox http://example.com/foo 5
'

test_expect_success \
	'Paths are properly quoted for Firefox. Version v2.0 and above' '
	echo "fake: -new-tab http://example.com/foo" >expect &&
	write_script "fake browser" <<-\EOF &&

	if test "$1" = "-version"; then
		echo "Fake Firefox browser version 2.0.0"
	else
		# Firefox (in contrast to w3m) is run in background (with &)
		# so redirect output to "actual"
		echo "fake: ""$@" >actual
	fi
	: >fake_browser_ran
	EOF
	git config browser.firefox.path "$(pwd)/fake browser" &&
	test_web_browse firefox http://example.com/foo 5
'

test_expect_success \
	'browser command allows arbitrary shell code' '
	echo "arg: http://example.com/foo" >expect &&
	git config browser.custom.cmd "
		f() {
			for i in \"\$@\"; do
				echo arg: \$i
			done
		}
		f" &&
	test_web_browse custom http://example.com/foo
'

test_done
