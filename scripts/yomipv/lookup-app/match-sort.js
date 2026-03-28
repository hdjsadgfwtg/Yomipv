/**
 * Matched-length sorting helpers for dictionary entry ranking.
 * Algorithm must stay in sync with api/match_sort.lua
 */

/**
 * Katakana → Hiragana normalization.
 * Covers U+30A1..U+30FA (ァ‥ヺ), including ヴヵヶヷヸヹヺ
 * @param {string} s
 * @returns {string}
 */
const toHiragana = (s) => {
  let r = '';
  for (const c of s) {
    const cp = c.codePointAt(0);
    r += (cp >= 0x30A1 && cp <= 0x30FA) ? String.fromCodePoint(cp - 0x60) : c;
  }
  return r;
};

/**
 * Strip parenthetical annotations: 食べる（たべる） → 食べる
 * @param {string} s
 * @returns {string}
 */
const stripParens = (s) => s.replace(/\s*[\(（].*?[\)）]\s*/g, '');

/**
 * Common prefix length between two strings (already normalized).
 * @param {string[]} a - array of characters
 * @param {string[]} b - array of characters
 * @returns {number}
 */
const prefixMatchLen = (a, b) => {
  const n = Math.min(a.length, b.length);
  let i = 0;
  while (i < n && a[i] === b[i]) i++;
  return i;
};

/**
 * Normalize a string into an array of hiragana-normalized characters.
 * @param {string} s
 * @returns {string[]}
 */
const toNormalizedChars = (s) => [...toHiragana(s)];

/**
 * Compute match score: max prefix match of term against expr and reading (kana-normalized).
 * Compares against both expression (handles kanji lookup) and reading (handles kana lookup).
 * @param {string[]} termChars - pre-computed normalized chars of the lookup term
 * @param {string} expr
 * @param {string} reading
 * @returns {number}
 */
const computeMatchedLen = (termChars, expr, reading) => {
  const exprChars = toNormalizedChars(stripParens(expr));
  let best = prefixMatchLen(termChars, exprChars);

  if (reading && reading !== expr) {
    const readingChars = toNormalizedChars(stripParens(reading));
    const r = prefixMatchLen(termChars, readingChars);
    if (r > best) best = r;
  }

  return best;
};

module.exports = { toHiragana, stripParens, toNormalizedChars, computeMatchedLen };
