let capturedFragment = null

export function captureSecretFragment (browser = window) {
  capturedFragment = browser.location.hash

  if (capturedFragment) {
    browser.history.replaceState(
      browser.history.state,
      '',
      browser.location.pathname + browser.location.search
    )
  }
}

export function takeSecretFragment () {
  const fragment = capturedFragment
  capturedFragment = null
  return fragment
}
