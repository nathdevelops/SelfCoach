import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers.dart';
import '../../app/router.dart';

/// A single step in the tutorial walkthrough.
class _TutorialStep {
  final IconData icon;
  final String title;
  final String description;

  const _TutorialStep({
    required this.icon,
    required this.title,
    required this.description,
  });
}

const List<_TutorialStep> _steps = [
  _TutorialStep(
    icon: Icons.smartphone,
    title: 'Set up your phone',
    description:
        'Prop your phone against a surface or stand so the front camera faces the area where you train.',
  ),
  _TutorialStep(
    icon: Icons.play_circle_filled,
    title: 'Tap "Start Monitoring"',
    description:
        'SelfCoach will watch through the front camera, ready to detect your movements automatically.',
  ),
  _TutorialStep(
    icon: Icons.accessibility_new,
    title: 'Step fully into frame',
    description:
        'Make sure your full body is visible — head, shoulders, hips, knees, and feet. '
        'You\'ll see "Monitoring..." when you\'re in position.',
  ),
  _TutorialStep(
    icon: Icons.sports,
    title: 'Perform your movement',
    description:
        'Execute your golf swing, squat, punch, or any athletic movement. '
        'SelfCoach auto-records when it detects significant motion — no button tapping needed.',
  ),
  _TutorialStep(
    icon: Icons.photo_library,
    title: 'Review your clips',
    description:
        'Find every auto-recorded clip in the Gallery. Tap to play, rename, tag, '
        'or delete — all stored locally on your device.',
  ),
];

/// Screen 0: Tutorial — mandatory on first launch (PRD §4, Screen 0).
///
/// Navigates to [CameraMonitorScreen] on "Get Started" and marks the tutorial
/// as seen via [SharedPreferences].
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _complete();
    }
  }

  void _back() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _complete() async {
    await markTutorialComplete();
    if (mounted) context.go(AppRoutes.cameraMonitor);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: List.generate(_steps.length, (i) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: i <= _currentPage
                            ? const Color(0xFF00C853)
                            : Colors.white24,
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Slides
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics:
                    const NeverScrollableScrollPhysics(), // nav via buttons only
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _steps.length,
                itemBuilder: (_, i) => _StepPage(step: _steps[i]),
              ),
            ),

            // Navigation buttons
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    OutlinedButton(
                      onPressed: _back,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                      ),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    key: const Key('tutorial_next_button'),
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    child: Text(
                      _currentPage == _steps.length - 1
                          ? 'Get Started'
                          : 'Next',
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

class _StepPage extends StatelessWidget {
  final _TutorialStep step;

  const _StepPage({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00C853).withOpacity(0.15),
              border: Border.all(
                  color: const Color(0xFF00C853).withOpacity(0.5), width: 2),
            ),
            child: Icon(step.icon,
                size: 60, color: const Color(0xFF00C853)),
          ),
          const SizedBox(height: 40),
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            step.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
