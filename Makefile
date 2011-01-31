rev = $(shell git rev-parse --short HEAD |  tr -d "\n")
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
