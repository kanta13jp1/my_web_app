(function installPaddleSandboxBridge() {
  'use strict';

  const paddleScriptUrl = 'https://cdn.paddle.com/paddle/v2/paddle.js';
  let paddleLoadPromise = null;
  let initializedToken = null;
  let activeEventCallback = null;
  const sandboxEventLog = [];

  function loadPaddle() {
    if (window.Paddle) return Promise.resolve(window.Paddle);
    if (paddleLoadPromise) return paddleLoadPromise;

    paddleLoadPromise = new Promise(function(resolve, reject) {
      const existing = document.querySelector(
        'script[src="' + paddleScriptUrl + '"]'
      );
      const script = existing || document.createElement('script');
      const onLoad = function() {
        if (window.Paddle) {
          resolve(window.Paddle);
        } else {
          reject(new Error('Paddle.js loaded without exposing window.Paddle'));
        }
      };
      const onError = function() {
        reject(new Error('Failed to load Paddle.js'));
      };

      script.addEventListener('load', onLoad, { once: true });
      script.addEventListener('error', onError, { once: true });
      if (!existing) {
        script.src = paddleScriptUrl;
        script.async = true;
        script.dataset.paddleSandbox = 'true';
        document.head.appendChild(script);
      }
    }).catch(function(error) {
      paddleLoadPromise = null;
      throw error;
    });

    return paddleLoadPromise;
  }

  function optionalText(value) {
    return typeof value === 'string' && value.length > 0 ? value : null;
  }

  function relayPaddleEvent(event) {
    if (!activeEventCallback || !event) return;
    const data = event.data || {};
    const totals = data.totals || {};
    const business = data.customer && data.customer.business;
    const taxIdentifier = business &&
      (business.tax_identifier || business.taxIdentifier);
    const payload = {
      name: optionalText(event.name) || '',
      checkoutId: optionalText(data.id),
      transactionId: optionalText(data.transaction_id),
      message: optionalText(data.detail) || optionalText(data.message),
      currencyCode: optionalText(data.currency_code || data.currencyCode),
      subtotal: optionalText(totals.subtotal),
      tax: optionalText(totals.tax),
      total: optionalText(totals.total),
      hasBusiness: Boolean(business),
      hasTaxIdentifier: Boolean(taxIdentifier),
    };
    sandboxEventLog.push({
      receivedAt: new Date().toISOString(),
      ...payload,
    });
    activeEventCallback(JSON.stringify(payload));
  }

  window.getPaddleSandboxEventLog = function() {
    return sandboxEventLog.map(function(entry) {
      return { ...entry };
    });
  };

  window.openPaddleSandboxCheckout = async function(
    clientSideToken,
    priceId,
    eventCallback
  ) {
    if (typeof clientSideToken !== 'string' ||
        !clientSideToken.startsWith('test_')) {
      throw new Error('A Paddle sandbox client-side token is required');
    }
    if (typeof priceId !== 'string' || !priceId.startsWith('pri_')) {
      throw new Error('A Paddle sandbox price ID is required');
    }
    if (typeof eventCallback !== 'function') {
      throw new Error('A Paddle event callback is required');
    }

    activeEventCallback = eventCallback;
    const paddle = await loadPaddle();
    paddle.Environment.set('sandbox');

    if (initializedToken === null) {
      paddle.Initialize({
        token: clientSideToken,
        eventCallback: relayPaddleEvent,
      });
      initializedToken = clientSideToken;
    } else if (initializedToken !== clientSideToken) {
      throw new Error('Paddle.js is already initialized with another token');
    }

    paddle.Checkout.open({
      items: [{ priceId: priceId, quantity: 1 }],
      settings: {
        showAddTaxId: true,
      },
    });
  };

  window.releasePaddleSandboxCheckout = function(eventCallback) {
    if (activeEventCallback === eventCallback) {
      activeEventCallback = null;
    }
  };
})();
