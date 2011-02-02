SHELL = /bin/sh
DESTDIR =
PREFIX = $(DESTDIR)/usr/local

execdir = $(PREFIX)/bin
datadir = $(PREFIX)/share
mandir = $(datadir)/man

PROGRAM = iot
SOURCES = iot.sh

rev = $(shell git rev-parse --short HEAD |  tr -d "\n")

all: $(PROGRAM)

$(PROGRAM): $(SOURCES)
	rm -f $@
	cat $(SOURCES) > $@+
	$(SHELL) -n $@+
	mv $@+ $@
	chmod 0755 $@

install: $(PROGRAM)
	install -d "$(execdir)"
	install -m 0755 $(PROGRAM) "$(execdir)/$(PROGRAM)"
	install -d "$(mandir)/man1"
	install -m 0644 man/$(PROGRAM).1 "$(mandir)/man1/$(PROGRAM).1"

uninstall:
	rm "$(execdir)/$(PROGRAM)"
	rm "$(mandir)/man1/$(PROGRAM).1"

run: all
	./$(PROGRAM)

clean:
	rm -f $(PROGRAM)

pages:
	shocco -t iot iot.sh > ../index.html
	ronn -br5 --organization='SCHEIBO' --manual='iot Manual' man/*.ronn
	cp man/*.html ..
	git checkout gh-pages
	mv ../*.html .
	git add *.html
	git commit -m "rebuild pages from '${rev}'"
	git push origin gh-pages
	git checkout master

docs:
	ronn -br5 --organization='SCHEIBO' --manual='iot Manual' man/*.ronn

shocco:
	shocco -t iot iot.sh > test.html

test:
	./iot --ROOTDIR='./tests' iot-runner iot-suite

.PHONY: run install uninstall pages docs shocco clean test
