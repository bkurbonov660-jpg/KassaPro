import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../store.dart';
import '../main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String? selected;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppStore>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.line)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 64, height: 64, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.track_changes, color: Colors.white, size: 32)),
              const SizedBox(height: 18),
              const Text('GoalFlow', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text)),
              const SizedBox(height: 8),
              const Text('Выбери валюту по умолчанию. Всё будет автоматически конвертироваться в неё.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.5)),
              const SizedBox(height: 24),
              const Align(alignment: Alignment.centerLeft,
                child: Text('ВАЛЮТА ПО УМОЛЧАНИЮ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 0.4))),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 9, crossAxisSpacing: 9, childAspectRatio: 1.4,
                children: ALL_CUR.map((c) {
                  final on = selected == c;
                  return GestureDetector(
                    onTap: () => setState(() => selected = c),
                    child: Container(
                      decoration: BoxDecoration(
                        color: on ? AppColors.accentSoft : AppColors.panel2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: on ? AppColors.accent : AppColors.line),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(CUR_FLAG[c]!, style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 6),
                        Text('${CUR_SYM[c]} $c', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                        const SizedBox(height: 2),
                        Text(CUR_NAME[c]!, style: const TextStyle(fontSize: 10, color: AppColors.muted), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent, foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.accent.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: selected == null ? null : () => s.setCurrency(selected!),
                  child: const Text('Продолжить', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                )),
            ]),
          ),
        )),
      ),
    );
  }
}
