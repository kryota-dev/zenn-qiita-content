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

# FIXME: コマンドの順序をアルファベット順にする（ChatGPTのお仕事）
# Zenn scripts
z/update:
	$(bi) zenn-cli@latest

z/preview:
	$(bxz) preview -p 8000 --open

z/new/article:
	$(bxz) new:article

z/new/book:
	$(bxz) new:book

z/list/articles:
	$(bxz) list:articles

z/list/books:
	$(bxz) list:books

z/version:
	$(bxz) -v

z/help:
	$(bxz) -h

z/guide/cli:
	open https://zenn.dev/zenn/articles/zenn-cli-guide

z/guide/md:
	open https://zenn.dev/zenn/articles/markdown-guide

# Qiita scripts
q/update:
	$(bi) @qiita/qiita-cli@latest

q/preview:
	$(bxq) preview $(q-credential) $(q-config) $(q-root)

q/new:
	$(bxq) new $(title) --root $(q-dir)

q/publish:
	$(bxq) publish $(title) $(q-root)

q/publish/all:
	$(bxq) publish --all

q/login:
	$(bxq) login $(q-credential) $(q-config)

q/version:
	$(bxq) version

q/help:
	$(bxq) help

q/pull:
	$(bxq) pull
