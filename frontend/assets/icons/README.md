# OAuth Provider Icons

Drop the official brand assets from each provider here:

- `google.svg` (or `google.png`) — download from Google's official sign-in branding page:
  https://developers.google.com/identity/branding-guidelines

- `apple.svg` (or `apple.png`) — download from Apple's Sign in with Apple HIG:
  https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple

Both providers explicitly publish these assets for use in third-party OAuth buttons.
Using their official artwork keeps you compliant with their branding requirements.

Until the files exist, the login screen falls back to Flutter's built-in `Icons.apple`
and a generic Material icon for Google — buttons remain clickable.
