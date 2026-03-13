# UI Capture Instrumentation

This closes the gap between browser-side actions and Salesforce debug logs.

## What this captures

- LWC load / connected events
- Button clicks
- Navigation events
- Current page URL
- Optional record id
- Extra client context as JSON

These events are persisted to the same capture session and merged into the sequential process run timeline.

## Endpoint

- `POST http://127.0.0.1:8001/sf-repo-ai/process-capture/ui-event`

## Browser snippet

Run this in the browser console after `process-capture/start` returns a `capture_id`:

```javascript
window.sfRepoAiCapture = async function sfRepoAiCapture(eventType, payload = {}) {
  const body = {
    capture_id: window.__SF_CAPTURE_ID__,
    event_type: eventType,
    component_name: payload.componentName || null,
    action_name: payload.actionName || null,
    element_label: payload.elementLabel || null,
    page_url: window.location.href,
    record_id: payload.recordId || null,
    details: payload.details || {},
    event_ts: new Date().toISOString()
  };

  const res = await fetch("http://127.0.0.1:8001/sf-repo-ai/process-capture/ui-event", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body)
  });

  return res.json();
};
```

Set the active capture id:

```javascript
window.__SF_CAPTURE_ID__ = "<capture-id>";
```

Record common events:

```javascript
sfRepoAiCapture("LWC_CONNECTED", {
  componentName: "c:createNattOppLwc",
  actionName: "connectedCallback"
});

sfRepoAiCapture("BUTTON_CLICK", {
  componentName: "c:createNattOppLwc",
  actionName: "Next",
  elementLabel: "Next"
});

sfRepoAiCapture("NAVIGATE", {
  componentName: "c:createNattOppLwc",
  actionName: "Open Quote"
});
```

## LWC integration pattern

If you decide to instrument a real LWC later, call the same endpoint from:

- `connectedCallback()`
- important button handlers like `handleNextClick()`
- submit/save handlers
- navigation handlers

## Expected outcome after stop + extraction

The run timeline will contain both:

- `LWC_COMPONENT` entries such as `c:createNattOppLwc`
- `UI_ACTION` entries such as `Next`, `Submit`, `Navigate`
- server-side components from logs like Apex classes, flows, approvals, and DML objects

This gives a single ordered sequence:

`UI action -> Apex/debug transaction -> downstream technical components`
