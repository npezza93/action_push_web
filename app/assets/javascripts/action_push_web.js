// app/assets/javascripts/components/request.js
class Request extends HTMLElement {
  static observedAttributes = ["href"];
  constructor() {
    super();
  }
  connectedCallback() {
    this.setAttribute("role", "button");
    this.#setState();
    this.addEventListener("click", this.onClick);
  }
  #setState() {
    if (this.isEnabled) {
      this.removeAttribute("disabled");
    } else {
      this.setAttribute("disabled", true);
    }
    this.hidden = !this.isEnabled;
  }
  disconnectedCallback() {
    this.removeEventListener("click", this.onClick);
  }
  attributeChangedCallback() {
    this.#setState();
  }
  get isEnabled() {
    return navigator.serviceWorker && window.Notification && Notification.permission == "default";
  }
  get #isDisabled() {
    return this.hasAttribute("disabled");
  }
  async onClick(event) {
    event.preventDefault();
    event.stopPropagation();
    if (this.isEnabled && !this.isDisabled) {
      const permission = await Notification.requestPermission();
      if (permission === "granted") {
        document.dispatchEvent(new CustomEvent("action-push-web:granted", {}));
      } else if (permission === "denied") {
        document.dispatchEvent(new CustomEvent("action-push-web:denied", {}));
      }
      this.#setState();
    }
  }
}

// app/assets/javascripts/components/denied.js
class Denied extends HTMLElement {
  constructor() {
    super();
  }
  connectedCallback() {
    this.hidden = !this.isEnabled;
    document.addEventListener("action-push-web:granted", this.attributeChangedCallback.bind(this));
    document.addEventListener("action-push-web:denied", this.attributeChangedCallback.bind(this));
  }
  disconnectedCallback() {
    document.removeEventListener("action-push-web:granted", this.attributeChangedCallback.bind(this));
    document.removeEventListener("action-push-web:denied", this.attributeChangedCallback.bind(this));
  }
  attributeChangedCallback() {
    this.hidden = !this.isEnabled;
  }
  get isEnabled() {
    return !navigator.serviceWorker || !window.Notification || Notification.permission == "denied";
  }
}

// node_modules/@rails/request.js/src/fetch_response.js
class FetchResponse {
  constructor(response) {
    this.response = response;
  }
  get statusCode() {
    return this.response.status;
  }
  get redirected() {
    return this.response.redirected;
  }
  get ok() {
    return this.response.ok;
  }
  get unauthenticated() {
    return this.statusCode === 401;
  }
  get unprocessableEntity() {
    return this.statusCode === 422;
  }
  get authenticationURL() {
    return this.response.headers.get("WWW-Authenticate");
  }
  get contentType() {
    const contentType = this.response.headers.get("Content-Type") || "";
    return contentType.replace(/;.*$/, "");
  }
  get headers() {
    return this.response.headers;
  }
  get html() {
    if (this.contentType.match(/^(application|text)\/(html|xhtml\+xml)$/)) {
      return this.text;
    }
    return Promise.reject(new Error(`Expected an HTML response but got "${this.contentType}" instead`));
  }
  get json() {
    if (this.contentType.match(/^application\/.*json$/)) {
      return this.responseJson || (this.responseJson = this.response.json());
    }
    return Promise.reject(new Error(`Expected a JSON response but got "${this.contentType}" instead`));
  }
  get text() {
    return this.responseText || (this.responseText = this.response.text());
  }
  get isTurboStream() {
    return this.contentType.match(/^text\/vnd\.turbo-stream\.html/);
  }
  get isScript() {
    return this.contentType.match(/\b(?:java|ecma)script\b/);
  }
  async renderTurboStream() {
    if (this.isTurboStream) {
      if (window.Turbo) {
        await window.Turbo.renderStreamMessage(await this.text);
      } else {
        console.warn("You must set `window.Turbo = Turbo` to automatically process Turbo Stream events with request.js");
      }
    } else {
      return Promise.reject(new Error(`Expected a Turbo Stream response but got "${this.contentType}" instead`));
    }
  }
  async activeScript() {
    if (this.isScript) {
      const script = document.createElement("script");
      const metaTag = document.querySelector("meta[name=csp-nonce]");
      if (metaTag) {
        const nonce = metaTag.nonce === "" ? metaTag.content : metaTag.nonce;
        if (nonce) {
          script.setAttribute("nonce", nonce);
        }
      }
      script.innerHTML = await this.text;
      document.body.appendChild(script);
    } else {
      return Promise.reject(new Error(`Expected a Script response but got "${this.contentType}" instead`));
    }
  }
}

// node_modules/@rails/request.js/src/request_interceptor.js
class RequestInterceptor {
  static register(interceptor) {
    this.interceptor = interceptor;
  }
  static get() {
    return this.interceptor;
  }
  static reset() {
    this.interceptor = undefined;
  }
}

// node_modules/@rails/request.js/src/lib/utils.js
function getCookie(name) {
  const cookies = document.cookie ? document.cookie.split("; ") : [];
  const prefix = `${encodeURIComponent(name)}=`;
  const cookie = cookies.find((cookie2) => cookie2.startsWith(prefix));
  if (cookie) {
    const value = cookie.split("=").slice(1).join("=");
    if (value) {
      return decodeURIComponent(value);
    }
  }
}
function compact(object) {
  const result = {};
  for (const key in object) {
    const value = object[key];
    if (value !== undefined) {
      result[key] = value;
    }
  }
  return result;
}
function metaContent(name) {
  const element = document.head.querySelector(`meta[name="${name}"]`);
  return element && element.content;
}
function stringEntriesFromFormData(formData) {
  return [...formData].reduce((entries, [name, value]) => {
    return entries.concat(typeof value === "string" ? [[name, value]] : []);
  }, []);
}
function mergeEntries(searchParams, entries) {
  for (const [name, value] of entries) {
    if (value instanceof window.File)
      continue;
    if (searchParams.has(name) && !name.includes("[]")) {
      searchParams.delete(name);
      searchParams.set(name, value);
    } else {
      searchParams.append(name, value);
    }
  }
}

// node_modules/@rails/request.js/src/fetch_request.js
class FetchRequest {
  constructor(method, url, options = {}) {
    this.method = method;
    this.options = options;
    this.originalUrl = url.toString();
  }
  async perform() {
    try {
      const requestInterceptor = RequestInterceptor.get();
      if (requestInterceptor) {
        await requestInterceptor(this);
      }
    } catch (error) {
      console.error(error);
    }
    const fetch = this.responseKind === "turbo-stream" && window.Turbo ? window.Turbo.fetch : window.fetch;
    const response = new FetchResponse(await fetch(this.url, this.fetchOptions));
    if (response.unauthenticated && response.authenticationURL) {
      return Promise.reject(window.location.href = response.authenticationURL);
    }
    if (response.isScript) {
      await response.activeScript();
    }
    const responseStatusIsTurboStreamable = response.ok || response.unprocessableEntity;
    if (responseStatusIsTurboStreamable && response.isTurboStream) {
      await response.renderTurboStream();
    }
    return response;
  }
  addHeader(key, value) {
    const headers = this.additionalHeaders;
    headers[key] = value;
    this.options.headers = headers;
  }
  sameHostname() {
    if (!this.originalUrl.startsWith("http:") && !this.originalUrl.startsWith("https:")) {
      return true;
    }
    try {
      return new URL(this.originalUrl).hostname === window.location.hostname;
    } catch (_) {
      return true;
    }
  }
  get fetchOptions() {
    return {
      method: this.method.toUpperCase(),
      headers: this.headers,
      body: this.formattedBody,
      signal: this.signal,
      credentials: this.credentials,
      redirect: this.redirect,
      keepalive: this.keepalive
    };
  }
  get headers() {
    const baseHeaders = {
      "X-Requested-With": "XMLHttpRequest",
      "Content-Type": this.contentType,
      Accept: this.accept
    };
    if (this.sameHostname()) {
      baseHeaders["X-CSRF-Token"] = this.csrfToken;
    }
    return compact(Object.assign(baseHeaders, this.additionalHeaders));
  }
  get csrfToken() {
    return getCookie(metaContent("csrf-param")) || metaContent("csrf-token");
  }
  get contentType() {
    if (this.options.contentType) {
      return this.options.contentType;
    } else if (this.body == null || this.body instanceof window.FormData) {
      return;
    } else if (this.body instanceof window.File) {
      return this.body.type;
    }
    return "application/json";
  }
  get accept() {
    switch (this.responseKind) {
      case "html":
        return "text/html, application/xhtml+xml";
      case "turbo-stream":
        return "text/vnd.turbo-stream.html, text/html, application/xhtml+xml";
      case "json":
        return "application/json, application/vnd.api+json";
      case "script":
        return "text/javascript, application/javascript";
      default:
        return "*/*";
    }
  }
  get body() {
    return this.options.body;
  }
  get query() {
    const originalQuery = (this.originalUrl.split("?")[1] || "").split("#")[0];
    const params = new URLSearchParams(originalQuery);
    let requestQuery = this.options.query;
    if (requestQuery instanceof window.FormData) {
      requestQuery = stringEntriesFromFormData(requestQuery);
    } else if (requestQuery instanceof window.URLSearchParams) {
      requestQuery = requestQuery.entries();
    } else {
      requestQuery = Object.entries(requestQuery || {});
    }
    mergeEntries(params, requestQuery);
    const query = params.toString();
    return query.length > 0 ? `?${query}` : "";
  }
  get url() {
    return this.originalUrl.split("?")[0].split("#")[0] + this.query;
  }
  get responseKind() {
    return this.options.responseKind || "html";
  }
  get signal() {
    return this.options.signal;
  }
  get redirect() {
    return this.options.redirect || "follow";
  }
  get credentials() {
    return this.options.credentials || "same-origin";
  }
  get keepalive() {
    return this.options.keepalive || false;
  }
  get additionalHeaders() {
    return this.options.headers || {};
  }
  get formattedBody() {
    const bodyIsAString = Object.prototype.toString.call(this.body) === "[object String]";
    const contentTypeIsJson = this.headers["Content-Type"] === "application/json";
    if (contentTypeIsJson && !bodyIsAString) {
      return JSON.stringify(this.body);
    }
    return this.body;
  }
}

// node_modules/@rails/request.js/src/verbs.js
async function post(url, options) {
  const request = new FetchRequest("post", url, options);
  return request.perform();
}

// app/assets/javascripts/components/granted.js
class Granted extends HTMLElement {
  constructor() {
    super();
  }
  connectedCallback() {
    document.addEventListener("action-push-web:granted", this.attributeChangedCallback.bind(this));
    document.addEventListener("action-push-web:denied", this.attributeChangedCallback.bind(this));
    this.#setState();
  }
  disconnectedCallback() {
    document.removeEventListener("action-push-web:granted", this.attributeChangedCallback.bind(this));
    document.removeEventListener("action-push-web:denied", this.attributeChangedCallback.bind(this));
  }
  attributeChangedCallback() {
    this.#setState();
  }
  async#subscribe() {
    const registration = await this.#serviceWorkerRegistration || await this.#registerServiceWorker();
    registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: this.#vapidPublicKey }).then((subscription) => {
      this.#syncPushSubscription(subscription);
    });
  }
  get #isEnabled() {
    return !!navigator.serviceWorker && !!window.Notification && Notification.permission == "granted" && this.getAttribute("href") && this.getAttribute("public-key");
  }
  get #serviceWorkerRegistration() {
    return navigator.serviceWorker.getRegistration();
  }
  get #vapidPublicKey() {
    return this.#urlBase64ToUint8Array(this.getAttribute("public-key"));
  }
  async#syncPushSubscription(subscription) {
    const response = await post(this.getAttribute("href"), {
      body: this.#extractJsonPayloadAsString(subscription)
    });
    if (!response.ok) {
      subscription.unsubscribe();
    }
  }
  #extractJsonPayloadAsString(subscription) {
    const { endpoint, keys: { p256dh, auth } } = subscription.toJSON();
    return JSON.stringify({ push_subscription: { endpoint, p256dh_key: p256dh, auth_key: auth } });
  }
  #setState() {
    this.hidden = !this.#isEnabled;
    if (this.#isEnabled) {
      this.#subscribe();
    }
  }
  #urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - base64String.length % 4) % 4);
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/");
    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);
    for (let i = 0;i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  }
  #registerServiceWorker() {
    return navigator.serviceWorker.register(this.getAttribute("service-worker-url"));
  }
}

// app/assets/javascripts/components/action_push_web.js
customElements.define("action-push-web-request", Request);
customElements.define("action-push-web-denied", Denied);
customElements.define("action-push-web-granted", Granted);
