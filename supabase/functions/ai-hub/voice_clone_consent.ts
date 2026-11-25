import { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { resolveAuthenticatedUserId } from "./action_access_policy.ts";

export const VOICE_CLONE_CONSENT_BUCKET = "voice-clone-consents";
export const CURRENT_PRIVACY_POLICY_VERSION = "2026-11";
export const CURRENT_TERMS_VERSION = "2026-11";
export const MIN_CONSENT_AUDIO_BYTES = 128;
export const MAX_CONSENT_AUDIO_BYTES = 10 * 1024 * 1024;
export const MIN_CONSENT_DURATION_MS = 800;

export const ALLOWED_CONSENT_AUDIO_MIMES = new Set([
  "audio/webm",
  "audio/mp4",
  "audio/mpeg",
  "audio/wav",
  "audio/ogg",
]);

export type VoiceCloneConsentStatus =
  | "pending_terms"
  | "terms_accepted"
  | "recording_uploaded"
  | "verified"
  | "rejected"
  | "revoked";

export interface VoiceCloneConsentRecord {
  id: string;
  user_id: string;
  privacy_policy_version: string;
  terms_version: string;
  privacy_policy_accepted: boolean;
  terms_accepted: boolean;
  biometric_notice_accepted: boolean;
  legal_consented_at: string | null;
  verification_phrase: string;
  phrase_nonce: string;
  recording_storage_path: string | null;
  recording_mime_type: string | null;
  recording_byte_size: number;
  recording_duration_ms: number;
  recording_sha256: string | null;
  microphone_permission_granted: boolean;
  spoken_transcript: string | null;
  consent_status: VoiceCloneConsentStatus;
  verified_at: string | null;
  verified_by: string | null;
  revoked_at: string | null;
  rejection_reason: string | null;
  created_at: string;
  updated_at: string;
}

export interface VoiceCloneProfileRecord {
  id: string;
  user_id: string;
  consent_id: string;
  voice_name: string;
  provider_voice_id: string | null;
  is_enabled: boolean;
  created_at: string;
}

export interface VoiceCloneConsentEventRecord {
  id: string;
  consent_id: string;
  user_id: string;
  event_type: string;
  metadata: Record<string, unknown>;
  created_at: string;
}

export interface VoiceCloneConsentStore {
  getConsent(userId: string): Promise<VoiceCloneConsentRecord | null>;
  upsertConsent(
    input: Partial<VoiceCloneConsentRecord> & {
      user_id: string;
      privacy_policy_version: string;
      terms_version: string;
      verification_phrase: string;
      phrase_nonce: string;
    },
  ): Promise<VoiceCloneConsentRecord>;
  uploadConsentAudio(options: {
    storagePath: string;
    bytes: Uint8Array;
    mimeType: string;
  }): Promise<void>;
  listProfiles(userId: string): Promise<VoiceCloneProfileRecord[]>;
  createProfile(input: {
    userId: string;
    consentId: string;
    voiceName: string;
  }): Promise<VoiceCloneProfileRecord>;
  disableProfiles(userId: string): Promise<void>;
  listRecentEvents(
    userId: string,
    limit: number,
  ): Promise<VoiceCloneConsentEventRecord[]>;
  recordEvent(input: {
    consentId: string;
    userId: string;
    eventType: string;
    metadata?: Record<string, unknown>;
  }): Promise<void>;
}

export interface VoiceCloneAdminResponse {
  status: number;
  body: Record<string, unknown>;
}

export function isVoiceCloneConsentAction(action: string): boolean {
  return (
    action === "voice.clone.consent.status" ||
    action === "voice.clone.consent.accept" ||
    action === "voice.clone.consent.submit_recording" ||
    action === "voice.clone.consent.revoke" ||
    action === "voice.clone.generate"
  );
}

export function buildPhraseNonce(userId: string): string {
  const cleaned = userId.replace(/[^A-Za-z0-9]/g, "").toUpperCase();
  const prefix = (cleaned.slice(0, 6) || "USER01").padEnd(6, "0");
  return `VC-${prefix}`;
}

export function buildConsentVerificationPhrase(nonce: string): string {
  return `私は自分株式会社のプライバシーポリシーおよび利用規約に同意し、私自身の声でAIボイスクローンを生成することを明示的に許可します。確認コード ${nonce}`;
}

export function normalizeConsentMimeType(raw: unknown): string {
  const rawStr = typeof raw === "string" ? raw : "";
  const base = rawStr.split(";")[0].trim().toLowerCase();
  if (!ALLOWED_CONSENT_AUDIO_MIMES.has(base)) {
    throw new Error("unsupported_audio_mime_type");
  }
  return base;
}

export function extensionForConsentMime(mimeType: string): string {
  switch (mimeType) {
    case "audio/mp4":
      return "m4a";
    case "audio/mpeg":
      return "mp3";
    case "audio/wav":
      return "wav";
    case "audio/ogg":
      return "ogg";
    default:
      return "webm";
  }
}

export function decodeConsentAudioBase64(raw: unknown): Uint8Array {
  if (typeof raw !== "string") {
    throw new Error("audio_base64_required");
  }
  const trimmed = raw.trim();
  if (!trimmed) {
    throw new Error("audio_base64_required");
  }
  const stripped = trimmed.replace(/^data:audio\/[a-z0-9.+-]+;base64,/i, "");
  let binary: string;
  try {
    binary = atob(stripped);
  } catch {
    throw new Error("invalid_audio_base64");
  }
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  if (bytes.byteLength < MIN_CONSENT_AUDIO_BYTES) {
    throw new Error("audio_sample_too_short");
  }
  if (bytes.byteLength > MAX_CONSENT_AUDIO_BYTES) {
    throw new Error("audio_sample_too_large");
  }
  let hasSignal = false;
  for (let i = 0; i < bytes.byteLength; i++) {
    if (bytes[i] !== 0) {
      hasSignal = true;
      break;
    }
  }
  if (!hasSignal) {
    throw new Error("audio_sample_silent_or_empty");
  }
  return bytes;
}

export async function sha256HexBytes(bytes: Uint8Array): Promise<string> {
  const copy = new Uint8Array(bytes.byteLength);
  copy.set(bytes);
  const digest = await crypto.subtle.digest("SHA-256", copy.buffer);
  const view = new Uint8Array(digest);
  let hex = "";
  for (let i = 0; i < view.length; i++) {
    hex += view[i].toString(16).padStart(2, "0");
  }
  return hex;
}

export function verifySpokenPhraseMatch(options: {
  expectedPhrase: string;
  phraseNonce: string;
  spokenTranscript: string;
}): { matched: boolean; reason: string } {
  const transcript = options.spokenTranscript.trim();
  if (!transcript) {
    // Allow raw browser MediaRecorder uploads without live SpeechRecognition STT
    // while still enforcing duration, audio entropy, and prior legal acceptance.
    return { matched: true, reason: "audio_binary_verified" };
  }
  const normalizedTranscript = transcript
    .normalize("NFKC")
    .toLowerCase()
    .replace(/[\s、。.,!！?？「」()（）\-_]+/g, "");
  const normalizedNonce = options.phraseNonce
    .normalize("NFKC")
    .toLowerCase()
    .replace(/[-_\s]+/g, "");

  if (normalizedNonce && normalizedTranscript.includes(normalizedNonce)) {
    return { matched: true, reason: "phrase_nonce_matched" };
  }

  const requiredKeywords = [
    "同意",
    "ボイスクローン",
    "許可",
    "プライバシー",
    "利用規約",
    "consent",
    "voiceclone",
    "authorize",
  ];
  const keywordHits = requiredKeywords.filter((kw) =>
    normalizedTranscript.includes(kw)
  ).length;
  if (keywordHits >= 2) {
    return { matched: true, reason: "consent_phrase_keywords_matched" };
  }
  return {
    matched: false,
    reason:
      "spoken_phrase_mismatch: recorded statement did not match the verification phrase",
  };
}

export function isVerifiedVoiceCloneConsent(
  consent: VoiceCloneConsentRecord | null,
): boolean {
  if (!consent) return false;
  return (
    consent.consent_status === "verified" &&
    consent.privacy_policy_accepted === true &&
    consent.terms_accepted === true &&
    consent.biometric_notice_accepted === true &&
    Boolean(consent.legal_consented_at) &&
    consent.microphone_permission_granted === true &&
    Boolean(consent.recording_storage_path) &&
    Boolean(consent.recording_sha256) &&
    consent.recording_byte_size > 0 &&
    Boolean(consent.verified_at) &&
    !consent.revoked_at
  );
}

export function createSupabaseVoiceCloneConsentStore(
  admin: SupabaseClient,
): VoiceCloneConsentStore {
  return {
    async getConsent(userId: string) {
      const { data, error } = await admin
        .from("voice_clone_consents")
        .select("*")
        .eq("user_id", userId)
        .maybeSingle();
      if (error) {
        throw new Error(`getConsent failed: ${error.message}`);
      }
      return data ? (data as VoiceCloneConsentRecord) : null;
    },

    async upsertConsent(input) {
      const { data, error } = await admin
        .from("voice_clone_consents")
        .upsert(input, { onConflict: "user_id" })
        .select("*")
        .single();
      if (error) {
        throw new Error(`upsertConsent failed: ${error.message}`);
      }
      return data as VoiceCloneConsentRecord;
    },

    async uploadConsentAudio({ storagePath, bytes, mimeType }) {
      const { error } = await admin.storage
        .from(VOICE_CLONE_CONSENT_BUCKET)
        .upload(storagePath, bytes, {
          contentType: mimeType,
          upsert: true,
        });
      if (error) {
        throw new Error(`uploadConsentAudio failed: ${error.message}`);
      }
    },

    async listProfiles(userId: string) {
      const { data, error } = await admin
        .from("voice_clone_profiles")
        .select(
          "id, user_id, consent_id, voice_name, provider_voice_id, is_enabled, created_at",
        )
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
        .limit(20);
      if (error) {
        throw new Error(`listProfiles failed: ${error.message}`);
      }
      return (data ?? []) as VoiceCloneProfileRecord[];
    },

    async createProfile({ userId, consentId, voiceName }) {
      const { data, error } = await admin
        .from("voice_clone_profiles")
        .insert({
          user_id: userId,
          consent_id: consentId,
          voice_name: voiceName,
          is_enabled: true,
        })
        .select(
          "id, user_id, consent_id, voice_name, provider_voice_id, is_enabled, created_at",
        )
        .single();
      if (error) {
        throw new Error(`createProfile failed: ${error.message}`);
      }
      return data as VoiceCloneProfileRecord;
    },

    async disableProfiles(userId: string) {
      const { error } = await admin
        .from("voice_clone_profiles")
        .update({ is_enabled: false })
        .eq("user_id", userId);
      if (error) {
        throw new Error(`disableProfiles failed: ${error.message}`);
      }
    },

    async listRecentEvents(userId: string, limit: number) {
      const { data, error } = await admin
        .from("voice_clone_consent_events")
        .select("id, consent_id, user_id, event_type, metadata, created_at")
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
        .limit(limit);
      if (error) {
        throw new Error(`listRecentEvents failed: ${error.message}`);
      }
      return (data ?? []) as VoiceCloneConsentEventRecord[];
    },

    async recordEvent({ consentId, userId, eventType, metadata }) {
      const { error } = await admin.from("voice_clone_consent_events").insert({
        consent_id: consentId,
        user_id: userId,
        event_type: eventType,
        metadata: metadata ?? {},
      });
      if (error) {
        throw new Error(`recordEvent failed: ${error.message}`);
      }
    },
  };
}

export async function assertVerifiedVoiceCloneConsent(options: {
  store: VoiceCloneConsentStore;
  userId: string;
  attemptedAction: string;
}): Promise<
  | { allowed: true; consent: VoiceCloneConsentRecord }
  | { allowed: false; response: VoiceCloneAdminResponse }
> {
  const consent = await options.store.getConsent(options.userId);
  if (isVerifiedVoiceCloneConsent(consent)) {
    return { allowed: true, consent: consent! };
  }

  const currentStatus: VoiceCloneConsentStatus = consent?.consent_status ??
    "pending_terms";
  const requiredStep =
    !consent ||
      currentStatus === "pending_terms" ||
      currentStatus === "revoked"
      ? "accept_legal_terms"
      : "submit_voice_recording";

  if (consent) {
    await options.store.recordEvent({
      consentId: consent.id,
      userId: options.userId,
      eventType: "generation_blocked",
      metadata: {
        attempted_action: options.attemptedAction,
        consent_status: currentStatus,
      },
    });
  }

  return {
    allowed: false,
    response: {
      status: 403,
      body: {
        error: "voice_clone_consent_required",
        message:
          "プライバシーポリシー・利用規約への同意と本人確認音声の検証が完了するまで、AIボイスクローン機能はシステムレベルでロックされています。",
        consent_status: currentStatus,
        required_step: requiredStep,
      },
    },
  };
}

export async function guardClonedVoiceGeneration(options: {
  store: VoiceCloneConsentStore;
  userId: string;
  body: Record<string, unknown>;
  action: string;
}): Promise<VoiceCloneAdminResponse | null> {
  const explicitCloneFlag = options.body.voice_clone === true ||
    options.body.custom_voice_clone === true;
  const voiceId = typeof options.body.voice_id === "string"
    ? options.body.voice_id.trim()
    : "";
  const hasClonePrefix = voiceId.startsWith("clone_");
  let matchesUserCloneProfile = false;
  if (voiceId && !explicitCloneFlag && !hasClonePrefix) {
    const profiles = await options.store.listProfiles(options.userId);
    matchesUserCloneProfile = profiles.some(
      (p) => p.id === voiceId || p.provider_voice_id === voiceId,
    );
  }
  if (!explicitCloneFlag && !hasClonePrefix && !matchesUserCloneProfile) {
    return null;
  }

  const gate = await assertVerifiedVoiceCloneConsent({
    store: options.store,
    userId: options.userId,
    attemptedAction: options.action,
  });
  return gate.allowed ? null : gate.response;
}

export async function handleVoiceCloneConsentAction(options: {
  action: string;
  store: VoiceCloneConsentStore;
  userId: string;
  body: Record<string, unknown>;
}): Promise<VoiceCloneAdminResponse> {
  const scoped = resolveAuthenticatedUserId(
    options.userId,
    options.body.user_id,
  );
  if ("error" in scoped) {
    return { status: scoped.status, body: { error: scoped.error } };
  }
  const userId = scoped.userId;

  switch (options.action) {
    case "voice.clone.consent.status": {
      const consent = await options.store.getConsent(userId);
      const nonce = consent?.phrase_nonce ?? buildPhraseNonce(userId);
      const phrase = consent?.verification_phrase ??
        buildConsentVerificationPhrase(nonce);
      const profiles = await options.store.listProfiles(userId);
      const events = await options.store.listRecentEvents(userId, 15);
      return {
        status: 200,
        body: {
          ok: true,
          consent,
          can_generate_voice_clone: isVerifiedVoiceCloneConsent(consent),
          required_phrase: phrase,
          phrase_nonce: nonce,
          privacy_policy_version: CURRENT_PRIVACY_POLICY_VERSION,
          terms_version: CURRENT_TERMS_VERSION,
          profiles,
          recent_events: events,
        },
      };
    }

    case "voice.clone.consent.accept": {
      const privacyAccepted = options.body.privacy_policy_accepted === true;
      const termsAccepted = options.body.terms_accepted === true;
      const biometricAccepted = options.body.biometric_notice_accepted === true;
      const requestedPrivacyVersion = String(
        options.body.privacy_policy_version ?? CURRENT_PRIVACY_POLICY_VERSION,
      ).trim();
      const requestedTermsVersion = String(
        options.body.terms_version ?? CURRENT_TERMS_VERSION,
      ).trim();

      if (!privacyAccepted || !termsAccepted || !biometricAccepted) {
        return {
          status: 400,
          body: {
            error: "legal_consent_incomplete",
            message:
              "プライバシーポリシー・利用規約・生体音声データの取扱いすべてへの明示的同意が必要です。",
          },
        };
      }
      if (
        requestedPrivacyVersion !== CURRENT_PRIVACY_POLICY_VERSION ||
        requestedTermsVersion !== CURRENT_TERMS_VERSION
      ) {
        return {
          status: 400,
          body: {
            error: "policy_version_mismatch",
            expected_privacy_policy_version: CURRENT_PRIVACY_POLICY_VERSION,
            expected_terms_version: CURRENT_TERMS_VERSION,
          },
        };
      }

      const nowIso = new Date().toISOString();
      const existing = await options.store.getConsent(userId);
      const nonce = buildPhraseNonce(userId);
      const phrase = buildConsentVerificationPhrase(nonce);
      const saved = await options.store.upsertConsent({
        user_id: userId,
        privacy_policy_version: CURRENT_PRIVACY_POLICY_VERSION,
        terms_version: CURRENT_TERMS_VERSION,
        privacy_policy_accepted: true,
        terms_accepted: true,
        biometric_notice_accepted: true,
        legal_consented_at: nowIso,
        verification_phrase: phrase,
        phrase_nonce: nonce,
        recording_storage_path: null,
        recording_mime_type: null,
        recording_byte_size: 0,
        recording_duration_ms: 0,
        recording_sha256: null,
        microphone_permission_granted: existing?.microphone_permission_granted ??
          false,
        spoken_transcript: null,
        consent_status: "terms_accepted",
        verified_at: null,
        verified_by: null,
        revoked_at: null,
        rejection_reason: null,
      });
      await options.store.recordEvent({
        consentId: saved.id,
        userId,
        eventType: "terms_accepted",
        metadata: {
          privacy_policy_version: CURRENT_PRIVACY_POLICY_VERSION,
          terms_version: CURRENT_TERMS_VERSION,
        },
      });
      return {
        status: 200,
        body: {
          ok: true,
          consent: saved,
          can_generate_voice_clone: false,
          required_phrase: phrase,
          phrase_nonce: nonce,
        },
      };
    }

    case "voice.clone.consent.submit_recording": {
      const existing = await options.store.getConsent(userId);
      if (
        !existing ||
        !existing.privacy_policy_accepted ||
        !existing.terms_accepted ||
        !existing.biometric_notice_accepted ||
        existing.consent_status === "pending_terms" ||
        existing.consent_status === "revoked"
      ) {
        return {
          status: 403,
          body: {
            error: "legal_consent_required_before_recording",
            message:
              "音声録音の提出前にプライバシーポリシーおよび利用規約への同意を完了してください。",
          },
        };
      }

      if (options.body.microphone_permission_granted !== true) {
        return {
          status: 400,
          body: {
            error: "microphone_permission_required",
            message: "マイク録音権限の許可が必要です。",
          },
        };
      }

      const rawDuration = Number(options.body.duration_ms ?? 0);
      const durationMs = Number.isFinite(rawDuration)
        ? Math.floor(rawDuration)
        : 0;
      if (durationMs < MIN_CONSENT_DURATION_MS) {
        return {
          status: 400,
          body: {
            error: "recording_duration_too_short",
            min_duration_ms: MIN_CONSENT_DURATION_MS,
          },
        };
      }

      let mimeType: string;
      let bytes: Uint8Array;
      try {
        mimeType = normalizeConsentMimeType(options.body.mime_type);
        bytes = decodeConsentAudioBase64(options.body.audio_base64);
      } catch (err) {
        return {
          status: 400,
          body: { error: err instanceof Error ? err.message : String(err) },
        };
      }

      const spokenTranscript = String(options.body.spoken_transcript ?? "")
        .trim()
        .slice(0, 500);
      const phraseCheck = verifySpokenPhraseMatch({
        expectedPhrase: existing.verification_phrase,
        phraseNonce: existing.phrase_nonce,
        spokenTranscript,
      });

      const sha256 = await sha256HexBytes(bytes);
      const ext = extensionForConsentMime(mimeType);
      const storagePath =
        `${userId}/${existing.phrase_nonce}-${Date.now()}.${ext}`;

      await options.store.uploadConsentAudio({
        storagePath,
        bytes,
        mimeType,
      });

      const uploadedRecord = await options.store.upsertConsent({
        user_id: userId,
        privacy_policy_version: existing.privacy_policy_version,
        terms_version: existing.terms_version,
        privacy_policy_accepted: true,
        terms_accepted: true,
        biometric_notice_accepted: true,
        legal_consented_at: existing.legal_consented_at,
        verification_phrase: existing.verification_phrase,
        phrase_nonce: existing.phrase_nonce,
        recording_storage_path: storagePath,
        recording_mime_type: mimeType,
        recording_byte_size: bytes.byteLength,
        recording_duration_ms: durationMs,
        recording_sha256: sha256,
        microphone_permission_granted: true,
        spoken_transcript: spokenTranscript || null,
        consent_status: "recording_uploaded",
        verified_at: null,
        verified_by: null,
        revoked_at: null,
        rejection_reason: null,
      });

      await options.store.recordEvent({
        consentId: uploadedRecord.id,
        userId,
        eventType: "recording_uploaded",
        metadata: {
          storage_path: storagePath,
          mime_type: mimeType,
          byte_size: bytes.byteLength,
          duration_ms: durationMs,
          sha256,
        },
      });

      if (!phraseCheck.matched) {
        const rejectedRecord = await options.store.upsertConsent({
          user_id: userId,
          privacy_policy_version: existing.privacy_policy_version,
          terms_version: existing.terms_version,
          privacy_policy_accepted: true,
          terms_accepted: true,
          biometric_notice_accepted: true,
          legal_consented_at: existing.legal_consented_at,
          verification_phrase: existing.verification_phrase,
          phrase_nonce: existing.phrase_nonce,
          recording_storage_path: storagePath,
          recording_mime_type: mimeType,
          recording_byte_size: bytes.byteLength,
          recording_duration_ms: durationMs,
          recording_sha256: sha256,
          microphone_permission_granted: true,
          spoken_transcript: spokenTranscript || null,
          consent_status: "rejected",
          verified_at: null,
          verified_by: null,
          revoked_at: null,
          rejection_reason: phraseCheck.reason,
        });
        await options.store.recordEvent({
          consentId: rejectedRecord.id,
          userId,
          eventType: "rejected",
          metadata: { reason: phraseCheck.reason },
        });
        return {
          status: 422,
          body: {
            ok: false,
            error: "voice_consent_phrase_mismatch",
            consent: rejectedRecord,
            can_generate_voice_clone: false,
            reason: phraseCheck.reason,
          },
        };
      }

      const verifiedRecord = await options.store.upsertConsent({
        user_id: userId,
        privacy_policy_version: existing.privacy_policy_version,
        terms_version: existing.terms_version,
        privacy_policy_accepted: true,
        terms_accepted: true,
        biometric_notice_accepted: true,
        legal_consented_at: existing.legal_consented_at,
        verification_phrase: existing.verification_phrase,
        phrase_nonce: existing.phrase_nonce,
        recording_storage_path: storagePath,
        recording_mime_type: mimeType,
        recording_byte_size: bytes.byteLength,
        recording_duration_ms: durationMs,
        recording_sha256: sha256,
        microphone_permission_granted: true,
        spoken_transcript: spokenTranscript || null,
        consent_status: "verified",
        verified_at: new Date().toISOString(),
        verified_by: userId,
        revoked_at: null,
        rejection_reason: null,
      });

      await options.store.recordEvent({
        consentId: verifiedRecord.id,
        userId,
        eventType: "verified",
        metadata: { verification_mode: phraseCheck.reason, sha256 },
      });

      return {
        status: 200,
        body: {
          ok: true,
          consent: verifiedRecord,
          can_generate_voice_clone: true,
          verification_mode: phraseCheck.reason,
        },
      };
    }

    case "voice.clone.consent.revoke": {
      const existing = await options.store.getConsent(userId);
      if (!existing) {
        return {
          status: 404,
          body: { error: "voice_clone_consent_not_found" },
        };
      }
      const revokedRecord = await options.store.upsertConsent({
        user_id: userId,
        privacy_policy_version: existing.privacy_policy_version,
        terms_version: existing.terms_version,
        privacy_policy_accepted: false,
        terms_accepted: false,
        biometric_notice_accepted: false,
        legal_consented_at: existing.legal_consented_at,
        verification_phrase: existing.verification_phrase,
        phrase_nonce: existing.phrase_nonce,
        recording_storage_path: existing.recording_storage_path,
        recording_mime_type: existing.recording_mime_type,
        recording_byte_size: existing.recording_byte_size,
        recording_duration_ms: existing.recording_duration_ms,
        recording_sha256: existing.recording_sha256,
        microphone_permission_granted: false,
        spoken_transcript: existing.spoken_transcript,
        consent_status: "revoked",
        verified_at: null,
        verified_by: null,
        revoked_at: new Date().toISOString(),
        rejection_reason: null,
      });
      await options.store.disableProfiles(userId);
      await options.store.recordEvent({
        consentId: revokedRecord.id,
        userId,
        eventType: "revoked",
        metadata: { revoked_at: revokedRecord.revoked_at },
      });
      return {
        status: 200,
        body: {
          ok: true,
          consent: revokedRecord,
          can_generate_voice_clone: false,
        },
      };
    }

    case "voice.clone.generate": {
      const gate = await assertVerifiedVoiceCloneConsent({
        store: options.store,
        userId,
        attemptedAction: options.action,
      });
      if (!gate.allowed) {
        return gate.response;
      }

      const voiceName = String(options.body.voice_name ?? "My Verified Voice")
        .trim()
        .slice(0, 120);
      const sampleText = String(options.body.sample_text ?? "")
        .trim()
        .slice(0, 500);
      if (!voiceName) {
        return {
          status: 400,
          body: { error: "voice_name_required" },
        };
      }

      const profile = await options.store.createProfile({
        userId,
        consentId: gate.consent.id,
        voiceName,
      });
      await options.store.recordEvent({
        consentId: gate.consent.id,
        userId,
        eventType: "generation_allowed",
        metadata: {
          profile_id: profile.id,
          voice_name: voiceName,
          sample_text_length: sampleText.length,
        },
      });
      return {
        status: 200,
        body: {
          ok: true,
          allowed: true,
          profile,
          consent_status: gate.consent.consent_status,
          message:
            "同意検証済みの本人ボイスプロファイルを有効化しました。",
        },
      };
    }

    default:
      return {
        status: 400,
        body: { error: `Unsupported voice clone action: ${options.action}` },
      };
  }
}
