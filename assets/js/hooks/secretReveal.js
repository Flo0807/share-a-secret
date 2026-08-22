import {
  clearBytes,
  decryptEncryptedSecret,
  deriveClaimKey,
  parseRootFragment,
  PROTOCOL_VERSION
} from '../secretCrypto.js'
import { takeSecretFragment } from '../secretFragment.js'

export default {
  mounted () {
    this.button = this.el.querySelector('[data-secret-reveal-target="button"]')
    this.loading = this.el.querySelector('[data-secret-reveal-target="loading"]')
    this.error = this.el.querySelector('[data-secret-reveal-target="error"]')
    this.output = this.el.querySelector('[data-secret-reveal-target="output"]')
    this.textarea = this.el.querySelector('[data-secret-reveal-target="textarea"]')
    this.onClick = () => this.reveal()
    this.button.addEventListener('click', this.onClick)

    try {
      this.root = parseRootFragment(takeSecretFragment() || '')
      this.button.disabled = false
    } catch (_error) {
      this.showError()
    }
  },

  destroyed () {
    this.button.removeEventListener('click', this.onClick)
    clearBytes(this.root)
  },

  async reveal () {
    this.error.hidden = true
    this.setLoading(true)

    try {
      const id = this.el.dataset.secretId
      const claimKey = await deriveClaimKey(id, this.root)
      const reply = await this.pushEvent('claim-encrypted-secret', { claim_key: claimKey })

      if (!reply.ok || reply.version !== PROTOCOL_VERSION) {
        throw new Error('secret claim failed')
      }

      const secret = await decryptEncryptedSecret(id, reply.payload, this.root)
      this.textarea.value = secret
      this.textarea.dispatchEvent(new Event('input', { bubbles: true }))
      this.button.hidden = true
      this.output.hidden = false
      clearBytes(this.root)
      this.root = null
    } catch (_error) {
      this.showError()
    } finally {
      this.setLoading(false)
    }
  },

  setLoading (loading) {
    this.button.disabled = loading
    this.loading.hidden = !loading
  },

  showError () {
    this.error.hidden = false
  }
}
