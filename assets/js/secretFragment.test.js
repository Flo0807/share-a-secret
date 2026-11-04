import assert from 'node:assert/strict'
import { afterEach, test } from 'node:test'

import { captureSecretFragment, takeSecretFragment } from './secretFragment.js'

afterEach(() => takeSecretFragment())

test('captures and scrubs every fragment before LiveView can read it', () => {
  const calls = []
  const browser = {
    location: {
      hash: '#v1.sensitive-root',
      pathname: '/secret-id',
      search: '?legacy=value'
    },
    history: {
      state: { navigation: 1 },
      replaceState: (...args) => calls.push(args)
    }
  }

  captureSecretFragment(browser)

  assert.deepEqual(calls, [[browser.history.state, '', '/secret-id?legacy=value']])
  assert.equal(takeSecretFragment(), '#v1.sensitive-root')
  assert.equal(takeSecretFragment(), null)
})

test('also scrubs malformed fragments and leaves fragment-free URLs alone', () => {
  const calls = []
  const browser = {
    location: { hash: '#malformed', pathname: '/', search: '' },
    history: { state: null, replaceState: (...args) => calls.push(args) }
  }

  captureSecretFragment(browser)
  assert.equal(calls.length, 1)
  assert.equal(takeSecretFragment(), '#malformed')

  browser.location.hash = ''
  captureSecretFragment(browser)
  assert.equal(calls.length, 1)
  assert.equal(takeSecretFragment(), '')
})
