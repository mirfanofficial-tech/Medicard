import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../ui/widgets.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _topics = <(IconData, String, String)>[
    (Icons.upload_file, 'How to upload records',
        'Tap Scan, photograph the document, then review the extracted details and confirm.'),
    (Icons.ios_share, 'How sharing works',
        'Share your MediCard code with a doctor. They request access; you approve each time, '
        'and every view is logged in Access History.'),
    (Icons.shield_outlined, 'Privacy & security',
        'Only you can see your full record. A doctor sees it only while an approved, '
        'time-limited grant is active. Sensitive entries stay hidden by default.'),
    (Icons.auto_awesome, 'How AI summaries work',
        'The AI summarises your records and flags things worth a doctor\'s attention. '
        'It never diagnoses and never prescribes.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('How can we help you?', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          const SectionHeader('Popular topics'),
          for (final (icon, title, body) in _topics)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ExpansionTile(
                shape: const RoundedRectangleBorder(),
                leading: Icon(icon, color: MediCardColors.primary),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [Align(alignment: Alignment.centerLeft, child: Text(body))],
              ),
            ),
          const SizedBox(height: 8),
          const InfoBanner(
            'Still stuck? Email support@medicard.example — this is a hackathon build, so '
            'responses are best-effort.',
          ),
        ],
      ),
    );
  }
}
