---
title: 'Googleカレンダーの予定を毎朝LINEに通知するGASを作ってみた'
emoji: '🗓️'
type: 'tech' # tech: 技術記事 / idea: アイデア
topics: ['gas', 'google', 'line']
published: false
---

## なぜ作ったのか

Google カレンダーに予定を入れているのですが、ずぼらな自分は予定を忘れてしまうことがあります 😅
なので、毎朝 LINE に予定を通知してくれるようなものがあれば便利だなと思い、作ってみました！

## 作ったもの

こんな感じです。
![](/images/9e9edd7d76ff7b/image1.png)

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
![](/images/9e9edd7d76ff7b/image2.png)
デフォルトカレンダーの場合は gmail のアドレスがカレンダー ID になります。
![](/images/9e9edd7d76ff7b/image3.png)

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

![](/images/9e9edd7d76ff7b/image4.png)

これで準備は完了です！

## 実装

今回の完成コードは以下になります。

```js
const main = () => {
  setTrigger()

  const MAIN_CALENDAR_ID = PropertiesService.getScriptProperties().getProperty('MAIN_CALENDAR_ID')
  const TODOIST_CALENDAR_ID = PropertiesService.getScriptProperties().getProperty('TODOIST_CALENDAR_ID')

  const now = new Date()
  const mainEvents = CalendarApp.getCalendarById(MAIN_CALENDAR_ID).getEventsForDay(now)
  const todoistEvents = CalendarApp.getCalendarById(TODOIST_CALENDAR_ID).getEventsForDay(now)

  let eventMessage = ''
  let eventCount = 0
  mainEvents.forEach((event, index) => {
    eventMessage += formatEvent(event, now) + (index !== mainEvents.length - 1 ? '\n' : '')
    eventCount++
  })

  let todoMessage = ''
  let todoCount = 0
  todoistEvents.forEach((event, index) => {
    todoMessage += formatEvent(event, now) + (index !== todoistEvents.length - 1 ? '\n' : '')
    todoCount++
  })

  if (eventCount > 0 || todoCount > 0) {
    const message = `\n本日の予定をお知らせします（https://calendar.google.com/calendar/u/0/r/day）\n\n\`✅ToDo (${todoCount})\`\n${todoMessage}\n\n\`🗓️予定 (${eventCount})\`\n${eventMessage}`
    sendLineNotify(message)
  }
}

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

/**
 * Trigger Function
 */
const setTrigger = () => {
  deleteAllTriggers()

  const time = new Date()

  time.setDate(time.getDate() + 1)
  time.setHours(8)
  time.setMinutes(0)
  time.setSeconds(0)
  ScriptApp.newTrigger('main').timeBased().at(time).create()
}

const deleteAllTriggers = () => {
  const allTriggers = ScriptApp.getProjectTriggers()
  allTriggers.forEach((trigger) => {
    ScriptApp.deleteTrigger(trigger)
  })
}
```

関数ごとに説明していきます。

### main

メインの関数です。

まずは、トリガーを設定します（後述）

次に、先ほどスクリプトプロパティに設定したカレンダー ID を取得し、定数に格納します。

```js
const MAIN_CALENDAR_ID = PropertiesService.getScriptProperties().getProperty('MAIN_CALENDAR_ID')
const TODOIST_CALENDAR_ID = PropertiesService.getScriptProperties().getProperty('TODOIST_CALENDAR_ID')
```

次に、今日の日付を取得し、その日付のイベントを取得します。

```js
const now = new Date()
const mainEvents = CalendarApp.getCalendarById(MAIN_CALENDAR_ID).getEventsForDay(now)
const todoistEvents = CalendarApp.getCalendarById(TODOIST_CALENDAR_ID).getEventsForDay(now)
```
