---
title: "Apple SiliconのMacにCocoaPodsを導入してみる"
emoji: "📲"
type: "tech"
topics:
  - "firebase"
  - "swift"
  - "xcode"
  - "cocoapods"
  - "applesilicon"
published: true
published_at: "2021-11-10 02:40"
---

M1Macに買い替えて、久しぶりにSwift開発を行なっていたところ、CocoaPodsの導入に詰まりました。
今回は私が行った対処法と合わせて、Cocoapodsのインストール方法をご紹介します。

# 前提条件

- Apple Silicon搭載のMac(M1で動作確認済)
- Rosettaは使用しない。
- Macにデフォルトでインストールされているrubyを使用。（rbenv不要）
- CocoaPodsを使用する予定のプロジェクトをXcodeにて作成済み。

# インストール手順

### CocoaPodsをインストール

ターミナルを起動し、以下のコマンドを実行します。

```bash
sudo arch -x86_64 gem install cocoapods
```

`ポイント：arch -x86_64の記述を忘れずに！`

次に、以下のコマンドを実行します。

```bash
pod setup
```

```Setup completed```と表示されていれば成功です。

### Podfileを作成

ライブラリを導入したいXcodeプロジェクトのフォルダを、ターミナルで開きます。
（ターミナルの使い方がイマイチという方は、以下の記事を参考にしてみてください。）
https://www.webdesignleaves.com/pr/plugins/mac_terminal_basics_01.html#h3_index_13

プロジェクトファイルまで移動したら、以下のコマンドを実行します。

```bash
pod init
```

プロジェクトファイル内に```Podfile```が生成されます。

### 使用するライブラリを導入

Podfileを開き、編集します。（Vimを推奨）

今回私は、Firebaseを使いたいので以下のように記述しました。

```bash
  1 # Uncomment the next line to define a global platform for your project
  2 # platform :ios, '9.0'
  3 platform :ios, ‘10.0’
  4 
  5 target 'CloudShift' do
  6   # Comment the next line if you don't want to use dynamic frameworks
  7   use_frameworks!
  8   pod 'Firebase/Analytics'
  9   pod 'Firebase/Auth'
 10   pod 'Firebase/Firestore'
 11 
 12   # Pods for CloudShift
 13 
 14 end
 ```
 
Podfileの編集を終えたら、以下のコマンドを実行します。

```bash
arch -x86_64 pod install
```

`ポイント：arch -x86_64の記述を忘れずに！`

場合によっては少し時間がかかります。

# さいごに

インストールコマンドを実行する際に```arch -x86_64```を付けるということを覚えておいていただければ、問題なく導入できるかと思います。（2021/11/10現在）

今後のアップデートでネイティブ対応されるかと思いますので、しばらくはこの方法で、Intelモジュールを使用してインストールしましょう。
