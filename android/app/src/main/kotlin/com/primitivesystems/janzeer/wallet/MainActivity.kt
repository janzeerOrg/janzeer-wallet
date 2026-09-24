package com.primitivesystems.janzeer.wallet

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity, not FlutterActivity: local_auth's BiometricPrompt needs a FragmentActivity — with the plain
// activity every fingerprint tap threw `no_fragment_activity` and the lock screen sat there (owner, 2026-09-23).
class MainActivity : FlutterFragmentActivity()
