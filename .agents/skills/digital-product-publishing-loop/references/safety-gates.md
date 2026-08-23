# Safety gates and handoff evidence

## Required hard gates

The candidate has nine hard checks. `secret_scan`, `pii_scan`, `human_contribution`, `price_match`, `private_object`, and `content_integrity` must be `pass`. Only `third_party_license`, `face_voice_consent`, and `chatgpt_voice_output` may be `not_applicable`, with a human-written reason.

Block readiness when any of these are true:

- a secret or PII finding has not been removed and rescanned;
- third-party license terms are missing or incompatible;
- a depicted face or recorded/synthetic voice lacks the required consent;
- ChatGPT Voice Output is proposed as standalone audio;
- the record does not identify concrete human selection, editing, assembly, or verification;
- the shop display price does not match the reviewed Stripe Price;
- the product is not in the private `product-downloads` bucket;
- object path, measured byte size, or SHA-256 is missing or mismatched.

Automated findings cannot mark human or external-evidence gates as passed. Do not use a waiver, retry, or stage rollback to erase prior audit evidence.
Review each gate only in its assigned stage. Return the candidate to that stage before replacing evidence; do not edit a passed gate in place after approval.

## Live handoff packet

Before requesting live authorization, provide:

- candidate ID, product ID, SHA-256, byte size, and version;
- source/provenance summary without local secret-bearing paths when unnecessary;
- nine gate statuses and concise evidence;
- reviewed Stripe Price ID, JPY amount, mode, private bucket/path, and object verification;
- exact proposed live command/action and environment;
- rollback action (`is_active = false`) and validation plan;
- the authorization reference to record in the publication run.

After an authorized action, record observable proof. A command returning success without catalog, checkout/download, and audit verification is not publication proof.
