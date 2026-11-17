import test from 'node:test';
import assert from 'node:assert/strict';
import { validateDraft, draftErrorMessage } from '../../web/labs/jwenv/dist/web/src/request_validation.js';

const request = (count = 8, type = 'choice') => ({
  model: 'jev-latest', state: '公開してよい合成テキスト',
  questions: { category: { type, instructions: '分類してください',
    criteria: type === 'choice' ? Object.fromEntries(Array.from({length:count}, (_, i) => [`c${i}`, null])) : Array.from({length:count}, (_, i) => `段階${i}`) } },
});
test('accepts eight options and rejects nine before loading a model', () => {
  assert.equal(validateDraft(request(), []).questions.category.type, 'choice');
  assert.throws(() => validateDraft(request(9), []), {code:'too_many_options'});
  assert.throws(() => validateDraft(request(1), []), {code:'too_few_options'});
  assert.equal(validateDraft(request(8, 'score'), []).questions.category.criteria.length, 8);
  assert.throws(() => validateDraft(request(9, 'score'), []), {code:'too_many_levels'});
});
test('rejects duplicate question IDs, including generated IDs', () => {
  const card = {id:'q1',type:'noul',criteria:''};
  assert.throws(() => validateDraft(request(), [card,{...card,id:' q1 '}]), {code:'duplicate_question'});
  assert.throws(() => validateDraft(request(), [{...card,id:''},card]), {code:'duplicate_question'});
});
test('rejects options collapsed by colon/whitespace normalization', () => {
  for (const criteria of ['food: A\nfood: B',' food ： A\nfood:B']) {
    assert.throws(() => validateDraft(request(), [{id:'c',type:'choice',criteria}]), {code:'duplicate_option'});
  }
  assert.ok(validateDraft(request(), [{id:'c',type:'choice',criteria:'food: A\ntransport: B'}]));
});
test('empty input is invalid and localized errors provide recovery steps', () => {
  assert.throws(() => validateDraft({...request(),state:''}, []), {code:'invalid_state'});
  assert.match(draftErrorMessage({code:'too_many_options',field:'questions.c.criteria'}, 'ja'), /8個以下/);
  assert.match(draftErrorMessage({code:'duplicate_question'}, 'en'), /unique/);
});
