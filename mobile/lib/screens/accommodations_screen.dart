import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/errors.dart';

/// The accommodation map: what the family does because of the child's anxiety.
class AccommodationsScreen extends StatefulWidget {
  const AccommodationsScreen({super.key, required this.api, required this.child});

  final ApiClient api;
  final Child child;

  @override
  State<AccommodationsScreen> createState() => _AccommodationsScreenState();
}

class _AccommodationsScreenState extends State<AccommodationsScreen> {
  List<Accommodation> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.api.accommodations(widget.child.id);
      if (mounted) {
        setState(() => _items = items);
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<String?> _askForText(String title, String label) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          minLines: 2,
          maxLines: 5,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(Strings.cancel)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text(Strings.save),
          ),
        ],
      ),
    );
  }

  Future<void> _add() async {
    final description = await _askForText(Strings.mapAdd, Strings.mapDescription);
    if (description == null || description.isEmpty) {
      return;
    }
    try {
      final created = await widget.api.addAccommodation(widget.child.id, description);
      if (mounted) {
        setState(() => _items = [..._items, created]);
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
  }

  Future<void> _setStatus(Accommodation item, AccommodationStatus status) async {
    String? plannedChange = item.plannedChange;
    if (status == AccommodationStatus.targeted) {
      plannedChange = await _askForText(Strings.mapSetTarget, Strings.mapPlannedChange);
      if (plannedChange == null || plannedChange.isEmpty) {
        return;
      }
    }

    try {
      final updated = await widget.api.updateAccommodation(widget.child.id, item.id, status, plannedChange);
      if (mounted) {
        setState(() => _items = [for (final i in _items) i.id == updated.id ? updated : i]);
      }
    } on ApiException catch (e) {
      if (mounted) {
        // 409: another accommodation is already the target. The method works on one at a time.
        showError(context, e, fallback: e.status == 409 ? Strings.mapOneAtATime : null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'map-add',
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text(Strings.mapAdd),
      ),
      body: _items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(Strings.mapEmpty,
                    style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: _items.length,
              itemBuilder: (context, index) => _AccommodationCard(item: _items[index], onSetStatus: _setStatus),
            ),
    );
  }
}

class _AccommodationCard extends StatelessWidget {
  const _AccommodationCard({required this.item, required this.onSetStatus});

  final Accommodation item;
  final void Function(Accommodation, AccommodationStatus) onSetStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (label, color) = switch (item.status) {
      AccommodationStatus.active => (Strings.mapStatusActive, scheme.surfaceContainerHighest),
      AccommodationStatus.targeted => (Strings.mapStatusTargeted, scheme.primaryContainer),
      AccommodationStatus.reduced => (Strings.mapStatusReduced, scheme.tertiaryContainer),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(item.description, style: theme.textTheme.bodyLarge)),
                const SizedBox(width: 8),
                Chip(label: Text(label), backgroundColor: color, visualDensity: VisualDensity.compact),
              ],
            ),
            if (item.status == AccommodationStatus.targeted && item.plannedChange != null) ...[
              const SizedBox(height: 8),
              Text(Strings.mapPlannedChange,
                  style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
              Text(item.plannedChange!),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (item.status == AccommodationStatus.active)
                  OutlinedButton(
                    onPressed: () => onSetStatus(item, AccommodationStatus.targeted),
                    child: const Text(Strings.mapSetTarget),
                  ),
                if (item.status == AccommodationStatus.targeted)
                  FilledButton.tonal(
                    onPressed: () => onSetStatus(item, AccommodationStatus.reduced),
                    child: const Text(Strings.mapMarkReduced),
                  ),
                if (item.status != AccommodationStatus.active)
                  TextButton(
                    onPressed: () => onSetStatus(item, AccommodationStatus.active),
                    child: const Text(Strings.mapBackToActive),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
