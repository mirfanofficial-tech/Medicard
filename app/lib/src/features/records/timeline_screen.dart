import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';
import '../../ui/widgets.dart';
import '../patient/record_type_ui.dart';
import 'models.dart';
import 'records_repository.dart';

final _queryProvider = StateProvider.autoDispose<String>((_) => '');
final _filterProvider = StateProvider.autoDispose<String?>((_) => null);

const _filters = <(String, String?)>[
  ('All', null),
  ('Lab Reports', 'lab'),
  ('Prescriptions', 'prescription'),
  ('Imaging', 'imaging'),
];

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(recordsListProvider);
    final q = ref.watch(_queryProvider).toLowerCase();
    final filter = ref.watch(_filterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Records'), automaticallyImplyLeading: false),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/patient/scan'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => ref.read(_queryProvider.notifier).state = v,
              decoration: const InputDecoration(
                hintText: 'Search your records',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final (label, type) in _filters)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: filter == type,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: filter == type ? Colors.white : MediCardColors.ink,
                      ),
                      onSelected: (_) => ref.read(_filterProvider.notifier).state = type,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(recordsListProvider.future),
              child: records.when(
                loading: () => const LoadingBlock(),
                error: (e, _) => ListView(children: [ErrorBlock(e)]),
                data: (all) {
                  var rows = all;
                  if (filter != null) rows = rows.where((r) => r.type == filter).toList();
                  if (q.isNotEmpty) {
                    rows = rows
                        .where((r) =>
                            r.type.contains(q) ||
                            (r.provider ?? '').toLowerCase().contains(q))
                        .toList();
                  }
                  if (rows.isEmpty) {
                    return ListView(children: [
                      const SizedBox(height: 60),
                      EmptyState(
                        icon: Icons.folder_open,
                        title: all.isEmpty ? 'No records yet' : 'Nothing matches',
                        subtitle: all.isEmpty ? 'Tap + to add a prescription or report.' : null,
                      ),
                    ]);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _RecordCard(rows[i]),
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

class _RecordCard extends StatelessWidget {
  const _RecordCard(this.r);
  final RecordSummary r;

  @override
  Widget build(BuildContext context) {
    final ui = recordTypeUi(r.type);
    return Card(
      child: ListTile(
        onTap: () => context.push('/patient/records/${r.id}'),
        leading: CircleAvatar(
          backgroundColor: ui.color.withOpacity(0.12),
          child: Icon(ui.icon, color: ui.color, size: 20),
        ),
        title: Text(ui.label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text([r.docDate, r.provider].where((e) => e != null).join(' · ')),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ProvenanceTag(verified: r.verified),
            if (r.sensitive)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.visibility_off, size: 14, color: MediCardColors.muted),
              ),
          ],
        ),
      ),
    );
  }
}
