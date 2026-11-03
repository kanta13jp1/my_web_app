"""Fail-closed, synthetic loopback-only Chrome/ChromeDriver smoke diagnostic."""
import contextlib
import http.server
import json
import subprocess
import threading
import time
import urllib.error
import urllib.request


class Page(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        payload = b'<html><head><title>dining-loopback-ok</title></head><body>synthetic</body></html>'
        self.send_response(200)
        self.send_header('Content-Type', 'text/html')
        self.send_header('Content-Length', str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *_args):
        pass


def request(path, payload=None):
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(
        'http://127.0.0.1:4444' + path,
        data=data,
        headers={'Content-Type': 'application/json'},
        method='GET' if payload is None else 'POST',
    )
    with urllib.request.urlopen(req, timeout=25) as response:
        result = json.load(response)
    if 'value' not in result or (isinstance(result['value'], dict) and 'error' in result['value']):
        raise RuntimeError('WebDriver returned an error')
    return result['value']


def main():
    server = http.server.HTTPServer(('127.0.0.1', 0), Page)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    driver = subprocess.Popen(['chromedriver', '--port=4444'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    session = None
    try:
        for _ in range(30):
            try:
                request('/status')
                break
            except (urllib.error.URLError, TimeoutError):
                time.sleep(0.5)
        else:
            raise RuntimeError('ChromeDriver did not start')
        print('driver ready', flush=True)
        session = request('/session', {'capabilities': {'alwaysMatch': {
            'browserName': 'chrome',
            'goog:chromeOptions': {'args': ['--headless=new', '--no-sandbox', '--disable-dev-shm-usage', '--no-proxy-server']},
        }}})['sessionId']
        print('chrome session created', flush=True)
        request('/session/' + session + '/url', {'url': 'http://127.0.0.1:%d/' % server.server_port})
        if request('/session/' + session + '/title') != 'dining-loopback-ok':
            raise RuntimeError('Unexpected synthetic page title')
        print('synthetic loopback navigation passed', flush=True)
    finally:
        if session:
            with contextlib.suppress(Exception):
                req = urllib.request.Request('http://127.0.0.1:4444/session/' + session, method='DELETE')
                with urllib.request.urlopen(req, timeout=5):
                    pass
        driver.terminate()
        try:
            driver.wait(timeout=5)
        except subprocess.TimeoutExpired:
            driver.kill()
            driver.wait(timeout=5)
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)


if __name__ == '__main__':
    main()
