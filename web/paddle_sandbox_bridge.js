(function () {
  'use strict';

  const paddleScriptUrl = 'https://cdn.paddle.com/paddle/v2/paddle.js';
  const sandboxTokenPattern = /^test_[a-zA-Z0-9]{27}$/;
  const priceIdPattern = /^pri_[a-z0-9]+$/;

  let scriptPromise = null;
  let initializedToken = null;
  let eventSink = null;

  function loadPaddleJs() {
    if (window.Paddle) return Promise.resolve(window.Paddle);
    if (scriptPromise) return scriptPromise;

    scriptPromise = new Promise(function (resolve, reject) {
      const existing = document.querySelector('script[data-paddle-sandbox-sdk]');
      if (existing) {
        existing.addEventListener('load', function () {
          if (window.Paddle) resolve(window.Paddle);
          else reject(new Error('Paddle.js loaded without a Paddle global'));
        }, { once: true });
        existing.addEventListener('error', function () {
          reject(new Error('Paddle.js failed to load'));
        }, { once: true });
        return;
      }

      const script = document.createElement('script');
      script.src = paddleScriptUrl;
      script.async = true;
      script.crossOrigin = 'anonymous';
      script.referrerPolicy = 'strict-origin-when-cross-origin';
      script.dataset.paddleSandboxSdk = 'true';
      script.onload = function () {
        if (window.Paddle) resolve(window.Paddle);
        else reject(new Error('Paddle.js loaded without a Paddle global'));
      };
      script.onerror = function () {
        reject(new Error('Paddle.js failed to load'));
      };
      document.head.appendChild(script);
    });

    return scriptPromise;
  }

  function forwardEvent(event) {
    if (!eventSink) return;

    const data = event && typeof event.data === 'object' && event.data
      ? event.data
      : {};
    const error = event && typeof event.error === 'object' && event.error
      ? event.error
      : {};
    const eventName = String((event && event.name) || 'checkout.error');
    const transactionId = String(
      data.transaction_id || data.transactionId || ''
    );
    const message = String(
      error.detail || error.message || data.message || (event && event.message) || ''
    ).slice(0, 240);

    eventSink(eventName, transactionId, message);
  }

  async function initialize(clientSideToken, onEvent) {
    if (!sandboxTokenPattern.test(String(clientSideToken || ''))) {
      throw new Error('A valid Paddle sandbox client-side token is required');
    }
    if (typeof onEvent !== 'function') {
      throw new Error('A Paddle event callback is required');
    }

    eventSink = onEvent;
    const paddle = await loadPaddleJs();

    if (initializedToken && initializedToken !== clientSideToken) {
      throw new Error('Paddle.js was already initialized with another token');
    }
    if (!initializedToken) {
      paddle.Environment.set('sandbox');
      paddle.Initialize({
        token: clientSideToken,
        eventCallback: forwardEvent
      });
      initializedToken = clientSideToken;
    }

    return 'initialized';
  }

  async function openCheckout(priceId, successUrl) {
    if (!initializedToken) {
      throw new Error('Paddle sandbox is not initialized');
    }
    if (!priceIdPattern.test(String(priceId || ''))) {
      throw new Error('A valid Paddle sandbox price ID is required');
    }

    const parsedSuccessUrl = new URL(String(successUrl || ''), window.location.href);
    if (!['http:', 'https:'].includes(parsedSuccessUrl.protocol)) {
      throw new Error('The Paddle success URL must use HTTP(S)');
    }
    if (parsedSuccessUrl.origin !== window.location.origin) {
      throw new Error('The Paddle success URL must use the current origin');
    }

    window.Paddle.Checkout.open({
      items: [{ priceId: priceId, quantity: 1 }],
      settings: {
        displayMode: 'overlay',
        locale: 'ja',
        showAddTaxId: true,
        successUrl: parsedSuccessUrl.href
      }
    });

    return 'opened';
  }

  window.paddleSandboxBridge = Object.freeze({
    initialize: initialize,
    openCheckout: openCheckout
  });
})();
