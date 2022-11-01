.PHONY: install
install:
	npm install

.PHONY: update
update:
	npm install zenn-cli@latest

.PHONY: preview
preview:
	npx zenn preview -p 8000 --open

.PHONY: new/article
new/article:
	npx zenn new:article

.PHONY: new/book
new/book:
	npx zenn new:book

.PHONY: list/articles
list/articles:
	npx zenn list:articles

.PHONY: list/books
list/books:
	npx zenn list:books

.PHONY: version
version:
	npx zenn -v

.PHONY: help
help:
	npx zenn -h

.PHONY: guide/cli
guide/cli:
	open https://zenn.dev/zenn/articles/zenn-cli-guide

.PHONY: guide/md
guide/md:
	open https://zenn.dev/zenn/articles/markdown-guide