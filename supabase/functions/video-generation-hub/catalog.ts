export type VideoModel = {
  key: string;
  name: string;
  description: string;
  durations: readonly number[];
  aspectRatios: readonly string[];
  resolutions: readonly string[];
  creditsPerSecond: number;
};

import { VIDEO_CREDIT_PACKS } from "../_shared/video_credit_packs.ts";

export const VIDEO_MODELS: readonly VideoModel[] = [
  {
    key: "studio-video-v1",
    name: "スタジオ Video 1",
    description:
      "当サイト運営の専用GPUで、短いプロンプトから映像を生成します。音声は含みません。",
    durations: [5],
    aspectRatios: ["16:9", "9:16"],
    resolutions: ["720p"],
    creditsPerSecond: 60,
  },
] as const;

export type ValidatedVideoRequest = {
  model: VideoModel;
  prompt: string;
  durationSeconds: number;
  aspectRatio: string;
  resolution: string;
  requiredCredits: number;
};

export type ValidationResult =
  | { ok: true; value: ValidatedVideoRequest }
  | { ok: false; code: string; message: string };

export function quoteVideoCredits(
  model: VideoModel,
  durationSeconds: number,
): number {
  return model.creditsPerSecond * durationSeconds;
}

export function validateVideoRequest(
  body: Record<string, unknown>,
): ValidationResult {
  const modelKey = asString(body.model_key) || VIDEO_MODELS[0].key;
  const model = VIDEO_MODELS.find((candidate) => candidate.key === modelKey);
  if (!model) {
    return invalid("invalid_model", "選択された動画モデルは利用できません。");
  }

  const prompt = asString(body.prompt);
  if (prompt.length < 3 || prompt.length > 1000) {
    return invalid(
      "invalid_prompt",
      "プロンプトは3〜1000文字で入力してください。",
    );
  }
  if (containsBlockedPrompt(prompt)) {
    return invalid(
      "prompt_not_allowed",
      "未成年者の性的表現など、禁止されている内容は生成できません。",
    );
  }

  const durationSeconds = asInteger(body.duration_seconds);
  if (!model.durations.includes(durationSeconds)) {
    return invalid(
      "invalid_duration",
      "選択された動画の長さは利用できません。",
    );
  }

  const aspectRatio = asString(body.aspect_ratio) || "16:9";
  if (!model.aspectRatios.includes(aspectRatio)) {
    return invalid(
      "invalid_aspect_ratio",
      "選択された縦横比は利用できません。",
    );
  }

  const resolution = asString(body.resolution) || "720p";
  if (!model.resolutions.includes(resolution)) {
    return invalid("invalid_resolution", "選択された解像度は利用できません。");
  }

  if (body.rights_confirmed !== true) {
    return invalid(
      "rights_confirmation_required",
      "生成内容に必要な権利を保有していることを確認してください。",
    );
  }
  if (body.adult_confirmed !== true) {
    return invalid(
      "adult_confirmation_required",
      "この機能は18歳以上の方のみ利用できます。",
    );
  }

  return {
    ok: true,
    value: {
      model,
      prompt,
      durationSeconds,
      aspectRatio,
      resolution,
      requiredCredits: quoteVideoCredits(model, durationSeconds),
    },
  };
}

export function publicCatalog() {
  return {
    models: VIDEO_MODELS.map((model) => ({
      key: model.key,
      name: model.name,
      description: model.description,
      durations: [...model.durations],
      aspect_ratios: [...model.aspectRatios],
      resolutions: [...model.resolutions],
      credits_per_second: model.creditsPerSecond,
    })),
    credit_packs: VIDEO_CREDIT_PACKS.map((pack) => ({
      key: pack.key,
      name: pack.name,
      credits: pack.credits,
      amount_jpy: pack.amountJpy,
    })),
  };
}

function containsBlockedPrompt(prompt: string): boolean {
  const normalized = prompt.toLowerCase().replace(/\s+/g, " ");
  const minorTerms = [
    "child",
    "minor",
    "underage",
    "児童",
    "未成年",
    "小学生",
  ];
  const sexualTerms = [
    "sexual",
    "nude",
    "naked",
    "porn",
    "sex",
    "性的",
    "裸",
    "ポルノ",
  ];
  return minorTerms.some((term) => normalized.includes(term)) &&
    sexualTerms.some((term) => normalized.includes(term));
}

function invalid(code: string, message: string): ValidationResult {
  return { ok: false, code, message };
}

function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asInteger(value: unknown): number {
  if (typeof value === "number" && Number.isInteger(value)) return value;
  if (typeof value === "string" && /^\d+$/.test(value.trim())) {
    return Number(value);
  }
  return 0;
}
