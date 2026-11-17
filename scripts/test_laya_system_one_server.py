import copy
import http.client
import json
import threading
import unittest

from laya_system_one_server import make_server


REQUEST = {'model': 'jev-latest', 'state': 'Please classify this message', 'questions': {
    'classification': {'type': 'choice', 'instructions': 'Pick a category',
                       'criteria': {'a': 'A', 'b': 'B'}}}}
RESPONSE = {'model': 'laya-rl-agent', 'answers': {'classification': {
    'type': 'choice', 'choice': 'a', 'probabilities': {'a': 0.75, 'b': 0.25},
    'confidence': 0.1887}}, 'usage': {'input_tokens': 12, 'output_tokens': 0}}


class FakeAgent:
    def __init__(self):
        self.calls = []
        self.response = copy.deepcopy(RESPONSE)
        self.fail = False

    def predict(self, state, questions):
        self.calls.append((state, questions))
        if self.fail:
            raise RuntimeError('must not leak private input')
        return self.response


class HttpContractTests(unittest.TestCase):
    def setUp(self):
        self.agent = FakeAgent()
        self.origin = 'https://my-web-app-b67f4.web.app'
        self.server = make_server(self.agent, port=0, allowed_origin=self.origin)
        self.thread = threading.Thread(target=self.server.serve_forever)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def request(self, payload=REQUEST, headers=None, method='POST', path='/v1/systemone'):
        connection = http.client.HTTPConnection('127.0.0.1', self.server.server_port, timeout=3)
        try:
            connection.request(method, path, body=json.dumps(payload),
                               headers={'Content-Type': 'application/json', **(headers or {})})
            response = connection.getresponse()
            return response.status, dict(response.getheaders()), json.loads(response.read())
        finally:
            connection.close()

    def test_existing_jev_request_preserves_laya_distribution_and_confidence(self):
        status, headers, body = self.request(headers={'Origin': self.origin, 'x-api-key': 'localjev'})
        self.assertEqual(status, 200)
        self.assertEqual(body, RESPONSE)
        self.assertEqual(self.agent.calls, [(REQUEST['state'], REQUEST['questions'])])
        self.assertEqual(headers['Access-Control-Allow-Origin'], self.origin)

    def test_unknown_origin_and_rebinding_host_never_invoke_model(self):
        for headers in [{'Origin': 'https://attacker.example'}, {'Origin': 'null'},
                        {'Origin': self.origin + '.attacker.example'}, {'Host': 'attacker.example'}]:
            with self.subTest(headers=headers):
                status, response_headers, _ = self.request(headers=headers)
                self.assertEqual(status, 403)
                self.assertNotIn('Access-Control-Allow-Origin', response_headers)
        self.assertFalse(self.agent.calls)

    def test_invalid_input_never_invokes_model(self):
        for payload in [[], {'state': 'x', 'questions': {}},
                        {**REQUEST, 'state': 'x' * 8001},
                        {**REQUEST, 'questions': {'classification': {'type': 'noul'}}}]:
            with self.subTest(payload=str(payload)[:60]):
                self.assertEqual(self.request(payload)[0], 400)
        self.assertFalse(self.agent.calls)

    def test_failure_does_not_leak_exception_and_next_call_recovers(self):
        self.agent.fail = True
        self.assertEqual(self.request()[::2], (502, {'error': 'Laya inference failed'}))
        self.agent.fail = False
        self.assertEqual(self.request()[0], 200)

    def test_malformed_model_answer_fails_closed(self):
        for change in [{'choice': 'unknown'}, {'confidence': float('nan')},
                       {'probabilities': {'a': 0.5}}, {'confidence': True}]:
            with self.subTest(change=change):
                self.agent.response = copy.deepcopy(RESPONSE)
                self.agent.response['answers']['classification'].update(change)
                self.assertEqual(self.request()[0], 502)

    def test_preflight_and_health_are_not_model_inference(self):
        status, headers, _ = self.request(method='OPTIONS', headers={'Origin': self.origin})
        self.assertEqual(status, 200)
        self.assertEqual(headers['Access-Control-Allow-Private-Network'], 'true')
        status, _, health = self.request(method='GET', path='/health')
        self.assertEqual(status, 200)
        self.assertFalse(health['inference_verified'])
        self.assertFalse(self.agent.calls)

    def test_wrong_path_and_content_type(self):
        self.assertEqual(self.request(path='/v1/classify')[0], 404)
        self.assertEqual(self.request(headers={'Content-Type': 'text/plain'})[0], 415)
        self.assertFalse(self.agent.calls)

    def test_wildcard_origin_configuration_is_rejected(self):
        with self.assertRaises(ValueError):
            make_server(self.agent, port=0, allowed_origin='*')


if __name__ == '__main__':
    unittest.main()
