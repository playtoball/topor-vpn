import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/utils/number_formatters.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// TOPOR VPN: mini-app style traffic tiles shown on the home screen while connected.
class HomeTrafficCard extends ConsumerWidget {
  const HomeTrafficCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(
      connectionNotifierProvider.select((v) => v.valueOrNull == const Connected()),
    );
    if (!connected) return const SizedBox.shrink();

    final t = ref.watch(translationsProvider).requireValue;
    final stats = ref.watch(statsNotifierProvider).asData?.value ?? SystemInfo.create();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _TrafficTile(
              icon: FluentIcons.arrow_download_16_filled,
              color: const Color(0xFF32D583),
              value: stats.downlink.toInt().speed(),
              total: stats.downlinkTotal.toInt().size(),
              label: t.components.stats.downlink,
            ),
          ),
          const Gap(12),
          Expanded(
            child: _TrafficTile(
              icon: FluentIcons.arrow_upload_16_filled,
              color: const Color(0xFFFF7A3D),
              value: stats.uplink.toInt().speed(),
              total: stats.uplinkTotal.toInt().size(),
              label: t.components.stats.uplink,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrafficTile extends StatelessWidget {
  const _TrafficTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.total,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const Gap(8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Gap(10),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(fontFamily: 'Oswald', fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            total,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
