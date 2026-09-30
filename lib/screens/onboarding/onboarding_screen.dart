import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/primary_button.dart';

/// First-run onboarding, shown once per user (flag stored on their
/// Firestore profile so it follows the account across devices).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _finishing = false;

  static const _slides = <_Slide>[
    _Slide(
      emoji: '🧾',
      gradientColors: [AppColors.indigo, AppColors.indigoDeep],
      title: 'Welcome to SplitMadu',
      message:
          'Track shared expenses with friends and settle debts the easy way. '
          'No more spreadsheet hisabu.',
    ),
    _Slide(
      emoji: '👥',
      gradientColors: [Color(0xFF2D7FF9), Color(0xFF1B5AC5)],
      title: 'Add Your Friends',
      message:
          'Search for friends by name or email and send a friend request. '
          'Once they accept, you can start splitting.',
    ),
    _Slide(
      emoji: '🍛',
      gradientColors: [AppColors.coral, AppColors.coralDeep],
      title: 'Split Expenses',
      message:
          'Record who paid, pick the participants, and SplitMadu instantly '
          'calculates who owes whom. Equal or custom — eshtu aaytu?',
    ),
    _Slide(
      emoji: '✨',
      gradientColors: [Color(0xFF0FA968), Color(0xFF0A7A4B)],
      title: 'Settle Smarter',
      message:
          'Balances update live as you settle up. Smart Settlement even '
          'simplifies tangled debts into the fewest payments.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _page == _slides.length - 1;

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await context.read<AuthProvider>().completeOnboarding();
    // AuthGate reacts to the profile flag and routes to the main app.
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 640;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.m, vertical: AppSpacing.s),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  final content = Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 132,
                        height: 132,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: slide.gradientColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: slide.gradientColors.first
                                  .withValues(alpha: 0.35),
                              blurRadius: 34,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          slide.emoji,
                          style: const TextStyle(fontSize: 62),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        slide.title,
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.m),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Text(
                          slide.message,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 15.5,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  );
                  return Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: isWide ? 48 : AppSpacing.l),
                    child: Center(child: content),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 48 : AppSpacing.l,
                vertical: AppSpacing.m,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _slides.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _page ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? scheme.primary
                                : scheme.outline.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.l),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Row(
                      children: [
                        if (!_isLast)
                          TextButton(
                            onPressed: _finish,
                            child: const Text('Skip'),
                          ),
                        const Spacer(),
                        Expanded(
                          flex: _isLast ? 1 : 0,
                          child: _isLast
                              ? PrimaryButton(
                                  label: 'Get Started',
                                  loading: _finishing,
                                  onPressed: _finish,
                                )
                              : PrimaryButton(
                                  label: 'Next',
                                  expand: false,
                                  onPressed: _next,
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({
    required this.emoji,
    required this.gradientColors,
    required this.title,
    required this.message,
  });

  final String emoji;
  final List<Color> gradientColors;
  final String title;
  final String message;
}
