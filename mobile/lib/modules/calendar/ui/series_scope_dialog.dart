import 'package:flutter/material.dart';

import '../data/events_repository.dart';

/// For a repeating event: apply to this occurrence, this and later ones, or
/// the whole series. Returns null when cancelled.
Future<SeriesScope?> askSeriesScope(BuildContext context, {required String verb}) => showModalBottomSheet<SeriesScope>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Tekrarlanan etkinlik', style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final (scope, label) in [
            (SeriesScope.thisOne, 'Sadece bu'),
            (SeriesScope.thisAndFollowing, 'Bu ve sonrakiler'),
            (SeriesScope.all, 'Tüm seri'),
          ])
            ListTile(
              minTileHeight: 56,
              title: Text('$label · $verb'),
              onTap: () => Navigator.pop(sheetContext, scope),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
