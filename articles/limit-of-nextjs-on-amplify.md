---
title: "AWS Amplifyで動かすNext.jsの限界"
emoji: "😵"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ['nextjs', 'amplify', 'aws']
published: true
---

## はじめに

この記事は[ディップ Advent Calendar 2024](https://qiita.com/advent-calendar/2024/dip-dev)の12日目の投稿です。

2023年にディップへ新卒入社しました、[@ryotaneko827](https://x.com/ryotaneko827) と申します。
総合求人情報サイト「[はたらこねっと](https://www.hatarako.net/)」のフロントエンド開発を中心に行っており、
2024年5月からは新規メディア「[はたらこマガジン](https://www.hatarako.net/magazine/)」の開発も兼任しています。

## 背景

Next.jsで開発したアプリケーションをAmplifyにデプロイした際に、
いくつかの制約と不具合に直面したので、その内容を共有します。

これからNext.jsで開発を行う方や、Amplifyを検討している方にとって参考になれば幸いです。

## この記事のターゲット

- Next.js (App Router)で開発を行っている方
- AWS上にデプロイを検討している方

## はたらこマガジンの技術スタック

はたらこマガジンは、以下の技術スタックで開発を行っています。

### フロントエンド

- Next.js v14 (App Router)
- Node.js v22

### バックエンド

- microCMS

### インフラ

- AWS Amplify Hosting

## 限界1: SSRモードデプロイする際のビルドサイズに制限がある

Next.jsは通常、SSRアプリケーションとして動作します。
しかし、AmplifyがSSRアプリでサポートしているビルドの最大出力サイズは**220MB**です。

https://docs.aws.amazon.com/ja_jp/amplify/latest/userguide/troubleshooting-SSR.html#build-output-too-large

この制限を超えると、ビルドが失敗してしまいます。
`generateStaticParams`などを利用して、ビルド時に静的生成させたい場面があるかも
しれませんが、220MBを超えないように注意が必要です。

### 実際に発生した問題

#### `generateStaticParams`を利用したらビルドサイズが大きくなった

ビルド時にmicroCMSからデータを取得し、全ての記事を静的生成するように設定しました。
しかし、記事数が増えるにつれてビルドサイズが大きくなり、リリース前の時点で既に220MBを超えてしまいました。

検索ページや、記事のプレビューページではSSRを利用したいため、SSGアプリには移行できませんでした。

## 限界2: App Routerのキャッシュが正しく機能しない

Next.jsには、オンデマンドでキャッシュを再検証できる機能があります。

https://nextjs.org/docs/14/app/building-your-application/caching

しかし、Amplify Hostingではこの機能が正しく機能しません。

https://docs.aws.amazon.com/ja_jp/amplify/latest/userguide/troubleshooting-SSR.html#on-demand-isr-not-supported

### 実際に発生した問題

#### `revalidatePath`が効かない

Route Handlerを利用して、`revalidatePath('/', 'layout')`を実行できるエンドポイントを作成しました。

https://nextjs.org/docs/14/app/api-reference/functions/revalidatePath#revalidating-all-data

しかし、エンドポイントを叩くとキャッシュが消去されるのですが、数分後に再度キャッシュが復活してしまう現象が発生しました。

## 対処法

### キャッシュを無効化する

Next.js v14のApp Routerで開発したアプリケーションをAmplifyにデプロイする際は、
layout.tsxに以下のコードを追加して、キャッシュを無効化することをおすすめします。

:::message
Next.js v15以降では、`fetch()`はデフォルトでキャッシュを無効化するようになりました。
https://nextjs.org/blog/our-journey-with-caching
:::

```tsx:app/layout.tsx
export const fetchCache = 'force-no-store'
export const dynamic = 'force-dynamic'
```

https://nextjs.org/docs/14/app/api-reference/file-conventions/route-segment-config#dynamic

https://nextjs.org/docs/14/app/api-reference/file-conventions/route-segment-config#fetchcache

### SSGアプリとしてデプロイする

ビルド時に全てのデータを取得できる場合は、Static Exportsを利用して、SSGアプリとしてデプロイすることも検討してみてください。

```ts:next.config.mjs
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'export',
  ...
}
```

https://nextjs.org/docs/14/app/building-your-application/deploying/static-exports

以下の記事が参考になります。

https://developers.play.jp/entry/2023/11/06/085943

## はたらこマガジンにおける今後の課題

現在は[キャッシュを無効化する](#キャッシュを無効化する)方法を採用しているため、ページの表示速度が遅くなってしまっています。

改善策として、以下の方法を検討しています。

- 脱Amplify Hosting
  - ECSもしくはS3 + CloudFrontで運用する
- SSGアプリとしてAmplify Hostingにデプロイする
  - ビルド時に静的生成できないページは、API GatewayもしくはCSRで対応する

## まとめ

Amplify Hostingは、インフラ環境の構築やデプロイの簡便さが魅力ですが、
実運用レベルでNext.jsを利用する際には、いくつかの制約があることを理解しておく必要があります。

ビルドの最大出力サイズは、もう少し大きくしてほしいです...。
