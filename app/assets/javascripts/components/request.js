import { post } from "@rails/request.js"

export default class Request extends HTMLElement {
  static observedAttributes = ["href"];

  constructor() {
    super();
  }

  connectedCallback() {
    this.setAttribute('role', 'button');
    this.#setState()

    this.addEventListener('click', this.onClick);
  }

  #setState() {
    if (this.isEnabled) {
      this.removeAttribute('disabled')
    } else {
      this.setAttribute('disabled', true)
    }

    this.hidden = !this.isEnabled;
  }

  disconnectedCallback() {
    this.removeEventListener('click', this.onClick);
  }

  attributeChangedCallback() {
    this.#setState()
  }

  get isEnabled() {
    return navigator.serviceWorker && window.Notification && Notification.permission == "default" && this.getAttribute('href')
  }

  get #isDisabled() {
    return this.hasAttribute('disabled')
  }

  async onClick(event) {
    event.preventDefault();
    event.stopPropagation();

    if (this.isEnabled && !this.isDisabled) {
      const permission = await Notification.requestPermission()
      if (permission === "granted") {
        const registration = await this.#serviceWorkerRegistration || await this.#registerServiceWorker()
        await this.#subscribe(registration)
      } else if (permission === "denied") {
        document.dispatchEvent(new CustomEvent('action-push-web:denied', {}))
      }
    }
  }

  async #subscribe(registration) {
    registration.pushManager
      .subscribe({ userVisibleOnly: true, applicationServerKey: this.#vapidPublicKey })
      .then(subscription => {
        this.#syncPushSubscription(subscription)
        document.dispatchEvent(new CustomEvent('action-push-web:granted', { detail: subscription }))
        this.hidden = true
      })
  }

  async #syncPushSubscription(subscription) {
    const response = await post(this.getAttribute('href'), {
      body: this.#extractJsonPayloadAsString(subscription),
    })

    if (!response.ok) {
      subscription.unsubscribe()
    }
  }

  #extractJsonPayloadAsString(subscription) {
    const { endpoint, keys: { p256dh, auth } } = subscription.toJSON()

    return JSON.stringify({ push_subscription: { endpoint, p256dh_key: p256dh, auth_key: auth } })
  }

  get #serviceWorkerRegistration() {
    return navigator.serviceWorker.getRegistration()
  }

  #registerServiceWorker() {
    return navigator.serviceWorker.register(this.getAttribute('service-worker-url') || "/service-worker.js")
  }

  get #vapidPublicKey() {
    const encodedVapidPublicKey = document.querySelector('meta[name="action-push-web-public-key"]').content
    return this.#urlBase64ToUint8Array(encodedVapidPublicKey)
  }

  // VAPID public key comes encoded as base64 but service worker registration needs it as a Uint8Array
  #urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - base64String.length % 4) % 4)
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")

    const rawData = window.atob(base64)
    const outputArray = new Uint8Array(rawData.length)

    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i)
    }

    return outputArray
  }
}
