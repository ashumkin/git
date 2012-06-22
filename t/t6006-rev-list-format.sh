#!/bin/sh

# Copyright (c) 2009 Jens Lehmann
# Copyright (c) 2011 Alexey Shumkin (+ non-UTF-8 commit encoding tests)

test_description='git rev-list --pretty=format test'

. ./test-lib.sh

test_tick
added=$(printf "added (\320\264\320\276\320\261\320\260\320\262\320\273\320\265\320\275) foo")
added_cp1251=$(echo "$added" | iconv -f utf-8 -t cp1251)
changed=$(printf "changed (\320\264\320\276\320\261\320\260\320\262\320\273\320\265\320\275) foo")
changed_cp1251=$(echo "$changed" | iconv -f utf-8 -t cp1251)

test_expect_success 'setup' '
	touch foo &&
	git add foo &&
	git config i18n.commitEncoding cp1251 &&
	git commit -m "$added_cp1251" &&
	head1=$(git rev-parse --verify HEAD) &&
	head1_7=$(echo $head1 | cut -c1-7) &&
	echo "$changed" > foo &&
	git commit -a -m "$changed_cp1251" &&
	head2=$(git rev-parse --verify HEAD) &&
	head2_7=$(echo $head2 | cut -c1-7) &&
	tree2=$(git cat-file -p HEAD | grep tree | cut -f 2 -d" ") &&
	tree2_7=$(echo $tree2 | cut -c1-7) &&
	head2_parent=$(git cat-file -p HEAD | grep parent | cut -f 2 -d" ") &&
	head2_parent_7=$(echo $head2_parent | cut -c1-7) &&
	git config --unset i18n.commitEncoding
'

# usage: test_format name format_string <expected_output
test_format() {
	local must_fail=0
	# if parameters count is more than 2 then test must fail
	if [ $# -gt 2 ]; then
		must_fail=1
		# remove first parameter which is flag for test failure
		shift
	fi
	cat >expect.$1
	name="format $1"
	command="git rev-list --pretty=format:'$2' master >output.$1 &&
test_cmp expect.$1 output.$1"
	if [ $must_fail -eq 1 ]; then
		test_expect_failure "$name" "$command"
	else
		test_expect_success "$name" "$command"
	fi
}

test_format percent %%h <<EOF
commit $head2
%h
commit $head1
%h
EOF

test_format hash %H%n%h <<EOF
commit $head2
$head2
$head2_7
commit $head1
$head1
$head1_7
EOF

test_format tree %T%n%t <<EOF
commit $head2
$tree2
$tree2_7
commit $head1
4d5fcadc293a348e88f777dc0920f11e7d71441c
4d5fcad
EOF

test_format parents %P%n%p <<EOF
commit $head2
$head1
$head2_parent_7
commit $head1


EOF

# we don't test relative here
test_format author %an%n%ae%n%ad%n%aD%n%at <<EOF
commit $head2
A U Thor
author@example.com
Thu Apr 7 15:13:13 2005 -0700
Thu, 7 Apr 2005 15:13:13 -0700
1112911993
commit $head1
A U Thor
author@example.com
Thu Apr 7 15:13:13 2005 -0700
Thu, 7 Apr 2005 15:13:13 -0700
1112911993
EOF

test_format committer %cn%n%ce%n%cd%n%cD%n%ct <<EOF
commit $head2
C O Mitter
committer@example.com
Thu Apr 7 15:13:13 2005 -0700
Thu, 7 Apr 2005 15:13:13 -0700
1112911993
commit $head1
C O Mitter
committer@example.com
Thu Apr 7 15:13:13 2005 -0700
Thu, 7 Apr 2005 15:13:13 -0700
1112911993
EOF

test_format failure encoding %e <<EOF
commit $head2
commit $head1
EOF

expected=$(printf "commit $head2\n\
$changed\n\
commit $head1\n\
$added
")

test_format failure subject %s <<EOF
$expected
EOF

test_format body %b <<EOF
commit $head2
commit $head1
EOF

expected=$(printf "commit $head2\n\
$changed\n\
\n\
commit $head1\n\
$added
")

test_format failure raw-body %B <<EOF
$expected

EOF

test_format colors %Credfoo%Cgreenbar%Cbluebaz%Cresetxyzzy <<EOF
commit $head2
[31mfoo[32mbar[34mbaz[mxyzzy
commit $head1
[31mfoo[32mbar[34mbaz[mxyzzy
EOF

test_format advanced-colors '%C(red yellow bold)foo%C(reset)' <<EOF
commit $head2
[1;31;43mfoo[m
commit $head1
[1;31;43mfoo[m
EOF

iconv -f utf-8 -t cp1251 > commit-msg <<EOF
Test printing of complex bodies

This commit message is much longer than the others,
and it will be encoded in cp1251. We should therefore
include an cp1251 character: так вот!
EOF

test_expect_success 'setup complex body' '
	git config i18n.commitencoding cp1251 &&
	echo change2 >foo && git commit -a -F commit-msg &&
	head3=$(git rev-parse --verify HEAD) &&
	head3_7=$(echo $head3 | cut -c1-7)
'

test_format complex-encoding %e <<EOF
commit $head3
cp1251
commit $head2
cp1251
commit $head1
cp1251
EOF

# unset commit encoding config
# otherwise %e does not print encoding value
# and following test fails
git config --unset i18n.commitencoding

expected=$(printf "commit $head3\n\
Test printing of complex bodies\n\
commit $head2\n\
$changed\n\
commit $head1\n\
$added
")

test_format failure complex-subject %s <<EOF
$expected
EOF

test_format failure complex-body %b <<EOF
commit $head3
This commit message is much longer than the others,
and it will be encoded in cp1251. We should therefore
include an cp1251 character: так вот!

commit $head2
commit $head1
EOF

test_expect_success '%x00 shows NUL' '
	echo  >expect commit $head3 &&
	echo >>expect fooQbar &&
	git rev-list -1 --format=foo%x00bar HEAD >actual.nul &&
	nul_to_q <actual.nul >actual &&
	test_cmp expect actual
'

test_expect_success '%ad respects --date=' '
	echo 2005-04-07 >expect.ad-short &&
	git log -1 --date=short --pretty=tformat:%ad >output.ad-short master &&
	test_cmp expect.ad-short output.ad-short
'

test_expect_success 'empty email' '
	test_tick &&
	C=$(GIT_AUTHOR_EMAIL= git commit-tree HEAD^{tree} </dev/null) &&
	A=$(git show --pretty=format:%an,%ae,%ad%n -s $C) &&
	test "$A" = "A U Thor,,Thu Apr 7 15:14:13 2005 -0700" || {
		echo "Eh? $A" >failure
		false
	}
'

test_expect_success 'del LF before empty (1)' '
	git show -s --pretty=format:"%s%n%-b%nThanks%n" HEAD^^ >actual &&
	test_line_count = 2 actual
'

test_expect_success 'del LF before empty (2)' '
	git show -s --pretty=format:"%s%n%-b%nThanks%n" HEAD >actual &&
	test_line_count = 6 actual &&
	grep "^$" actual
'

test_expect_success 'add LF before non-empty (1)' '
	git show -s --pretty=format:"%s%+b%nThanks%n" HEAD^^ >actual &&
	test_line_count = 2 actual
'

test_expect_success 'add LF before non-empty (2)' '
	git show -s --pretty=format:"%s%+b%nThanks%n" HEAD >actual &&
	test_line_count = 6 actual &&
	grep "^$" actual
'

test_expect_success 'add SP before non-empty (1)' '
	git show -s --pretty=format:"%s% bThanks" HEAD^^ >actual &&
	test $(wc -w <actual) = 3
'

test_expect_success 'add SP before non-empty (2)' '
	git show -s --pretty=format:"%s% sThanks" HEAD^^ >actual &&
	test $(wc -w <actual) = 6
'

test_expect_success '--abbrev' '
	echo SHORT SHORT SHORT >expect2 &&
	echo LONG LONG LONG >expect3 &&
	git log -1 --format="%h %h %h" HEAD >actual1 &&
	git log -1 --abbrev=5 --format="%h %h %h" HEAD >actual2 &&
	git log -1 --abbrev=5 --format="%H %H %H" HEAD >actual3 &&
	sed -e "s/$_x40/LONG/g" -e "s/$_x05/SHORT/g" <actual2 >fuzzy2 &&
	sed -e "s/$_x40/LONG/g" -e "s/$_x05/SHORT/g" <actual3 >fuzzy3 &&
	test_cmp expect2 fuzzy2 &&
	test_cmp expect3 fuzzy3 &&
	! test_cmp actual1 actual2
'

test_expect_success '%H is not affected by --abbrev-commit' '
	git log -1 --format=%H --abbrev-commit --abbrev=20 HEAD >actual &&
	len=$(wc -c <actual) &&
	test $len = 41
'

test_expect_success '%h is not affected by --abbrev-commit' '
	git log -1 --format=%h --abbrev-commit --abbrev=20 HEAD >actual &&
	len=$(wc -c <actual) &&
	test $len = 21
'

test_expect_success '"%h %gD: %gs" is same as git-reflog' '
	git reflog >expect &&
	git log -g --format="%h %gD: %gs" >actual &&
	test_cmp expect actual
'

test_expect_success '"%h %gD: %gs" is same as git-reflog (with date)' '
	git reflog --date=raw >expect &&
	git log -g --format="%h %gD: %gs" --date=raw >actual &&
	test_cmp expect actual
'

test_expect_success '"%h %gD: %gs" is same as git-reflog (with --abbrev)' '
	git reflog --abbrev=13 --date=raw >expect &&
	git log -g --abbrev=13 --format="%h %gD: %gs" --date=raw >actual &&
	test_cmp expect actual
'

test_expect_success '%gd shortens ref name' '
	echo "master@{0}" >expect.gd-short &&
	git log -g -1 --format=%gd refs/heads/master >actual.gd-short &&
	test_cmp expect.gd-short actual.gd-short
'

test_expect_success 'reflog identity' '
	echo "C O Mitter:committer@example.com" >expect &&
	git log -g -1 --format="%gn:%ge" >actual &&
	test_cmp expect actual
'

test_expect_success 'oneline with empty message' '
	git commit -m "dummy" --allow-empty &&
	git commit -m "dummy" --allow-empty &&
	git filter-branch --msg-filter "sed -e s/dummy//" HEAD^^.. &&
	git rev-list --oneline HEAD >test.txt &&
	test_line_count = 5 test.txt &&
	git rev-list --oneline --graph HEAD >testg.txt &&
	test_line_count = 5 testg.txt
'

test_expect_success 'single-character name is parsed correctly' '
	git commit --author="a <a@example.com>" --allow-empty -m foo &&
	echo "a <a@example.com>" >expect &&
	git log -1 --format="%an <%ae>" >actual &&
	test_cmp expect actual
'

test_done
