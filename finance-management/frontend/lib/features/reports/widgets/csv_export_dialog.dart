import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';

/// Modal dialog providing CSV file download, direct file-save status, and clipboard copying
class CsvExportDialog extends StatefulWidget {
  final String rangeLabel;
  final String csvContent;
  final String filename;
  final String? savedPath;

  const CsvExportDialog({
    super.key,
    required this.rangeLabel,
    required this.csvContent,
    required this.filename,
    this.savedPath,
  });

  @override
  State<CsvExportDialog> createState() => _CsvExportDialogState();
}

class _CsvExportDialogState extends State<CsvExportDialog> {
  bool _isCopied = false;
  String? _currentSavedPath;
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    _currentSavedPath = widget.savedPath;
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.csvContent));
    setState(() => _isCopied = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ CSV copied to clipboard! You can paste it into Excel or WhatsApp.'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _saveToDownloads() async {
    try {
      // Try standard Android Downloads folder
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) {
        final file = File('${downloadDir.path}/${widget.filename}');
        await file.writeAsString(widget.csvContent);
        setState(() => _currentSavedPath = file.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Saved to Downloads: ${widget.filename}'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        return;
      }

      // Fallback to system temp/documents
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/${widget.filename}');
      await file.writeAsString(widget.csvContent);
      setState(() => _currentSavedPath = file.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to: ${file.path}'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not write directly to disk. Use "Copy CSV" to paste anywhere.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lineCount = widget.csvContent.split('\n').length;
    final byteSize = (widget.csvContent.length / 1024).toStringAsFixed(1);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedLg),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 540.0,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(AppSpacing.md + 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: AppColors.successContainer,
                    borderRadius: AppSpacing.roundedSm,
                  ),
                  child: const Icon(Icons.file_download_done_rounded, color: AppColors.success, size: 24.0),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CSV Export Ready',
                        style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Range: ${widget.rangeLabel}',
                        style: const TextStyle(fontSize: 12.0, color: AppColors.textMutedLight),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(),
            const SizedBox(height: AppSpacing.xs),

            // File Info Tile
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: AppSpacing.roundedSm,
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  const Icon(Icons.table_chart_rounded, size: 28.0, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.filename,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          '$lineCount rows • $byteSize KB • RFC 4180 CSV Format',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textMutedLight),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Save status notification
            if (_currentSavedPath != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: AppColors.successContainer.withAlpha(80),
                  borderRadius: AppSpacing.roundedSm,
                  border: Border.all(color: AppColors.success.withAlpha(120)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16.0),
                    const SizedBox(width: 6.0),
                    Expanded(
                      child: Text(
                        'Downloaded to: $_currentSavedPath',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.success),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            // Action Buttons Row (Full width)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(_isCopied ? Icons.check_rounded : Icons.copy_rounded, size: 16.0),
                    label: Text(_isCopied ? 'Copied!' : 'Copy CSV'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                    onPressed: _copyToClipboard,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    text: 'Save to Downloads',
                    icon: Icons.download_rounded,
                    onPressed: _saveToDownloads,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            // Toggle Preview Button
            TextButton.icon(
              icon: Icon(_showPreview ? Icons.keyboard_arrow_up_rounded : Icons.visibility_outlined, size: 16.0),
              label: Text(_showPreview ? 'Hide CSV Data Preview' : 'Show CSV Data Preview'),
              onPressed: () => setState(() => _showPreview = !_showPreview),
            ),

            // CSV Preview Box
            if (_showPreview)
              Flexible(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 4.0),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowestLight,
                    borderRadius: AppSpacing.roundedSm,
                    border: Border.all(color: AppColors.outlineVariantLight),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: SelectableText(
                        widget.csvContent,
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 10.5,
                          height: 1.4,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
