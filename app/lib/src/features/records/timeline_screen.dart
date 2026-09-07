import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';
import 'records_repository.dart';

final _filterProvider = StateProvider.autoDispose<String?>((_) => null);

const _types = ['prescription', 'lab', 'imaging', 'note'];

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
    final filter = ref.watch(_filterProvider);
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
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: filter == null,
                  onSelected: (_) => ref.read(_filterProvider.notifier).state = null,
                ),
                for (final t in _types) ...[
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: Text('${t[0].toUpperCase()}${t.substring(1)}'),
                    selected: filter == t,
                    onSelected: (_) => ref.read(_filterProvider.notifier).state = t,
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.refresh(recordsListProvider.future),
              child: records.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(children: [
                  const SizedBox(height: 80),
                  Center(child: Text('Could not load: $e')),
                ]),
                data: (all) {
                  final rows =
                      filter == null ? all : all.where((r) => r.type == filter).toList();
                  if (rows.isEmpty) {
                    return ListView(children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Text(all.isEmpty
                            ? 'No records yet. Tap “Add record”.'
                            : 'Nothing of this type.'),
                      ),
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
          ),
        ],
      ),
    );
  }
}
