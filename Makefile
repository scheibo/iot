pages:
	set -e
	echo "Rebuilding pages"
	rev=$(git rev-parse --short HEAD |  tr -d "\n")
	shocco -t iot iot > ../index.html+
	git checkout gh-pages
	mv ../index.hmtl+ .
	rm index.html
	mv index.html+ index.html
	git add index.html
	git commit -m "rebuild pages from ${rev}"
	git push origin gh-pages


