rev = $(shell git rev-parse --short HEAD |  tr -d "\n")
pages:
	set -e
	shocco -t iot iot > ../index.html
	git checkout gh-pages
	mv ../index.html .
	git add index.html
	git commit -m "rebuild pages from '${rev}'"
	git push origin gh-pages
	git checkout master
