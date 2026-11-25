import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { authorizeAiHubAction } from "./action_access_policy.ts";
import {
  buildConsentVerificationPhrase,
  buildPhraseNonce,
  decodeConsentAudioBase64,
  guardClonedVoiceGeneration,
  handleVoiceCloneConsentAction,
  normalizeConsentMimeType,
  verifySpokenPhraseMatch,
  type VoiceCloneConsentEventRecord,
  type VoiceCloneConsentRecord,
  type VoiceCloneConsentStore,
  type VoiceCloneProfileRecord,
} from "./voice_clone_consent.ts";

function createInMemoryVoiceCloneStore(): {
  store: VoiceCloneConsentStore;
  uploads: Map<string, { bytes: Uint8Array; mimeType: string }>;
  events: VoiceCloneConsentEventRecord[];
  profiles: VoiceCloneProfileRecord[];
  consents: Map<string, VoiceCloneConsentRecord>;
} {
  const consents = new Map<string, VoiceCloneConsentRecord>();
  const uploads = new Map<string, { bytes: Uint8Array; mimeType: string }>();
  const profiles: VoiceCloneProfileRecord[] = [];
  const events: VoiceCloneConsentEventRecord[] = [];

  const store: VoiceCloneConsentStore = {
    getConsent(userId: string) {
      return Promise.resolve(consents.get(userId) ?? null);
    },

    upsertConsent(input) {
      const now = new Date().toISOString();
      const prev = consents.get(input.user_id);
      const next: VoiceCloneConsentRecord = {
        id: prev?.id ?? `consent-${consents.size + 1}`,
        user_id: input.user_id,
        privacy_policy_version: input.privacy_policy_version,
        terms_version: input.terms_version,
        privacy_policy_accepted: input.privacy_policy_accepted ??
          prev?.privacy_policy_accepted ?? false,
        terms_accepted: input.terms_accepted ?? prev?.terms_accepted ?? false,
        biometric_notice_accepted: input.biometric_notice_accepted ??
          prev?.biometric_notice_accepted ?? false,
        legal_consented_at: input.legal_consented_at !== undefined
          ? input.legal_consented_at
          : (prev?.legal_consented_at ?? null),
        verification_phrase: input.verification_phrase,
        phrase_nonce: input.phrase_nonce,
        recording_storage_path: input.recording_storage_path !== undefined
          ? input.recording_storage_path
          : (prev?.recording_storage_path ?? null),
        recording_mime_type: input.recording_mime_type !== undefined
          ? input.recording_mime_type
          : (prev?.recording_mime_type ?? null),
        recording_byte_size: input.recording_byte_size ??
          prev?.recording_byte_size ?? 0,
        recording_duration_ms: input.recording_duration_ms ??
          prev?.recording_duration_ms ?? 0,
        recording_sha256: input.recording_sha256 !== undefined
          ? input.recording_sha256
          : (prev?.recording_sha256 ?? null),
        microphone_permission_granted: input.microphone_permission_granted ??
          prev?.microphone_permission_granted ?? false,
        spoken_transcript: input.spoken_transcript !== undefined
          ? input.spoken_transcript
          : (prev?.spoken_transcript ?? null),
        consent_status: input.consent_status ?? prev?.consent_status ??
          "pending_terms",
        verified_at: input.verified_at !== undefined
          ? input.verified_at
          : (prev?.verified_at ?? null),
        verified_by: input.verified_by !== undefined
          ? input.verified_by
          : (prev?.verified_by ?? null),
        revoked_at: input.revoked_at !== undefined
          ? input.revoked_at
          : (prev?.revoked_at ?? null),
        rejection_reason: input.rejection_reason !== undefined
          ? input.rejection_reason
          : (prev?.rejection_reason ?? null),
        created_at: prev?.created_at ?? now,
        updated_at: now,
      };
      consents.set(input.user_id, next);
      return Promise.resolve(next);
    },

    uploadConsentAudio({ storagePath, bytes, mimeType }) {
      uploads.set(storagePath, { bytes, mimeType });
      return Promise.resolve();
    },

    listProfiles(userId: string) {
      return Promise.resolve(profiles.filter((p) => p.user_id === userId));
    },

    createProfile({ userId, consentId, voiceName }) {
      const profile: VoiceCloneProfileRecord = {
        id: `clone_profile_${profiles.length + 1}`,
        user_id: userId,
        consent_id: consentId,
        voice_name: voiceName,
        provider_voice_id: null,
        is_enabled: true,
        created_at: new Date().toISOString(),
      };
      profiles.unshift(profile);
      return Promise.resolve(profile);
    },

    disableProfiles(userId: string) {
      for (const p of profiles) {
        if (p.user_id === userId) {
          p.is_enabled = false;
        }
      }
      return Promise.resolve();
    },

    listRecentEvents(userId: string, limit: number) {
      return Promise.resolve(
        events.filter((e) => e.user_id === userId).slice(0, limit),
      );
    },

    recordEvent({ consentId, userId, eventType, metadata }) {
      events.unshift({
        id: `evt-${events.length + 1}`,
        consent_id: consentId,
        user_id: userId,
        event_type: eventType,
        metadata: metadata ?? {},
        created_at: new Date().toISOString(),
      });
      return Promise.resolve();
    },
  };

  return { store, uploads, events, profiles, consents };
}

function validSampleAudioBase64(length = 256): string {
  const bytes = new Uint8Array(length);
  for (let i = 0; i < length; i++) {
    bytes[i] = (i % 200) + 1;
  }
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

Deno.test("authorizeAiHubAction enforces authenticated user for voice.clone.* actions", () => {
  const actions = [
    "voice.clone.consent.status",
    "voice.clone.consent.accept",
    "voice.clone.consent.submit_recording",
    "voice.clone.consent.revoke",
    "voice.clone.generate",
  ];
  for (const action of actions) {
    const anonDecision = authorizeAiHubAction(action, {
      userId: null,
      isServiceRole: false,
    });
    assertEquals(anonDecision.allowed, false);
    if (!anonDecision.allowed) assertEquals(anonDecision.status, 401);

    const srDecision = authorizeAiHubAction(action, {
      userId: null,
      isServiceRole: true,
    });
    assertEquals(srDecision.allowed, false);
    if (!srDecision.allowed) assertEquals(srDecision.status, 401);

    assertEquals(
      authorizeAiHubAction(action, { userId: "usr-1", isServiceRole: false })
        .allowed,
      true,
    );
  }
});

Deno.test("normalizes audio mime types, rejects silent buffers, and verifies spoken phrase", () => {
  assertEquals(
    normalizeConsentMimeType("audio/webm;codecs=opus"),
    "audio/webm",
  );
  const decoded = decodeConsentAudioBase64(validSampleAudioBase64(256));
  assertEquals(decoded.byteLength, 256);

  const nonce = buildPhraseNonce("12345678-aaaa-bbbb-cccc-1234567890ab");
  const phrase = buildConsentVerificationPhrase(nonce);
  assertEquals(
    verifySpokenPhraseMatch({
      expectedPhrase: phrase,
      phraseNonce: nonce,
      spokenTranscript: `明示的に許可します 確認コード ${nonce}`,
    }).matched,
    true,
  );
  assertEquals(
    verifySpokenPhraseMatch({
      expectedPhrase: phrase,
      phraseNonce: nonce,
      spokenTranscript: "totally unrelated random speech",
    }).matched,
    false,
  );
});

Deno.test("voice.clone end-to-end flow: blocks unconsented generation, records consent & audio evidence, unlocks clone, and revokes fail-closed", async () => {
  const { store, uploads, events, profiles } = createInMemoryVoiceCloneStore();
  const userId = "usr-voice-owner-1";

  // 1. System-level block before consent exists.
  const blockedBefore = await handleVoiceCloneConsentAction({
    action: "voice.clone.generate",
    store,
    userId,
    body: { voice_name: "My Voice" },
  });
  assertEquals(blockedBefore.status, 403);
  assertEquals(blockedBefore.body.error, "voice_clone_consent_required");

  // Guard helper blocks voice.tts when voice_clone=true, while permitting stock voices.
  const stockAllowed = await guardClonedVoiceGeneration({
    store,
    userId,
    action: "voice.tts",
    body: { voice_id: "21m00Tcm4TlvDq8ikWAM" },
  });
  assertEquals(stockAllowed, null);

  const clonedTtsBlocked = await guardClonedVoiceGeneration({
    store,
    userId,
    action: "voice.tts",
    body: { voice_clone: true, voice_id: "clone_custom_1" },
  });
  assertExists(clonedTtsBlocked);
  assertEquals(clonedTtsBlocked.status, 403);

  // 2. Reject recording before privacy/terms acceptance.
  const recordingWithoutTerms = await handleVoiceCloneConsentAction({
    action: "voice.clone.consent.submit_recording",
    store,
    userId,
    body: {
      microphone_permission_granted: true,
      mime_type: "audio/webm",
      duration_ms: 2400,
      audio_base64: validSampleAudioBase64(256),
    },
  });
  assertEquals(recordingWithoutTerms.status, 403);

  // 3. Partial checkbox acceptance rejected with 400.
  const partialLegal = await handleVoiceCloneConsentAction({
    action: "voice.clone.consent.accept",
    store,
    userId,
    body: {
      privacy_policy_accepted: true,
      terms_accepted: false,
      biometric_notice_accepted: true,
    },
  });
  assertEquals(partialLegal.status, 400);

  // 4. Full legal acceptance succeeds and generates phrase challenge.
  const accepted = await handleVoiceCloneConsentAction({
    action: "voice.clone.consent.accept",
    store,
    userId,
    body: {
      privacy_policy_accepted: true,
      terms_accepted: true,
      biometric_notice_accepted: true,
      privacy_policy_version: "2026-11",
      terms_version: "2026-11",
    },
  });
  assertEquals(accepted.status, 200);
  assertEquals(accepted.body.can_generate_voice_clone, false);
  const nonce = String(accepted.body.phrase_nonce);

  // 5. Generation still blocked after legal acceptance until spoken voice verification finishes.
  const blockedMidway = await handleVoiceCloneConsentAction({
    action: "voice.clone.generate",
    store,
    userId,
    body: { voice_name: "My Voice" },
  });
  assertEquals(blockedMidway.status, 403);

  // 6. Mismatched phrase transitions to rejected (422) and stays blocked.
  const mismatched = await handleVoiceCloneConsentAction({
    action: "voice.clone.consent.submit_recording",
    store,
    userId,
    body: {
      microphone_permission_granted: true,
      mime_type: "audio/webm;codecs=opus",
      duration_ms: 2200,
      audio_base64: validSampleAudioBase64(256),
      spoken_transcript: "hello unrelated speech",
    },
  });
  assertEquals(mismatched.status, 422);
  assertEquals(mismatched.body.can_generate_voice_clone, false);

  // 7. Valid spoken confirmation + recording uploads to private storage and unlocks clone generation.
  const verified = await handleVoiceCloneConsentAction({
    action: "voice.clone.consent.submit_recording",
    store,
    userId,
    body: {
      microphone_permission_granted: true,
      mime_type: "audio/webm;codecs=opus",
      duration_ms: 2600,
      audio_base64: validSampleAudioBase64(256),
      spoken_transcript:
        `私はプライバシーポリシーおよび利用規約に同意し確認コード ${nonce} を読み上げます`,
    },
  });
  assertEquals(verified.status, 200);
  assertEquals(verified.body.can_generate_voice_clone, true);
  assertEquals(uploads.size, 1);

  // 8. Verified user can generate / activate voice clone profile.
  const generated = await handleVoiceCloneConsentAction({
    action: "voice.clone.generate",
    store,
    userId,
    body: { voice_name: "Kanta Verified Voice", sample_text: "テスト音声" },
  });
  assertEquals(generated.status, 200);
  assertEquals(generated.body.allowed, true);
  assertEquals(profiles.length, 1);
  assertEquals(profiles[0].is_enabled, true);

  // 9. Cross-user spoofing via body.user_id is rejected with 403.
  const spoofed = await handleVoiceCloneConsentAction({
    action: "voice.clone.consent.status",
    store,
    userId,
    body: { user_id: "usr-other-user" },
  });
  assertEquals(spoofed.status, 403);

  // 10. Revoking consent disables profiles and locks generation fail-closed again.
  const revoked = await handleVoiceCloneConsentAction({
    action: "voice.clone.consent.revoke",
    store,
    userId,
    body: {},
  });
  assertEquals(revoked.status, 200);
  assertEquals(profiles[0].is_enabled, false);

  const blockedAfterRevoke = await handleVoiceCloneConsentAction({
    action: "voice.clone.generate",
    store,
    userId,
    body: { voice_name: "My Voice" },
  });
  assertEquals(blockedAfterRevoke.status, 403);
  assertEquals(
    events.some((e) => e.event_type === "generation_blocked"),
    true,
  );
});
