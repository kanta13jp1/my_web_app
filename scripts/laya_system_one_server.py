"""Opt-in loopback adapter; SDK/model installation is separate from the web app."""
import argparse
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import math
import os
from urllib.parse import urlsplit

MAX_BODY = 65536
MODELS = {
    'multilingual': 'convaiinnovations/laya-multilingual',
    'english': 'convaiinnovations/laya',
    'typed-decisions': 'convaiinnovations/laya-typed-decisions',
}


def validate_request(payload):
    if not isinstance(payload, dict):
        raise ValueError('Expected an object')
    state = payload.get('state')
    if not isinstance(state, str) or not 1 <= len(state) <= 8000:
        raise ValueError('state must contain 1 to 8000 characters')
    questions = payload.get('questions')
    if not isinstance(questions, dict) or len(questions) != 1:
        raise ValueError('Exactly one choice question is supported')
    for key, question in questions.items():
        if not isinstance(key, str) or not 1 <= len(key) <= 100:
            raise ValueError('Invalid question ID')
        if not isinstance(question, dict) or question.get('type') != 'choice':
            raise ValueError('Only choice questions are supported')
        instructions = question.get('instructions', '')
        if not isinstance(instructions, str) or len(instructions) > 2000:
            raise ValueError('Invalid instructions')
        criteria = question.get('criteria')
        if not isinstance(criteria, dict) or not 2 <= len(criteria) <= 20:
            raise ValueError('Expected 2 to 20 choices')
        for choice, label in criteria.items():
            if not isinstance(choice, str) or not 1 <= len(choice) <= 100:
                raise ValueError('Invalid choice ID')
            if not isinstance(label, str) or not 1 <= len(label) <= 500:
                raise ValueError('Invalid choice label')
    return state, questions


def validate_response(result, questions):
    if not isinstance(result, dict) or not isinstance(result.get('answers'), dict):
        raise ValueError('Invalid model output')
    for key, question in questions.items():
        answer = result['answers'].get(key)
        if not isinstance(answer, dict) or answer.get('type') != 'choice':
            raise ValueError('Invalid answer')
        probabilities = answer.get('probabilities')
        if not isinstance(probabilities, dict) or set(probabilities) != set(question['criteria']):
            raise ValueError('Invalid probability keys')
        if answer.get('choice') not in probabilities:
            raise ValueError('Unknown choice')
        for value in [answer.get('confidence'), *probabilities.values()]:
            if type(value) not in (int, float) or not math.isfinite(value) or not 0 <= value <= 1:
                raise ValueError('Invalid probability or confidence')
        if abs(sum(probabilities.values()) - 1) > 0.01:
            raise ValueError('Probabilities do not sum to one')
    return result


def make_server(agent, port=8081, allowed_origin=None):
    if allowed_origin:
        origin = urlsplit(allowed_origin)
        if (origin.scheme not in ('http', 'https') or not origin.hostname
                or origin.path or origin.query or origin.fragment or origin.username
                or origin.password or '*' in allowed_origin):
            raise ValueError('allowed-origin must be one exact HTTP(S) origin, without a trailing slash')

    class Handler(BaseHTTPRequestHandler):
        def setup(self):
            super().setup()
            self.connection.settimeout(5)

        def log_message(self, *_args):
            pass  # Never log financial input, URL parameters, or model output.

        def permitted(self):
            expected = {f'127.0.0.1:{self.server.server_port}', f'localhost:{self.server.server_port}'}
            origins = self.headers.get_all('Origin') or []
            hosts = self.headers.get_all('Host') or []
            return (len(hosts) == 1 and hosts[0] in expected
                    and (not origins or (len(origins) == 1 and allowed_origin is not None
                                         and origins[0] == allowed_origin)))

        def reply(self, status, payload):
            body = json.dumps(payload, allow_nan=False).encode()
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Connection', 'close')
            if self.permitted() and self.headers.get('Origin') == allowed_origin and allowed_origin:
                self.send_header('Access-Control-Allow-Origin', allowed_origin)
                self.send_header('Vary', 'Origin')
                self.send_header('Access-Control-Allow-Methods', 'POST, GET, OPTIONS')
                self.send_header('Access-Control-Allow-Headers', 'content-type, x-api-key')
                self.send_header('Access-Control-Allow-Private-Network', 'true')
            self.end_headers()
            self.wfile.write(body)
            self.close_connection = True

        def do_GET(self):
            if not self.permitted():
                return self.reply(403, {'error': 'Host or origin denied'})
            if self.path != '/health':
                return self.reply(404, {'error': 'Not found'})
            self.reply(200, {'ready': True, 'backend': 'laya', 'inference_verified': False})

        def do_OPTIONS(self):
            if not self.permitted():
                return self.reply(403, {'error': 'Host or origin denied'})
            if self.path != '/v1/systemone':
                return self.reply(404, {'error': 'Not found'})
            self.reply(200, {'ok': True})

        def do_POST(self):
            if not self.permitted():
                return self.reply(403, {'error': 'Host or origin denied'})
            if self.path != '/v1/systemone':
                return self.reply(404, {'error': 'Not found'})
            if self.headers.get_content_type() != 'application/json':
                return self.reply(415, {'error': 'Expected application/json'})
            lengths = self.headers.get_all('Content-Length') or []
            if len(lengths) != 1 or self.headers.get('Transfer-Encoding'):
                return self.reply(400, {'error': 'Expected one content length'})
            try:
                length = int(lengths[0])
                if not 0 < length <= MAX_BODY:
                    return self.reply(413, {'error': 'Request too large or empty'})
                payload = json.loads(self.rfile.read(length))
                state, questions = validate_request(payload)
            except (ValueError, UnicodeError, TimeoutError):
                return self.reply(400, {'error': 'Invalid request'})
            try:
                # The model is selected at process startup, never by untrusted requests.
                result = validate_response(agent.predict(state, questions), questions)
                encoded = json.loads(json.dumps(result, allow_nan=False))
            except Exception:
                return self.reply(502, {'error': 'Laya inference failed'})
            self.reply(200, encoded)

    return HTTPServer(('127.0.0.1', port), Handler)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8081)
    parser.add_argument('--model', choices=MODELS, default='multilingual')
    parser.add_argument('--allow-origin')
    parser.add_argument('--offline', action='store_true')
    args = parser.parse_args()
    if args.offline:
        os.environ['HF_HUB_OFFLINE'] = '1'
        os.environ['TRANSFORMERS_OFFLINE'] = '1'
    import laya  # Optional dependency: not installed or loaded by contract tests.
    agent = laya.load(MODELS[args.model])
    with make_server(agent, args.port, args.allow_origin) as server:
        print(f'Laya ready on http://127.0.0.1:{server.server_port}; model={args.model}', flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == '__main__':
    main()
