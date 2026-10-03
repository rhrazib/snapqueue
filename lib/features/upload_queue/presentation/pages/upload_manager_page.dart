import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../domain/entities/upload_item.dart';
import '../../domain/usecases/sync_upload_queue.dart';
import '../bloc/upload_manager_bloc.dart';

class UploadManagerPage extends StatelessWidget {
  const UploadManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Manager'),
        actions: [
          BlocSelector<UploadManagerBloc, UploadManagerState, bool>(
            selector: (s) => s.online,
            builder: (_, online) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _LinkChip(online: online),
            ),
          ),
        ],
      ),
      body: BlocBuilder<UploadManagerBloc, UploadManagerState>(
        builder: (context, state) {
          final bloc = context.read<UploadManagerBloc>();
          return Column(
            children: [
              _SummaryCard(state: state),
              _ListHeader(
                state: state,
                onRetry: () => bloc.add(const RetryFailedPressed()),
                onClear: () => bloc.add(const ClearSyncedPressed()),
              ),
              Expanded(
                child: state.items.isEmpty
                    ? const _EmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: state.items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _UploadTile(
                          item: state.items[i],
                          online: state.online,
                        ),
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.photo_camera_outlined, size: 20),
                      label: const Text('START NEW UPLOAD BATCH'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    return _Pill(
      color: online ? AppColors.success : AppColors.danger,
      label: online ? 'Online' : 'Offline',
    );
  }
}

/// Tinted pill with a status dot, used for link state and item state.
class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.state});

  final UploadManagerState state;

  @override
  Widget build(BuildContext context) {
    final percent = (state.progress * 100).round();
    final waiting = !state.online && state.pendingCount > 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BATCH SYNC PROGRESS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 32,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${formatBytes(state.doneBytes)} / ${formatBytes(state.totalBytes)} uploaded',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: state.progress,
              minHeight: 6,
              backgroundColor: AppColors.surfaceHigh,
              color: AppColors.primary,
            ),
          ),
          if (waiting) ...[
            const SizedBox(height: 14),
            const Row(
              children: [
                Icon(Icons.wifi_off_rounded, size: 16, color: AppColors.warning),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You are offline. Uploads resume automatically.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.warning),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({
    required this.state,
    required this.onRetry,
    required this.onClear,
  });

  final UploadManagerState state;
  final VoidCallback onRetry;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'PENDING UPLOADS (${state.pendingCount})',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
                color: AppColors.textMuted,
              ),
            ),
          ),
          if (state.hasFailed)
            TextButton(onPressed: onRetry, child: const Text('Retry failed')),
          if (state.syncedCount > 0)
            TextButton(onPressed: onClear, child: const Text('Clear synced')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.surfaceHigh,
              child: Icon(
                Icons.cloud_done_outlined,
                size: 34,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Nothing queued',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Photos you upload appear here and sync automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({required this.item, required this.online});

  final UploadItem item;
  final bool online;

  ({String text, Color color}) get _status => switch (item.status) {
        UploadStatus.pending => online
            ? (text: 'Queued', color: AppColors.textSecondary)
            : (text: 'Waiting for connection', color: AppColors.warning),
        UploadStatus.retrying => (
            text:
                'Retrying - attempt ${item.attempts + 1}/${SyncUploadQueue.maxAttempts}',
            color: AppColors.warning,
          ),
        UploadStatus.uploading => (
            text: 'Uploading - ${(item.progress * 100).round()}%',
            color: AppColors.primaryLight,
          ),
        UploadStatus.synced => (text: 'Synced', color: AppColors.success),
        UploadStatus.failed => (text: 'Failed', color: AppColors.danger),
      };

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final file = File(item.path);
    final synced = item.status == UploadStatus.synced;

    return Opacity(
      opacity: synced ? 0.65 : 1,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 54,
                height: 54,
                child: file.existsSync()
                    ? Image.file(file, fit: BoxFit.cover, cacheWidth: 140)
                    : ColoredBox(
                        color: AppColors.surfaceHigh,
                        child: Icon(
                          // synced photos are deleted from the device
                          synced
                              ? Icons.cloud_done_outlined
                              : Icons.image_not_supported_outlined,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatBytes(item.sizeBytes),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _Pill(color: status.color, label: status.text),
                  ),
                  if (item.status == UploadStatus.uploading) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: item.progress,
                        minHeight: 4,
                        backgroundColor: AppColors.surfaceHigh,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
