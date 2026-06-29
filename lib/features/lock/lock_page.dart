import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/lock/lock_controller.dart';
import '../../core/responsive/responsive.dart';

/// App-lock screen: PIN entry or biometric prompt releases the cached vault password and unlocks.
class LockPage extends StatefulWidget {
  const LockPage({super.key});
  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  final _lock = Get.find<LockController>();
  final _pin = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (_lock.mode.value == 'biometric') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _biometric());
    }
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _biometric() async {
    setState(() => _busy = true);
    try {
      if (await _lock.unlockWithBiometric()) Get.offAllNamed(Routes.home);
    } catch (_) {
      // user can retry
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pinUnlock() async {
    if (_pin.text.isEmpty) return;
    setState(() => _busy = true);
    try {
      if (await _lock.unlockWithPin(_pin.text)) {
        Get.offAllNamed(Routes.home);
      } else {
        Get.snackbar('', 'incorrect_password'.tr, snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final biometric = _lock.mode.value == 'biometric';
    return Scaffold(
      body: SafeArea(
        child: ContentColumn(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(biometric ? Icons.fingerprint : Icons.pin, size: 56),
                const SizedBox(height: 12),
                Text('wallet_locked_unlock'.tr, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 24),
                if (biometric)
                  FilledButton.icon(
                    onPressed: _busy ? null : _biometric,
                    icon: const Icon(Icons.fingerprint),
                    label: Text('unlock'.tr),
                  )
                else ...[
                  TextField(
                    controller: _pin,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'enter_pin'.tr),
                    onSubmitted: (_) => _pinUnlock(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(onPressed: _busy ? null : _pinUnlock, icon: const Icon(Icons.lock_open), label: Text('unlock'.tr)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
