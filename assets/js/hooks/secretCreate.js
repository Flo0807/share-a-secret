import { buildSecretUrl, createEncryptedSecret } from '../secretCrypto.js'

export default {
  mounted () {
    this.form = this.el.querySelector('[data-secret-create-target="form"]')
    this.secretInput = this.el.querySelector('[data-secret-create-target="secret"]')
    this.linkCountInput = this.el.querySelector('[data-secret-create-target="link-count"]')
    this.expirationInput = this.el.querySelector('[data-secret-create-target="expiration"]')
    this.submitButton = this.el.querySelector('[data-secret-create-target="submit"]')
    this.loading = this.el.querySelector('[data-secret-create-target="loading"]')
    this.error = this.el.querySelector('[data-secret-create-target="error"]')
    this.results = this.el.querySelector('[data-secret-create-target="results"]')
    this.onSubmit = event => event.preventDefault()
    this.onClick = () => this.createLinks()

    this.form.addEventListener('submit', this.onSubmit)
    this.submitButton.addEventListener('click', this.onClick)

    if (window.isSecureContext && crypto?.subtle && crypto?.randomUUID) {
      for (const control of [this.secretInput, this.linkCountInput, this.expirationInput, this.submitButton]) {
        control.disabled = false
      }
    } else {
      this.showError()
    }
  },

  destroyed () {
    this.form.removeEventListener('submit', this.onSubmit)
    this.submitButton.removeEventListener('click', this.onClick)
  },

  async createLinks () {
    this.hideError()

    if (!this.form.reportValidity()) return

    this.setLoading(true)

    try {
      const linkCount = Number.parseInt(this.linkCountInput.value, 10)
      const expiration = Number.parseInt(this.expirationInput.value, 10)
      const encryptedSecrets = await Promise.all(
        Array.from({ length: linkCount }, () => createEncryptedSecret(this.secretInput.value))
      )

      const reply = await this.pushEvent('create-encrypted-secrets', {
        expiration,
        entries: encryptedSecrets.map(secret => ({
          id: secret.id,
          payload: secret.payload,
          claim_verifier: secret.claimVerifier
        }))
      })

      if (!reply.ok) throw new Error('secret creation failed')

      encryptedSecrets.forEach((secret, index) => {
        const row = this.el.querySelector(`[data-secret-create-link-row="${index}"]`)
        const input = this.el.querySelector(`[data-secret-create-link="${index}"]`)
        input.value = buildSecretUrl(window.location.origin, secret.id, secret.root)
        row.hidden = false
      })

      this.secretInput.value = ''
      this.form.hidden = true
      this.results.hidden = false
    } catch (_error) {
      this.showError()
    } finally {
      this.setLoading(false)
    }
  },

  setLoading (loading) {
    this.submitButton.disabled = loading
    this.loading.hidden = !loading
  },

  showError () {
    this.error.hidden = false
  },

  hideError () {
    this.error.hidden = true
  }
}
