bi := bun install
bxz := bunx zenn
bxq := bunx qiita
q-dir := ./qiita/
q-credential := --credential $(q-dir)
q-config := --config $(q-dir)
q-root := --root $(q-dir)


init: install z/update q/update

install:
	$(bi)


# Zenn scripts
z/guide/cli:
	open https://zenn.dev/zenn/articles/zenn-cli-guide

z/guide/md:
	open https://zenn.dev/zenn/articles/markdown-guide

z/help:
	$(bxz) -h

z/list/articles:
	$(bxz) list:articles

z/list/books:
	$(bxz) list:books

z/new/article:
	$(bxz) new:article

z/new/book:
	$(bxz) new:book

z/preview:
	$(bxz) preview -p 8000 --open

z/update:
	$(bi) zenn-cli@latest

z/version:
	$(bxz) -v


# Qiita scripts
q/help:
	$(bxq) help

q/login:
	$(bxq) login $(q-credential) $(q-config)

q/new:
	$(bxq) new $(title) --root $(q-dir)

q/preview:
	$(bxq) preview $(q-credential) $(q-config) $(q-root)

q/publish:
	$(bxq) publish $(title) $(q-root)

q/publish/all:
	$(bxq) publish --all

q/pull:
	$(bxq) pull

q/update:
	$(bi) @qiita/qiita-cli@latest

q/version:
	$(bxq) version
