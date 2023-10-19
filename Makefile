init: update preview

install:
	bun install

update:
	bun install zenn-cli@latest

preview:
	bunx zenn preview -p 8000 --open

new/article:
	bunx zenn new:article

new/book:
	bunx zenn new:book

list/articles:
	bunx zenn list:articles

list/books:
	bunx zenn list:books

version:
	bunx zenn -v

help:
	bunx zenn -h

guide/cli:
	open https://zenn.dev/zenn/articles/zenn-cli-guide

guide/md:
	open https://zenn.dev/zenn/articles/markdown-guide