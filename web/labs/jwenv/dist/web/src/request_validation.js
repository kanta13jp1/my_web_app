// Application-specific preflight; the pinned inference engine remains unchanged.
import { validate, MODEL_ALIASES, JevError } from "../../src/jev.js";

export function validateDraft(request, cards) {
    const ids = new Set();
    for (const [i, card] of cards.entries()) {
        const id = card.id.trim() || `q${i + 1}`;
        if (ids.has(id)) throw new JevError("duplicate_question", id, "questions");
        ids.add(id);
        if (card.type !== "choice") continue;
        const keys = new Set();
        for (const line of card.criteria.split("\n").map(x => x.trim()).filter(Boolean)) {
            const key = line.split(/[:：]/, 1)[0].trim();
            if (keys.has(key)) throw new JevError("duplicate_option", key, `questions.${id}.criteria`);
            keys.add(key);
        }
    }
    return validate(request, MODEL_ALIASES);
}

const JA = {
    duplicate_question: "質問IDが重複しています。別のIDに変更してください。",
    duplicate_option: "選択肢名が重複しています。別の名前に変更してください。",
    too_many_options: "選択肢は最大8個です。8個以下に減らしてください。",
    too_few_options: "選択肢を2個以上入力してください。",
    too_many_levels: "段階は最大8個です。8個以下に減らしてください。",
    too_few_levels: "段階を2個以上入力してください。",
    invalid_state: "判定する文章を入力してください。",
    invalid_instructions: "各質問のinstructionsに、判定したい内容を入力してください。",
    invalid_questions: "質問を1つ以上入力してください（最大64問）。",
    too_many_questions: "質問は最大64問です。質問を減らしてください。",
};
export function draftErrorMessage(error, lang) {
    if (lang === "ja") return (JA[error.code] || "質問や選択肢の入力を確認してください。") + (error.field ? ` [${error.field}]` : "");
    const duplicates = {
        duplicate_question: "Question IDs must be unique. Change the repeated ID.",
        duplicate_option: "Option names must be unique. Rename the repeated option.",
    };
    return (duplicates[error.code] || error.message) + (error.field ? ` [${error.field}]` : "");
}
