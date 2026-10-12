import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/session_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  // On the web the app is served next to the API, so its own address is the server's.
  final _server = TextEditingController(text: kIsWeb ? Uri.base.origin : 'http://10.0.2.2:8000');
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _step = 0;

  @override
  void dispose() {
    _server.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Semantics(
                header: true,
                child: Text('Günün tek akışı.',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        )),
              ),
              const SizedBox(height: 12),
              Text(
                _step == 0
                    ? 'Takvim, para ve sağlık işlemlerini seçimlerle yönet.'
                    : 'LifeBase hesabına bağlan.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 40),
              if (_step == 0) ...[
                _Feature(icon: Icons.touch_app_rounded, text: 'Yazmak yerine seç'),
                _Feature(icon: Icons.offline_bolt_rounded, text: 'Çevrimdışıyken de devam et'),
                _Feature(icon: Icons.calendar_month_rounded, text: 'Android takvimine eşitle'),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => setState(() => _step = 1),
                  child: const Text('Başla'),
                ),
              ] else ...[
                TextField(
                  controller: _server,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'Sunucu adresi'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-posta'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Şifre'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: session.isLoading
                      ? null
                      : () => ref.read(sessionControllerProvider.notifier).login(
                            serverUrl: _server.text,
                            email: _email.text,
                            password: _password.text,
                          ),
                  child: session.isLoading
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Bağlan'),
                ),
                if (session.hasError || session.value?.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Bağlantı kurulamadı. Bilgileri kontrol et.',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
        ]),
      );
}
