import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// First-run education. Completion is stored per authenticated customer.
class WathaqOnboardingGate extends StatefulWidget {
  const WathaqOnboardingGate({super.key, required this.userId, required this.child});
  final String userId;
  final Widget child;

  @override
  State<WathaqOnboardingGate> createState() => _WathaqOnboardingGateState();
}

class _WathaqOnboardingGateState extends State<WathaqOnboardingGate> {
  bool? _completed;

  String get _key => 'wathaq.onboarding.completed.v1.${widget.userId}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _completed = prefs.getBool(_key) ?? false);
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    if (mounted) setState(() => _completed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_completed == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _completed!
        ? widget.child
        : WathaqOnboardingScreen(onFinished: _finish);
  }
}

class WathaqOnboardingScreen extends StatefulWidget {
  const WathaqOnboardingScreen({super.key, required this.onFinished});
  final VoidCallback onFinished;

  @override
  State<WathaqOnboardingScreen> createState() => _WathaqOnboardingScreenState();
}

class _WathaqOnboardingScreenState extends State<WathaqOnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _steps = <_OnboardingStep>[
    _OnboardingStep(
      icon: Icons.stars_rounded,
      title: 'نقاطك ومستوى عضويتك',
      description: 'تابع رصيد نقاطك ومستوى عضويتك من الصفحة الرئيسية. كلما شاركت في برامج الولاء، اقتربت من مزايا ومكافآت أكثر.',
    ),
    _OnboardingStep(
      icon: Icons.storefront_rounded,
      title: 'اكتشف المتاجر وانضم إليها',
      description: 'تعرّف على المتاجر المشاركة وبرامج الولاء المتاحة، ثم انضم إلى البرنامج المناسب لتبدأ جمع النقاط.',
    ),
    _OnboardingStep(
      icon: Icons.card_giftcard_rounded,
      title: 'اجمع النقاط واستبدل المكافآت',
      description: 'اجمع النقاط من مشترياتك المؤهلة لدى المتاجر المشاركة، ثم استخدم رصيدك لاستبدال المكافآت المتاحة وفق شروط كل متجر.',
    ),
    _OnboardingStep(
      icon: Icons.qr_code_2_rounded,
      title: 'رمز QR يجعلها أسهل',
      description: 'اعرض رمزك من زر QR داخل التطبيق لدى موظف المتجر لإتمام عملية التحقق أو تسجيل النقاط. لا تشارك الرمز إلا أثناء العملية داخل المتجر.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _steps.length - 1) {
      widget.onFinished();
      return;
    }
    _controller.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            children: [
              Row(
                children: [
                  const Spacer(),
                  TextButton(onPressed: widget.onFinished, child: const Text('تخطي التعليم')),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _steps.length,
                  onPageChanged: (index) => setState(() => _page = index),
                  itemBuilder: (context, index) {
                    final step = _steps[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 154,
                          height: 154,
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: .08),
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.secondary.withValues(alpha: .45), width: 2),
                          ),
                          child: Icon(step.icon, size: 76, color: colors.primary),
                        ),
                        const SizedBox(height: 38),
                        Text(step.title, textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
                        const SizedBox(height: 16),
                        Text(step.description, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_steps.length, (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: index == _page ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: index == _page ? colors.primary : colors.outlineVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                )),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(_page == _steps.length - 1 ? 'ابدأ استخدام وثاق' : 'التالي'),
                ),
              ),
              const SizedBox(height: 8),
              Text('${_page + 1} من ${_steps.length}', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingStep {
  const _OnboardingStep({required this.icon, required this.title, required this.description});
  final IconData icon;
  final String title;
  final String description;
}
