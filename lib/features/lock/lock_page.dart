import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/lock/lock_controller.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/jz_tokens.dart';
import '../../core/ui/jz.dart';
import '../../core/storage/secure_store.dart';

/// App-lock screen: a PIN pad or the biometric prompt releases the cached account and unlocks instantly.
class LockPage extends StatefulWidget {
  const LockPage({super.key});
  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  final _lock = Get.find<LockController>();
  String _pin = '';
  bool _busy = false;
  bool _shake = false;

  @override
  void initState() {
    super.initState();
    if (_lock.mode.value == 'biometric') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _biometric());
    }
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

  Future<void> _tryPin() async {
    setState(() => _busy = true);
    try {
      if (await _lock.unlockWithPin(_pin)) {
        Get.offAllNamed(Routes.home);
      } else {
        setState(() {
          _shake = true;
          _pin = '';
        });
        jzToast('wrong_pin'.tr, error: true);
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (mounted) setState(() => _shake = false);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _key(String k) {
    if (_busy) return;
    setState(() {
      if (k == '<') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else if (_pin.length < 8) {
        _pin += k;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = JzColors.of(context);
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
                const Center(child: JzMark(size: 64)),
                gap16,
                Text('wallet_locked_unlock'.tr, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                gap8,
                Center(child: JzAddressPill(SecureStore.address)),
                gap24,
                if (biometric) ...[
                  Center(
                    child: Material(
                      color: c.accentWeak,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _busy ? null : _biometric,
                        child: Padding(padding: const EdgeInsets.all(26), child: Icon(Icons.fingerprint, size: 44, color: c.accent)),
                      ),
                    ),
                  ),
                  gap16,
                  JzPrimaryButton(label: 'unlock'.tr, icon: Icons.fingerprint, busy: _busy, onPressed: _busy ? null : _biometric),
                ] else ...[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    transform: Matrix4.translationValues(_shake ? 8 : 0, 0, 0),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (var i = 0; i < 6; i++)
                        Container(
                          width: 14,
                          height: 14,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < _pin.length ? c.accent : c.surface3,
                            border: Border.all(color: i < _pin.length ? c.accent : c.borderStrong),
                          ),
                        ),
                    ]),
                  ),
                  gap24,
                  _PinPad(onKey: _key, onDone: _pin.isEmpty ? null : _tryPin, busy: _busy),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PinPad extends StatelessWidget {
  const _PinPad({required this.onKey, required this.onDone, required this.busy});
  final ValueChanged<String> onKey;
  final VoidCallback? onDone;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = JzColors.of(context);
    Widget key(String k, {IconData? icon, VoidCallback? onTap}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Material(
              color: icon == null ? c.surface : c.surface2,
              borderRadius: JzRadius.rMd,
              child: InkWell(
                borderRadius: JzRadius.rMd,
                onTap: onTap ?? () => onKey(k),
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(borderRadius: JzRadius.rMd, border: Border.all(color: c.border)),
                  child: icon != null
                      ? Icon(icon, color: k == 'ok' ? c.accent : c.muted, size: 22)
                      : Text(k, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: c.text, fontFamily: kMono)),
                ),
              ),
            ),
          ),
        );
    return Column(children: [
      for (final row in const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
      ])
        Row(children: [for (final k in row) key(k)]),
      Row(children: [
        key('<', icon: Icons.backspace_outlined),
        key('0'),
        key('ok', icon: busy ? Icons.hourglass_top : Icons.arrow_forward_rounded, onTap: busy ? () {} : (onDone ?? () {})),
      ]),
    ]);
  }
}
