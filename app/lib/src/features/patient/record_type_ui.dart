import 'package:flutter/material.dart';

import '../../theme.dart';

class RecordTypeUi {
  const RecordTypeUi(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

RecordTypeUi recordTypeUi(String type) => switch (type) {
      'prescription' => const RecordTypeUi('Prescription', Icons.receipt_long, MediCardColors.success),
      'lab' => const RecordTypeUi('Lab Report', Icons.science_outlined, Color(0xFF7C3AED)),
      'imaging' => const RecordTypeUi('Imaging', Icons.image_outlined, Color(0xFF2563EB)),
      _ => const RecordTypeUi('Note', Icons.sticky_note_2_outlined, MediCardColors.muted),
    };
