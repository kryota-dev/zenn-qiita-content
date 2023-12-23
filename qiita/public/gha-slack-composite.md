---
title: GitHub Actionsで再利用可能なSlack通知アクションを作ってみた
private: false
tags:
  - githubactions
  - slack
updated_at: '2023-12-23T15:44:04+09:00'
id: null
organization_url_name: dip-net
slide: false
---

## はじめに

この記事は[ディップ Advent Calendar 2023](https://qiita.com/advent-calendar/2023/dip-dev)の23日目の投稿です。

私はフロントエンド課に所属しており、普段はHTML, SCSS, JavaScriptを使用してWebサイトの開発を行っています。

今回の記事では、業務効率化のために最近導入したGitHub Actionsについて紹介していきます。

## 概要

私の所属チームでは、GitHub Actionsで様々なワークフローを動かしています。

ほとんどのワークフローで、Slackの通知が飛ぶ処理を実装しているのですが、同じような処理を各ワークフローで都度実装しているという状態でした。
そこで、関数化みたいなことをして複数のワークフローで使いまわせるようにしたいなと思い調べたところ、Composite Actionsというものを見つけて、いい感じにやりたいことを実現できたので、今回はそちらを紹介していきます。

## 前提

今回はGitHub Enterprise Serverの環境下で、Ubuntuのセルフホステッドランナーを使用して動作するように作成しています。

GitHub CloudやGitHubが提供しているランナーで実装する場合は、`GITHUB_TOKEN`やランナーの指定を変更する必要がありますので、適宜読み替えてください。

## Composite Actionsとは？

別名で「複合アクション」とも呼ばれています。

ワークフローのstepを別ファイルに切り出すことで、複数のワークフローで再利用することが可能となっている機能です。

プログラミング言語で関数を扱うような感じで、Composite Actionsでは`inputs`と`outputs`を活用して、引数と戻り値を受け渡しすることも可能となっています。

## 成果物

今回作成したComposite Actionsは、以下のディレクトリ構成になっています。

```tree
.github/actions/
└── slack
    ├── post-message
    │   ├── failure
    │   │   └── action.yml
    │   └── success
    │       └── action.yml
    └── search-thread-message
        └── action.yml
```

## 実装

### ワークフローの実行成功時にSlackへ通知するAction

スレッド投稿を行いたい場面があるので、`chat.postMessage`を使用しています。

```yml:slack/post-message/success/action.yml
name: Slackに通知（成功）
description: Slackに通知（成功）

inputs:
  slack-channel-id:
    description: SlackのチャンネルID
    required: true
  slack-bot-oauth-token:
    description: SlackのBotのOAuth Token
    required: true
  slack-chat-post-message-url:
    description: Slackのchat.postMessageのURL
    required: true
  slack-color:
    description: Slackの通知色
    required: false
    default: good  # good, warning, danger, or any hex color code (eg. #439FE0)
  slack-title:
    description: Slackのメッセージタイトル
    required: false
    default: '*<@${{ github.actor }}> workflowの実行に成功しました*'
  slack-message:
    description: Slackのメッセージ
    required: false
    default: 以下のリンクから実行結果をご確認ください\n${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
  slack-thread-ts:
    description: Slackのスレッドのts
    required: false
    default: 'null'
  slack-reply-broadcast:
    description: Slackのスレッド投稿をチャンネルにも投稿
    required: false
    default: 'false'

runs:
  using: "composite"
  steps:
    - id: slack-post-message-success
      shell: bash
      run: |
        SLACK_DATA=$(cat <<EOF
        {
        $(if [ "${{ inputs.slack-thread-ts }}" != "null" ]; then
          echo "  \"thread_ts\": \"${{ inputs.slack-thread-ts }}\","
          echo "  \"reply_broadcast\": \"${{ inputs.slack-reply-broadcast }}\","
        fi)
          "channel": "${{ inputs.slack-channel-id }}",
          "attachments": [
            {
              "fallback": "${{ inputs.slack-title }}",
              "pretext": "${{ inputs.slack-title }}",
              "color": "${{ inputs.slack-color }}",
              "author_name": "${GITHUB_REPOSITORY#${GITHUB_REPOSITORY_OWNER}/}",
              "author_link": "${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}",
              "text": "${{ inputs.slack-message }}",
            }
          ]
        }
        EOF
        )
        curl -X POST \
          -H 'Content-type: application/json' \
          -H "Authorization: Bearer ${{ inputs.slack-bot-oauth-token }}" \
          --data "${SLACK_DATA}" \
          "${{ inputs.slack-chat-post-message-url }}"
```

#### inputs

値の受け渡しが必須なものには`required: true`を指定し、
逆に必須でないものには`required: false`と`defalt:`にデフォルト値を指定しています。

```yml
# 必須
slack-channel-id:
    description: SlackのチャンネルID
    required: true

# 任意
slack-color:
    description: Slackの通知色
    required: false
    default: good  # good, warning, danger, or any hex color code (eg. #439FE0)
```

#### runs

ワークフローで`jobs`に記述していた処理を、`runs`に記述します。
`using: "composite"`を宣言しておくことで、Composite Actionsとして使用できるようになります。

```yml
runs:
  using: "composite"  # Composite Actionsとして宣言
  steps:
    ...
```

#### steps

`steps`では、シェルスクリプトを記述する際に`shell: bash`という形で、
シェルの種類を宣言しておく必要があります。

```yml
steps:
  - id: slack-post-message-success
    shell: bash  # シェルの種類を宣言
    run: |
      ...
```

### ワークフローの実行失敗時にSlackに通知するAction

失敗時はスレッド投稿を行わずに通知を行うため、`webhook`を使用しています。

```yml:slack/post-message/failure/action.yml
name: Slackに通知（失敗）
description: Slackに通知（失敗）

inputs:
  slack-webhook-url:
    description: SlackのWebhook URL
    required: true
  slack-color:
    description: Slackの通知色
    required: false
    default: danger # good, warning, danger, or any hex color code (eg. #439FE0)
  slack-title:
    description: Slackのメッセージタイトル
    required: false
    default: '*<@${{ github.actor }}> workflowの実行に失敗しました*'
  slack-message:
    description: Slackのメッセージ
    required: false
    default: 以下のリンクから実行結果をご確認ください\n${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}

runs:
  using: "composite"
  steps:
    - id: slack-post-message-failure
      shell: bash
      run: |
        SLACK_DATA=$(cat <<EOF
          {
            "attachments": [
              {
                "fallback": "${{ inputs.slack-title }}",
                "pretext": "${{ inputs.slack-title }}",
                "color": "${{ inputs.slack-color }}",
                "author_name": "${GITHUB_REPOSITORY#${GITHUB_REPOSITORY_OWNER}/}",
                "author_link": "${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}",
                "text": "${{ inputs.slack-message }}",
              }
            ]
          }
        EOF
        )
        curl -X POST -H 'Content-type: application/json' --data "${SLACK_DATA}" "${{ inputs.slack-webhook-url }}"
```

### Slackのスレを検索し、thread_tsを取得するAction

スレッド投稿を行う際に、`thread_ts`を取得する必要があるため、
`inputs`で検索条件を受け取り、`outputs`でtsを返すようにしています。

> `thread_ts`とは、スレッドごとに割り振られる一意の値です。
> 投稿時に`thread_ts`を指定することで、スレッドに投稿することができます。

```yml:slack/search-thread-message/action.yml
name: Slackのスレッドメッセージを検索
description: Slackのスレッドメッセージを検索

inputs:
  slack-channel-id:
    description: SlackのチャンネルID
    required: true
  slack-user-oauth-token:
    description: SlackのユーザーのOAuth Token
    required: true
  slack-search-messages-url:
    description: Slackのsearch.messagesのURL
    required: true
  query-param:
    description: 検索クエリパラメータ
    required: true

outputs:
  slack-thread-ts:
    description: Slackのスレッドのts
    value: ${{ steps.slack-search-thread-message.outputs.slack-thread-ts }}

runs:
  using: "composite"
  steps:
    - id: slack-search-thread-message
      shell: bash
      run: |
        SEARCH_QUERY="in:<#${{ inputs.slack-channel-id }}> ${{ inputs.query-param }}"
        MAX_RETRIES=3
        RETRY_COUNT=0
        TS=null
        while [[ $TS == null && $RETRY_COUNT -lt $MAX_RETRIES ]]; do
          SEARCH_RESPONSE=$(curl -s "${{ inputs.slack-search-messages-url }}" \
            -H "Authorization: Bearer ${{ inputs.slack-user-oauth-token }}" \
            -d "query=$SEARCH_QUERY" \
            -d "sort=timestamp" \
            -d "sort_dir=asc" \
            -d "count=1")
          TS=$(echo $SEARCH_RESPONSE | jq -r '.messages.matches[0].ts')
          if [[ $TS == null ]]; then
            echo "スレッドが見つかりませんでした。3秒後に再検索します"
            RETRY_COUNT=$((RETRY_COUNT + 1))
            sleep 3
          fi
        done
        if [[ $TS != null ]]; then
          echo "slack-thread-ts=$TS" >> $GITHUB_OUTPUT
        else
          echo "スレッドが見つかりませんでした"
          echo "slack-thread-ts=null" >> $GITHUB_OUTPUT
        fi
```

### ワークフローでの使用例

PRのイベントをトリガーに、Slackに通知するワークフローです。

弊社の場合、GitHubのユーザーIDとSlackのユーザーIDが同一であるため`<@${{ github.actor }}>`という形でメンションを飛ばしています。
GitHubのユーザーIDがメールアドレスのドメインより前の部分である場合に、このような形でメンションを飛ばすことができます。

```yml
name: PRのイベントをSlackに通知

on:
  pull_request:
    types: [opened, ready_for_review, reopened, closed]

env:
  GH_ENTERPRISE_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  GH_HOST: ${{ secrets.GH_HOST }}
  PR_NUMBER: ${{ github.event.pull_request.number }}
  PR_LINK: ${{ github.event.pull_request.html_url }}
  PR_ACTION: ${{ github.event.action }}

jobs:
  pr-events:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      - name: PRのレビュアーを取得
        id: get-reviewers
        if: ${{ env.PR_ACTION != 'closed' }}
        run: |
          gh_output=$(gh pr view ${{ env.PR_NUMBER }} --json reviewRequests -q '.reviewRequests[].login')
          if [ -z "$gh_output" ]; then
            echo "reviewers=" >> $GITHUB_OUTPUT
          else
            echo "reviewers=$(echo "$gh_output" | awk '{print "<@" $0 ">"}' | tr '\n' ' ')" >> $GITHUB_OUTPUT
          fi
      #-- 以下Slack通知 --#
      - name: Slackのスレッドメッセージを検索
        id: search-thread-message
        uses: ./.github/actions/slack/search-thread-message
        with:
          slack-channel-id: ${{ secrets.SLACK_CHANNEL_ID }}
          slack-user-oauth-token: ${{ secrets.SLACK_USER_OAUTH_TOKEN }}
          slack-search-messages-url: ${{ secrets.SLACK_SEARCH_MESSAGES_URL }}
          query-param: ${{ env.PR_LINK }}
      - name: Slackのメッセージを作成
        id: create-slack-message
        if: ${{ success() }}
        run: |
          SLACK_TITLE=""
          SLACK_MESSAGE="PR作成者: <@${{ github.actor }}>\n以下のリンクからPRを確認してください\n${{ env.PR_LINK }}"
          REPLY_BROADCAST="false"
          if [ "${{ env.PR_ACTION }}" = "ready_for_review" ] || [ "${{ env.PR_ACTION }}" = "opened" ]; then
            SLACK_TITLE="${{ steps.get-reviewers.outputs.reviewers }}*PRがオープンされました*"
            REPLY_BROADCAST="true"
          elif [ "${{ env.PR_ACTION }}" = "reopened" ]; then
            SLACK_TITLE="${{ steps.get-reviewers.outputs.reviewers }}*PRが再オープンされました*"
            REPLY_BROADCAST="true"
          elif [ "${{ env.PR_ACTION }}" = "closed" ]; then
            if [ "${{ github.event.pull_request.merged }}" = "true" ]; then
              SLACK_TITLE="*PRがマージされました*"
            else
              SLACK_TITLE="*PRがクローズされました*"
            fi
            SLACK_MESSAGE="作業者: <@${{ github.actor }}>\n${{ env.PR_LINK }}"
          fi
          echo "slack-title=${SLACK_TITLE}" >> $GITHUB_OUTPUT
          echo "slack-message=${SLACK_MESSAGE}" >> $GITHUB_OUTPUT
          echo "reply-broadcast=${REPLY_BROADCAST}" >> $GITHUB_OUTPUT
      - name: Slackに通知（成功）
        if: ${{ success() }}
        uses: ./.github/actions/slack/post-message/success
        with:
          slack-channel-id: ${{ secrets.SLACK_CHANNEL_ID }}
          slack-bot-oauth-token: ${{ secrets.SLACK_BOT_OAUTH_TOKEN }}
          slack-chat-post-message-url: ${{ secrets.SLACK_CHAT_POST_MESSAGE_URL }}
          slack-title: ${{ steps.create-slack-message.outputs.slack-title }}
          slack-message: ${{ steps.create-slack-message.outputs.slack-message }}
          slack-thread-ts: ${{ steps.search-thread-message.outputs.slack-thread-ts }}
          slack-reply-broadcast: ${{ steps.create-slack-message.outputs.reply-broadcast }}
      - name: Slackに通知（失敗）
        if: ${{ failure() }}
        uses: ./.github/actions/slack/post-message/failure
        with:
          slack-webhook-url: ${{ secrets.SLACK_WEBHOOK_URL }}
```

#### id

Composite Actionsのoutputsを参照する際に、ワークフロー側で`id`を指定する必要があります。

```yml
- name: Slackのスレッドメッセージを検索
  id: search-thread-message # idを指定
  uses: ./.github/actions/slack/search-thread-message
  ...
- name: Slackに通知（成功）
  if: ${{ success() }}
  uses: ./.github/actions/slack/post-message/success
  with:
    ...
    slack-thread-ts: ${{ steps.search-thread-message.outputs.slack-thread-ts }} # outputsを参照
    ...
```

#### uses

リポジトリのルートディレクトリからの相対パスで指定することができます。

```yml
uses: ./.github/actions/slack/post-message/success
```

#### if

`if`を使用することで、条件に応じてステップの実行を制御することができます。

```yml
- name: Slackに通知（成功）
  if: ${{ success() }}  # 成功時のみ実行
  uses: ./.github/actions/slack/post-message/success
  with:
    ...
- name: Slackに通知（失敗）
  if: ${{ failure() }}  # 失敗時のみ実行
  uses: ./.github/actions/slack/post-message/failure
  with:
    ...
```

## 実行結果

作成したComposite Actionsを使用したワークフローの実行結果です。

### ワークフローの実行成功時にSlackへ通知するAction

PRのDraftを作成した際に投稿されるスレッドに投稿しています。

![](https://raw.githubusercontent.com/ryota-k0827/zenn-content/main/images/articles/gha-slack-composite/image1.png)

### ワークフローの実行失敗時にSlackに通知するAction

![](https://raw.githubusercontent.com/ryota-k0827/zenn-content/main/images/articles/gha-slack-composite/image2.png)

## まとめ

今回はComposite Actionsを使用して、GitHub Actionsで再利用可能なSlack通知アクションを作成してみました。
Composite Actionsを使用することで、メンテナンス性の高いワークフローを作成することができるようになるので、ぜひ活用してみてください。

https://docs.github.com/ja/actions/creating-actions/creating-a-composite-action
