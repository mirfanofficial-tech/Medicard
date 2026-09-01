import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';
import 'records_repository.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  IconData _icon(String type) => switch (type) {
        'prescription' => Icons.medication,
        'lab' => Icons.science,
        'imaging' => Icons.image,
        _ => Icons.note,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(recordsListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline'),
        leading: BackButton(onPressed: () => context.go('/patient')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/patient/records/upload'),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Add record'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(recordsListProvider.future),
        child: records.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 80),
            Center(child: Text('Could not load: $e')),
          ]),
          data: (rows) {
            if (rows.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                Center(child: Text('No records yet. Tap “Add record”.')),
              ]);
            }
            return ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final r = rows[i];
                return ListTile(
                  leading: Icon(_icon(r.type)),
                  title: Text(
                    '${r.type[0].toUpperCase()}${r.type.substring(1)}'
                    '${r.provider != null ? ' · ${r.provider}' : ''}',
                  ),
                  subtitle: Text(r.docDate ?? 'Undated'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (r.sensitive)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.visibility_off, size: 16),
                      ),
                    ProvenanceTag(verified: r.verified),
                  ]),
                  onTap: () => context.go('/patient/records/${r.id}'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
