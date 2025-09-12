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
    return navigator.serviceWorker && window.Notification && Notification.permission == "default" && this.getAttribute("href");
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

// app/assets/javascripts/components/granted.js
class Granted extends HTMLElement {
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
    if (this.isEnabled) {
      this.subscribe();
    }
  }
  async subscribe() {
    const registration = await this.#serviceWorkerRegistration || await this.#registerServiceWorker();
    registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: this.#vapidPublicKey }).then((subscription) => {
      this.#syncPushSubscription(subscription);
    });
  }
  get isEnabled() {
    return !!navigator.serviceWorker && !!window.Notification && Notification.permission == "granted";
  }
  get #serviceWorkerRegistration() {
    return navigator.serviceWorker.getRegistration();
  }
  get #vapidPublicKey() {
    const encodedVapidPublicKey = document.querySelector('meta[name="action-push-web-public-key"]').content;
    return this.#urlBase64ToUint8Array(encodedVapidPublicKey);
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
