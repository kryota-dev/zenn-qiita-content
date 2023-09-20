---
title: 'Googleカレンダーの予定を毎朝LINEに通知するGASを作ってみた'
emoji: '🗓️'
type: 'tech' # tech: 技術記事 / idea: アイデア
topics: ['gas', 'google', 'line']
published: true
---

## なぜ作ったのか

Google カレンダーに予定を入れているのですが、ずぼらな自分は予定を忘れてしまうことがあります 😅
なので、毎朝 LINE に予定を通知してくれるようなものがあれば便利だなと思い、作ってみました！

## 作ったもの

こんな感じです。
![](/images/articles/notify-gcal-to-line/image1.png)

## 使用サービス

- Google Apps Script
- Google カレンダー
- LINE Notify
- Todoist（自分はタスク管理をこれにしているので、一緒に通知してもらうようにしています）

## 事前準備

### LINE Notify

[LINE Notify にアクセスします。](https://notify-bot.line.me/my/)
アカウントを持っていない場合は、アカウントを作成してください。

ログイン後、アクセストークンを発行します。
自分は LINE のグループを作成し、LINE Notify を招待して、そのグループに通知を送るようにしています。

発行したアクセストークンは、後ほど使いますので、メモしておいてください。

### Google カレンダー

カレンダー ID を取得します。
カレンダー ID は、カレンダーの設定から確認できます。
![](/images/articles/notify-gcal-to-line/image2.png)
デフォルトカレンダーの場合は gmail のアドレスがカレンダー ID になります。
![](/images/articles/notify-gcal-to-line/image3.png)

### Google Apps Script

GAS プロジェクトを作成します（作成方法は自由）

プロジェクトを作成したら、左サイドバーの歯車アイコンをクリックし、プロジェクトのプロパティを開きます。

スクリプトプロパティに以下を追加します。

- `LINE_NOTIFY_ENDPOINT`
  - LINE Notify のエンドポイント
  - https://notify-api.line.me/api/notify
- `LINE_NOTIFY_PERSONAL_ACCESS_TOKEN`
  - 先ほど取得した LINE Notify のアクセストークン
- `MAIN_CALENDAR_ID`
  - 先ほど取得したカレンダー ID
- `TODOIST_CALENDER_ID`
  - Todoist のカレンダー ID

![](/images/articles/notify-gcal-to-line/image4.png)

これで準備は完了です！

## 実装

今回の完成コードは以下になります。

https://github.com/ryota-k0827/gcal-today-schedule-line-notify/blob/main/main.gs

関数ごとに説明していきます。

### main

メインの関数です。

まずは、トリガーを設定します。
（関数の説明は後述）

```js
setTrigger()
```

先ほどスクリプトプロパティに設定したカレンダー ID を取得し、定数に格納します。

```js
const MAIN_CALENDAR_ID = PropertiesService.getScriptProperties().getProperty('MAIN_CALENDAR_ID')
const TODOIST_CALENDAR_ID = PropertiesService.getScriptProperties().getProperty('TODOIST_CALENDAR_ID')
```

今日の日付を取得し、先ほど定数に格納したカレンダーIDを使用して、その日付のイベントを取得します。

```js
const now = new Date()
const mainEvents = CalendarApp.getCalendarById(MAIN_CALENDAR_ID).getEventsForDay(now)
const todoistEvents = CalendarApp.getCalendarById(TODOIST_CALENDAR_ID).getEventsForDay(now)
```

イベントの数とイベントのメッセージを生成する関数を呼び出します。
（関数の説明は後述）

```js
const {message: eventMessage, count: eventCount} = generateEventMessage(mainEvents, now)
const {message: todoMessage, count: todoCount} = generateEventMessage(todoistEvents, now)
```

イベントの数が 0 以上の場合は、LINE に通知を送ります。

```js
if (eventCount > 0 || todoCount > 0) {
  const message = `\n本日の予定をお知らせします（https://calendar.google.com/calendar/u/0/r/day）\n\n\`✅ToDo (${todoCount})\`\n${todoMessage}\n\n\`🗓️予定 (${eventCount})\`\n${eventMessage}`
  sendLineNotify(message)
}
```

### setTrigger, deleteAllTriggers

トリガーを設定する関数です。

```js
const setTrigger = () => {
  deleteAllTriggers()

  const time = new Date()

  time.setDate(time.getDate() + 1)
  time.setHours(8)
  time.setMinutes(0)
  time.setSeconds(0)
  ScriptApp.newTrigger('main').timeBased().at(time).create()
}
```

以下は、トリガーを削除する関数です。

```js
const deleteAllTriggers = () => {
  const allTriggers = ScriptApp.getProjectTriggers()
  allTriggers.forEach((trigger) => {
    ScriptApp.deleteTrigger(trigger)
  })
}
```

まず、トリガーを削除します。
前回設定したトリガーは1回限りの実行なので、削除しておきます。
（実際は既存のトリガー全て削除しています）

```js
deleteAllTriggers()
```

そして、次回の実行用トリガーを設定します。
（次回の実行は、翌日の朝8時になります）

```js
const time = new Date()

time.setDate(time.getDate() + 1)
time.setHours(8)
time.setMinutes(0)
time.setSeconds(0)
ScriptApp.newTrigger('main').timeBased().at(time).create()
```

### formatEvent

取得したイベントを整形する関数です。
終日イベントと、時間指定イベントで整形する内容が異なります。

```js
const formatEvent = (event, now) => {
  const timeZone = 'JST'
  const dateFormat = 'M/d'
  const dateTimeFormat = 'HH:mm'

  const startDateTime = event.getStartTime()
  const endDateTime = new Date(event.getEndTime().getTime() - 1) // Subtract 1 millisecond to account for Google Calendar's behavior
  const startDate = Utilities.formatDate(startDateTime, timeZone, dateFormat)
  const endDate = Utilities.formatDate(endDateTime, timeZone, dateFormat)
  const todayDate = Utilities.formatDate(now, timeZone, dateFormat)

  if (event.isAllDayEvent()) {
    if (startDate === endDate) {
      return `*All Day* : ${event.getTitle()}`
    } else {
      return `*All Day (${startDate} - ${endDate})* : ${event.getTitle()}`
    }
  } else {
    const adjustedEndDateTime = new Date(endDateTime.getTime() + 1)
    if (startDate === todayDate && startDate === endDate) {
      return `${Utilities.formatDate(startDateTime, timeZone, dateTimeFormat)} - ${Utilities.formatDate(
        adjustedEndDateTime,
        timeZone,
        dateTimeFormat
      )}: ${event.getTitle()}`
    } else {
      return `${Utilities.formatDate(startDateTime, timeZone, dateTimeFormat)} - ${endDate} ${Utilities.formatDate(
        adjustedEndDateTime,
        timeZone,
        dateTimeFormat
      )}: ${event.getTitle()}`
    }
  }
}
```

### generateEventMessage

イベントの数とイベントのメッセージを生成する関数です。
ここで、先ほど作成した`formatEvent`を使用して、イベントのメッセージを生成しています。

```js
const generateEventMessage = (events, now) => {
  let message = ''
  let count = 0

  events.forEach((event, index) => {
    message += formatEvent(event, now) + (index !== events.length - 1 ? '\n' : '')
    count++
  })

  return {message, count}
}
```

### sendLineNotify

LINE に通知を送る関数です。
先ほどスクリプトプロパティに設定した LINE Notify のエンドポイントとアクセストークンを使用して、通知を送ります。

```js
const sendLineNotify = (message) => {
  const LINE_NOTIFY_ENDPOINT = PropertiesService.getScriptProperties().getProperty('LINE_NOTIFY_ENDPOINT')
  const LINE_NOTIFY_PERSONAL_ACCESS_TOKEN = PropertiesService.getScriptProperties().getProperty(
    'LINE_NOTIFY_PERSONAL_ACCESS_TOKEN'
  )

  const options = {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${LINE_NOTIFY_PERSONAL_ACCESS_TOKEN}`,
    },
    payload: {
      message: message,
    },
  }

  UrlFetchApp.fetch(LINE_NOTIFY_ENDPOINT, options)
}
```

## トリガーの設定, 実行

初回のみ、手動で実行します。
次回以降は、トリガー関数によって自動で設定されます。
![](/images/articles/notify-gcal-to-line/image5.png)

実行すると、LINE に通知が送られます。
![](/images/articles/notify-gcal-to-line/image6.png)

Android の場合は、通知がこうなります。
（モバイル版のLINEは装飾が使えないので、装飾は無視されます）
![](/images/articles/notify-gcal-to-line/image7.png)

カレンダーの予定通りに通知が送られていることが確認できました！
![](/images/articles/notify-gcal-to-line/image8.png)

## まとめ

今回は、Google カレンダーの予定を毎朝 LINE に通知する GAS を作成しました。
終日イベントが扱いづらく、`formatEvent`関数の作成に少し苦労しましたが、無事に完成できました！
（最近予定がスカスカなので、通知が来ない日も多いですが...）

今回の成果物はGitHubに公開しています。
https://github.com/ryota-k0827/gcal-today-schedule-line-notify

以下のChrome拡張機能を使用すると、GASのコードを簡単にGitHubにアップロードできるので、便利です。
https://chrome.google.com/webstore/detail/google-apps-script-github/lfjcgcmkmjjlieihflfhjopckgpelofo?hl=ja

## 参考文献

繰り返しトリガーについて、こちらで詳しく説明されていました。
https://auto-worker.com/blog/?p=6383
