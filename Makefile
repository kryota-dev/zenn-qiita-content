init: update preview

install:
	pnpm install

update:
	pnpm install zenn-cli@latest

preview:
	npx zenn preview -p 8000 --open

new/article:
	npx zenn new:article

new/book:
	npx zenn new:book

list/articles:
	npx zenn list:articles

list/books:
	npx zenn list:books

version:
	npx zenn -v

help:
	npx zenn -h

guide/cli:
	open https://zenn.dev/zenn/articles/zenn-cli-guide

guide/md:
	open https://zenn.dev/zenn/articles/markdown-guide