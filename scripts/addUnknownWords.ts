// CSpellの辞書に存在しない単語を自動で一括追加するスクリプト
import { execSync } from 'child_process'
import fs from 'fs'
import path from 'path'

// 1. Get the unknown words
const result = execSync('bun check:spell 2>&1 | grep "Unknown word" | awk \'{print $NF}\'', { encoding: 'utf8' })
const unknownWords = result
  .split('\n')
  .filter(Boolean)
  .map((word) => word.replace(/^\(|\)$/g, '')) // Remove surrounding ()

// Check if unknown words exist
if (unknownWords.length === 0) {
  console.log('No unknown words detected.')
  process.exit()
}

// 2. Add words to cspell.json
const cspellPath = path.join(process.cwd(), 'cspell.json')
let config

// Check if cspell.json exists
if (fs.existsSync(cspellPath)) {
  config = JSON.parse(fs.readFileSync(cspellPath, 'utf8'))
} else {
  config = { words: [] }
}

// Update the words in config
config.words = Array.from(new Set([...config.words, ...unknownWords]))

// Save the updated config
fs.writeFileSync(cspellPath, JSON.stringify(config, null, 4), 'utf8')

console.log(`Added ${unknownWords.length} unknown words to cspell.json.`)
