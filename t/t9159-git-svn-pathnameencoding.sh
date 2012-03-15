#!/bin/sh
#
# Copyright (c) 2011 Alexey Shumkin
#

# Don't run this test by default unless the user really wants it
# I don't like the idea of taking a port and possibly leaving a
# daemon running on a users system if the test fails.
# Not all git users will need to interact with SVN.

test_description='git svn svn.pathnameencoding '

. ./lib-git-svn.sh

export LC_ALL=russian

test_expect_success 'load svn dumpfile'  '
	svnadmin load "$rawsvnrepo" < "${TEST_DIRECTORY}/t9159/svn.cp1251.dump"
	'

test_expect_success 'clone using git svn' '
		git svn init "$svnrepo" x &&
		cd x &&
		git config svn.pathnameencoding cp1251 &&
		git config i18n.logOutputencoding cp1251 &&
		git config i18n.commitencoding cp1251 &&
		git config core.quotepath false &&
		git svn fetch
		'

test_expect_success 'test files under git control' '
		git ls-files | grep cp1251-�����/cp1251-����.txt
	'

test_expect_success 'test that "cp1251-�����" folder exists and contains file "cp1251-����"' '
		test -d cp1251-����� &&
		test -s cp1251-�����/cp1251-����.txt &&
		echo -e "\nadded line: ��������� ����� LC_ALL=$LC_ALL" >> cp1251-�����/cp1251-����.txt &&
		git commit -a -m "���� cp1251 �������" &&
		git svn dcommit
	' 

test_done
