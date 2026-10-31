// 日本語フォント（Noto Sans JP）を、アプリが使う文字だけに切り出して同梱する。
//
//   cd tools/font && npm install
//   node build_jp_font.mjs <NotoSansJP[wght].ttf のパス>
//
// なぜ同梱するか: Flutter Web は漢字のフォントを持たず、画面を描いてから
// Google Fonts へ取りに行く。その数秒のあいだ漢字が □ で出ていた。
// 使う文字だけなら 1 太さ数百 KB で済むので、最初から持たせる。
//
// 文字は lib/ の Dart と assets/levels の JSON から集める（文言やステージ名を
// 足したら、このスクリプトを流し直す）。かなと記号は今後の文言のために丸ごと入れる。
// 英数字と基本の記号（U+2190 より前）は入れない。ここを入れると、タイルの数字まで
// このフォントで描かれて見た目が変わる。それらは今までどおり Flutter 既定の Roboto で描く。
// 元のフォントは game-assets の math-puzzle/font-src/ にある。

import { readFileSync, readdirSync, statSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import subsetFont from 'subset-font';

const here = dirname(fileURLToPath(import.meta.url));
const app = join(here, '..', '..', 'number_puzzle');
const outDir = join(app, 'assets', 'fonts');

/** 使っている太さ。app_theme.dart などの FontWeight と揃える。 */
const WEIGHTS = [400, 700, 800];

const src = process.argv[2];
if (!src) {
  console.error('使い方: node build_jp_font.mjs <NotoSansJP[wght].ttf>');
  process.exit(1);
}

function walk(dir, exts, out = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, exts, out);
    else if (exts.some((e) => name.endsWith(e))) out.push(p);
  }
  return out;
}

const chars = new Set();
const addRange = (from, to) => {
  for (let c = from; c <= to; c++) chars.add(String.fromCodePoint(c));
};
addRange(0x3000, 0x303f); // 和文の記号（、。「」など）
addRange(0x3040, 0x309f); // ひらがな
addRange(0x30a0, 0x30ff); // カタカナ
addRange(0xff01, 0xff5e); // 全角英数・記号
for (const file of [...walk(join(app, 'lib'), ['.dart']), ...walk(join(app, 'assets', 'levels'), ['.json'])]) {
  for (const ch of readFileSync(file, 'utf8')) {
    if (ch.codePointAt(0) >= 0x2190 && ch !== '\uFEFF') chars.add(ch);
  }
}
const text = [...chars].join('');

const font = readFileSync(src);
mkdirSync(outDir, { recursive: true });
for (const wght of WEIGHTS) {
  const out = await subsetFont(font, text, { targetFormat: 'sfnt', variationAxes: { wght } });
  const path = join(outDir, `NotoSansJP-${wght}.ttf`);
  writeFileSync(path, out);
  console.log(`${path}  ${(out.length / 1024).toFixed(0)} KB`);
}
console.log(`文字数: ${chars.size}`);
