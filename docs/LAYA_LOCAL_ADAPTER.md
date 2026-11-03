# Optional local Laya adapter

This is a **local Python companion**, not a model running in the Flutter browser
or Firebase. Production remains on its existing defaults. The current JevClient
already speaks `/v1/systemone`, so no duplicate client or production-wide flag
change is needed. The adapter supports one `choice` question with 2–20 options.

## Install on a machine with sufficient memory and disk

Do not run these commands on a resource-constrained machine. PyTorch, model
weights and first-load memory require more space than a screenshot's inference
memory number. MLX measurements on Apple hardware do not predict this adapter's
Windows/PyTorch performance.

```sh
python -m venv .venv-laya
# Activate that environment with your platform's command, then:
python -m pip install 'laya @ git+https://github.com/NandhaKishorM/laya.git@42626c348753fbb17572a813127df2278a1ec527'
python scripts/laya_system_one_server.py --model multilingual --port 8081
```

First startup downloads the model. Subsequent `--offline` runs require the
complete model/tokenizer cache. `multilingual` selects the 322M model; `english`
selects the 421M model. The default is deliberately multilingual for Japanese
input. The server selects the checkpoint at startup and ignores the request's
`model` field; a request cannot download or select another model.

Native local clients can use `http://127.0.0.1:8081/v1/systemone`. Browser access
is denied unless you explicitly allow one origin, without a trailing slash:

```sh
python scripts/laya_system_one_server.py --model multilingual --port 8081 --offline --allow-origin https://my-web-app-b67f4.web.app
```

The listener is always `127.0.0.1`. Do not reverse-proxy it onto a network or
weaken its Host/Origin checks. It has no user authentication and trusts local
processes. Allowing an origin permits scripts on that site to send local model
requests. Never put a cloud API key into a public Flutter build.

## Client integration and five-step operation

For a separately configured Flutter build, pass
`--dart-define=JEV_ENDPOINT=http://127.0.0.1:8081/v1/systemone` and the existing
feature flag required by the calling feature. This setting does not alter the
already deployed public build. No `JEV_MODEL` setting is required.

1. Start the adapter on a adequately provisioned machine. Check `/health`; it
   reports readiness, **not** successful model inference.
2. Open the separately configured app and log in with an existing account.
3. Navigate to Asset Management through the normal feature navigation.
4. Use a classification/search operation that calls the existing Jev client.
5. Verify the actual network request reaches port 8081, the selected answer is
   correct, and stopping the adapter restores the existing fallback behavior.

The existing client timeout is 800 ms. Cold or CPU inference may exceed it.
Client timeout does not cancel server inference; this adapter serializes work.
Do not increase timeouts or enable production routing based on this mock test
suite. CORS response headers alone do not prove that a browser's local-network
permissions or mixed-content rules allow the connection. Real browser testing
and workload-specific latency/accuracy evaluation remain deployment prerequisites.

## Verification and limits

GitHub Actions runs `scripts/test_laya_system_one_server.py` through real loopback
HTTP with a fake SDK. It checks the Jev wire contract, preserved probabilities
and confidence, origin/host rejection, malformed input/output, and recovery.
It downloads no model and establishes no inference performance or accuracy.

For real evaluation, record model and SDK revisions, device, precision, warmup,
sample count, p50/p95, timeouts, expected labels, and routing failures. Use local
authorized data; do not upload personal financial records into public CI or a
third-party demo. A model's confidence is not proof of correctness, and Laya's
default calibration needs validation for the chosen language and task.

Sources: [upstream Laya](https://github.com/NandhaKishorM/laya),
[independent MLX runtime](https://github.com/mizorewww/laya-mlx).
