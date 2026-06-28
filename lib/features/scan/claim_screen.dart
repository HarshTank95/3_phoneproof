import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/report.dart';
import '../../ui/glass_card.dart';
import '../../ui/theme.dart';
import '../../ui/transitions.dart';
import 'scan_screen.dart';

/// Optional claim entry. For buyers this powers the "claimed vs real" payoff;
/// for sellers it's the spec they want to prove. Everything is skippable.
class ClaimScreen extends StatefulWidget {
  final ScanMode mode;
  const ClaimScreen({super.key, required this.mode});

  @override
  State<ClaimScreen> createState() => _ClaimScreenState();
}

class _ClaimScreenState extends State<ClaimScreen> {
  final _model = TextEditingController();
  final _imei = TextEditingController();
  double _ageMonths = 12;
  bool _ageEnabled = false;
  String? _condition;
  String? _tier;

  @override
  void dispose() {
    _model.dispose();
    _imei.dispose();
    super.dispose();
  }

  bool get _isBuyer => widget.mode == ScanMode.buyer;

  void _start() {
    final claim = Claim(
      model: _model.text.trim().isEmpty ? null : _model.text.trim(),
      ageMonths: _ageEnabled ? _ageMonths.round() : null,
      condition: _condition,
      claimedTier: _tier,
    );
    Navigator.of(context).push(sharedAxisRoute(
      context,
      ScanScreen(
        mode: widget.mode,
        claim: claim,
        imei: _imei.text.trim().isEmpty ? null : _imei.text.trim(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isBuyer ? 'What did the seller claim?' : 'What are you proving?'),
      ),
      body: AppBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(
                _isBuyer
                    ? 'Enter what the seller told you. We’ll hold it against the hardware truth — every field is optional.'
                    : 'Tell us the model and age you’re listing. We’ll back it with measured proof.',
                style: const TextStyle(color: AppColors.textDim, height: 1.4),
              ),
              const SizedBox(height: 20),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Claimed model'),
                    TextField(
                      controller: _model,
                      textCapitalization: TextCapitalization.words,
                      decoration: _dec('e.g. Samsung Galaxy S23'),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _label('Claimed age'),
                        const Spacer(),
                        Switch(
                          value: _ageEnabled,
                          onChanged: (v) => setState(() => _ageEnabled = v),
                        ),
                      ],
                    ),
                    if (_ageEnabled) ...[
                      Text(
                        _ageMonths >= 12
                            ? '${(_ageMonths / 12).toStringAsFixed(_ageMonths % 12 == 0 ? 0 : 1)} years (${_ageMonths.round()} months)'
                            : '${_ageMonths.round()} months',
                        style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
                      ),
                      Slider(
                        value: _ageMonths,
                        min: 1,
                        max: 72,
                        divisions: 71,
                        label: '${_ageMonths.round()}m',
                        onChanged: (v) => setState(() => _ageMonths = v),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Claimed condition'),
                    _chips(
                      ['Like new', 'Good', 'Fair', 'Poor'],
                      _condition,
                      (v) => setState(() => _condition = v),
                    ),
                    const SizedBox(height: 18),
                    _label('Claimed class (helps catch CPU fakes)'),
                    _chips(
                      const ['Flagship', 'Mid-range', 'Budget'],
                      _tier == null
                          ? null
                          : {'flagship': 'Flagship', 'midrange': 'Mid-range', 'budget': 'Budget'}[_tier],
                      (v) => setState(() => _tier = {
                            'Flagship': 'flagship',
                            'Mid-range': 'midrange',
                            'Budget': 'budget'
                          }[v]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('IMEI (optional)'),
                    TextField(
                      controller: _imei,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _dec('Dial *#06# to view'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Third-party apps can’t read IMEI on Android 10+. We store what you type on the certificate but mark it unverifiable.',
                      style: TextStyle(color: AppColors.textDim, fontSize: 11.5, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.radar_rounded),
                label: const Text('Start scan'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  setState(() {
                    _model.clear();
                    _imei.clear();
                    _ageEnabled = false;
                    _condition = null;
                    _tier = null;
                  });
                  _start();
                },
                child: const Text('Skip — just scan the phone'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
      );

  Widget _chips(List<String> options, String? selected, ValueChanged<String?> onSel) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final sel = o == selected;
        return ChoiceChip(
          label: Text(o),
          selected: sel,
          onSelected: (_) => onSel(sel ? null : o),
          selectedColor: AppColors.accent.withValues(alpha: 0.25),
          side: BorderSide(color: sel ? AppColors.accent : AppColors.hairline),
        );
      }).toList(),
    );
  }
}
