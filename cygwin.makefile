# build on Cygwin
SDIR := $(shell cd $(dir $(firstword $(MAKEFILE_LIST))) && pwd)
GVF := $(SDIR)/GIT-VERSION-FILE
DEF_DESTDIR := $(SDIR)/.build
DESTDIR ?= $(DEF_DESTDIR)
ifeq ($(OS),Windows_NT)
	prefix=/usr
else
	# on Linux use /usr/local
	prefix=/usr/local
endif
libexec=$(prefix)/lib
CONFIG_FLAGS=--with-libpcre
INSTALL=install

GIT-VERSION-FILE: make-version FORCE
	@$(SHELL_PATH) ./GIT-VERSION-GEN
-include GIT-VERSION-FILE

.PHONY: FORCE

all : config make-all make-bundle

apt-cyg-deps:
	apt-cyg install -u asciidoc docbook-xml42 openssl-devel xmlto-devel w32api

config : GIT-VERSION-FILE
	$(SDIR)/configure --prefix=$(prefix) --libexec=$(libexec) $(CONFIG_FLAGS)

config-and-make : config make-only

config-and-install : config-and-make make-install

make-only :
	make all && make man

make :
	make all && make install && make man && make install-doc

make-dest :
	make install install-doc DESTDIR="$(DESTDIR)"

make-install:
	make install install-doc

make-bundles : make-dest strip completion jump subtree bzip

make-all : make make-dest

make-version : FORCE
	$(shell git describe | cut -f 1,2 -d - > version)

strip :
	find $(DESTDIR) -iname '*.exe' -print -exec strip {} \;

COMPLETION_DIR := $(DESTDIR)/etc/bash_completion.d/
completion :
	mkdir -p $(COMPLETION_DIR)
	$(INSTALL) -v -m 0644 $(SDIR)/contrib/completion/{git-completion.bash,git-prompt.sh} -t $(COMPLETION_DIR)

install-completion :
	$(INSTALL) -v -m 0644 $(SDIR)/contrib/completion/{git-completion.bash,git-prompt.sh} -t /etc/bash_completion.d/

jump :
	$(INSTALL) -v -m 0755 $(SDIR)/contrib/git-jump/git-jump -t $(DESTDIR)$(libexec)/git-core

install-jump :
	$(INSTALL) -v -m 0755 $(SDIR)/contrib/git-jump/git-jump -t $(libexec)/git-core

subtree :
	$(MAKE) -C contrib/subtree install DESTDIR="$(DESTDIR)"

install-subtree :
	$(MAKE) -C contrib/subtree install

bzip : bzip-main bzip-gui bzip-gitk bzip-completion bzip-svn bzip-jump bzip-subtree

# remove leading slash from $(prefix)
BZIP_PREFIX := $(patsubst /%,%,$(prefix))
TAR_BZ_SUFFIX = -1.tar.bz2
TAR_BZ_FULL_SUFFIX = $(GIT_VERSION)$(TAR_BZ_SUFFIX)

bzip-main:
	tar --directory $(DESTDIR) --verbose --bzip2 --create --file git-$(TAR_BZ_FULL_SUFFIX) usr etc
bzip-gui:
	gzip -c $(DESTDIR)$(prefix)/share/man/man1/git-gui.1 > $(DESTDIR)$(prefix)/share/man/man1/git-gui.1.gz
	tar --directory $(DESTDIR) --verbose --bzip2 --create --file git-gui-$(TAR_BZ_FULL_SUFFIX) $(BZIP_PREFIX)/{share/{git-gui,man/man1/git-gui.1.gz},lib/git-core/git-gui{,--askpass}}
bzip-gitk:
	gzip -c $(DESTDIR)$(prefix)/share/man/man1/gitk.1 > $(DESTDIR)$(prefix)/share/man/man1/gitk.1.gz
	tar --directory $(DESTDIR) --verbose --bzip2 --create --file gitk-$(TAR_BZ_FULL_SUFFIX) $(BZIP_PREFIX)/{bin/gitk,share/{gitk,man/man1/gitk.1.gz}}
bzip-completion:
	tar -C $(DESTDIR) --verbose --bzip2 --create --file git-completion-$(TAR_BZ_FULL_SUFFIX) etc/bash_completion.d
bzip-svn:
	gzip -c $(DESTDIR)$(prefix)/share/man/man1/git-svn.1 > $(DESTDIR)$(prefix)/share/man/man1/git-svn.1.gz
	tar --directory $(DESTDIR) --verbose --bzip2 --create --file git-svn-$(TAR_BZ_FULL_SUFFIX) $(BZIP_PREFIX)/{lib/git-core/git-svn,share/man/man1/git-svn.1.gz}
bzip-jump:
	tar --directory $(DESTDIR) --verbose --bzip2 --create --file git-jump-$(TAR_BZ_FULL_SUFFIX) $(BZIP_PREFIX)/lib/git-core/git-jump
bzip-subtree:
	tar --directory $(DESTDIR) --verbose --bzip2 --create --file git-subtree-$(TAR_BZ_FULL_SUFFIX) $(BZIP_PREFIX)/lib/git-core/git-subtree
