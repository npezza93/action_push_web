import { post } from "@rails/request.js"

export default class Granted extends HTMLElement {
  constructor() {
    super();
  }

  connectedCallback() {
    document.addEventListener('action-push-web:granted', this.attributeChangedCallback.bind(this));
    document.addEventListener('action-push-web:denied', this.attributeChangedCallback.bind(this));
    this.#setState()
  }

  disconnectedCallback() {
    document.removeEventListener('action-push-web:granted', this.attributeChangedCallback.bind(this));
    document.removeEventListener('action-push-web:denied', this.attributeChangedCallback.bind(this));
  }

  attributeChangedCallback() {
    this.#setState()
  }

  async #subscribe() {
    const registration = await this.#serviceWorkerRegistration || await this.#registerServiceWorker()
    registration.pushManager
      .subscribe({ userVisibleOnly: true, applicationServerKey: this.#vapidPublicKey })
      .then(subscription => {
        this.#syncPushSubscription(subscription)
      })
  }

  get #isEnabled() {
    return !!navigator.serviceWorker && !!window.Notification && Notification.permission == "granted"
  }

  get #serviceWorkerRegistration() {
    return navigator.serviceWorker.getRegistration()
  }

  get #vapidPublicKey() {
    const encodedVapidPublicKey = document.querySelector('meta[name="action-push-web-public-key"]').content
    return this.#urlBase64ToUint8Array(encodedVapidPublicKey)
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

  #setState() {
    this.hidden = !this.#isEnabled;
    if (this.#isEnabled) {
      this.#subscribe()
    }
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

  #registerServiceWorker() {
    return navigator.serviceWorker.register(this.getAttribute('service-worker-url'))
  }
}
