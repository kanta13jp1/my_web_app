export function compare(expected, response, calls) {
 const marks=expected.trim().split(/\s+/).filter(Boolean);
 if(!marks.length||new Set(marks).size!==marks.length)throw new Error('期待する識別文字列を重複なく入力してください。');
 if(!Number.isSafeInteger(calls)||calls<0)throw new Error('ツール呼出数は0以上の整数で入力してください。');
 const found=new Set(response.trim().split(/\s+/).filter(Boolean));
 return {rows:marks.map(mark=>({mark,seen:found.has(mark)})),scope:calls===0?'ツール呼出0として記録':'ツール参照の影響を除外できません'};
}
