import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../models/report_model.dart';
import '../repositories/reports_repository.dart';
import '../widgets/csv_export_dialog.dart';

/// Financial Reports & Analytics screen with responsive metrics, range filtering, and CSV export
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportsRepository _reportsRepo = ReportsRepository();

  String _selectedRange = 'This Month';
  bool _isLoading = true;
  bool _isExporting = false;
  ReportData? _reportData;

  final List<String> _ranges = const [
    'This Month',
    'Last Month',
    'This Quarter',
    'Year to Date',
    'All Time',
  ];

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);

    try {
      final data = await _reportsRepo.getReport(range: _selectedRange);
      if (mounted) {
        setState(() {
          _reportData = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exportCsv() async {
    if (_reportData == null) return;

    setState(() => _isExporting = true);

    try {
      final csvContent = _reportsRepo.buildCsvString(_reportData!);
      final safeRange = _selectedRange.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
      final dateStr = DateTime.now().toLocal().toString().split(' ')[0].replaceAll('-', '');
      final filename = 'finance_report_${safeRange}_$dateStr.csv';

      String? savedPath;
      try {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          final file = File('${downloadDir.path}/$filename');
          await file.writeAsString(csvContent);
          savedPath = file.path;
        }
      } catch (_) {}

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => CsvExportDialog(
            rangeLabel: _selectedRange,
            csvContent: csvContent,
            filename: filename,
            savedPath: savedPath,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate CSV: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _showPdfSummary() {
    if (_reportData == null) return;
    final m = _reportData!.metrics;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Audit Summary for $_selectedRange: ${m.totalCustomers} borrowers, ${CurrencyFormatter.format(m.totalCollected)} collected.',
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < AppSpacing.tabletBreakpoint;
        final horizontalPadding = isMobile ? AppSpacing.md : AppSpacing.lg;

        return RefreshIndicator(
          onRefresh: _loadReportData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header & Export Row
                _buildHeader(context, isMobile),
                const SizedBox(height: AppSpacing.md),

                // Range Filter Pills
                _buildRangeSelector(),
                const SizedBox(height: AppSpacing.md),

                if (_isLoading) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Executive KPI Summary Cards
                _buildKpiSection(constraints.maxWidth),
                const SizedBox(height: AppSpacing.lg),

                // Portfolio & Collection Health Section
                _buildPortfolioHealthCard(context),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financial Reports',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 22.0,
                ),
          ),
          const SizedBox(height: 4.0),
          Text(
            'Portfolio performance, recovery metrics, and collection forecasts.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMutedLight,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: _isExporting
                      ? const SizedBox(
                          width: 16.0,
                          height: 16.0,
                          child: CircularProgressIndicator(strokeWidth: 2.0),
                        )
                      : const Icon(Icons.file_download_outlined, size: 18.0),
                  label: Text(_isExporting ? 'Exporting...' : 'Export CSV'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedMd),
                  ),
                  onPressed: _isExporting ? null : _exportCsv,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  text: 'PDF Report',
                  icon: Icons.picture_as_pdf_outlined,
                  onPressed: _showPdfSummary,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Financial Reports',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4.0),
              Text(
                'Portfolio performance, recovery metrics, and collection forecasts.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMutedLight,
                    ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            OutlinedButton.icon(
              icon: _isExporting
                  ? const SizedBox(
                      width: 16.0,
                      height: 16.0,
                      child: CircularProgressIndicator(strokeWidth: 2.0),
                    )
                  : const Icon(Icons.file_download_outlined, size: 18.0),
              label: Text(_isExporting ? 'Exporting...' : 'Export CSV'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedMd),
              ),
              onPressed: _isExporting ? null : _exportCsv,
            ),
            const SizedBox(width: AppSpacing.sm),
            AppButton(
              text: 'PDF Report',
              icon: Icons.picture_as_pdf_outlined,
              onPressed: _showPdfSummary,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRangeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _ranges.map((range) {
          final isSelected = _selectedRange == range;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              onTap: () {
                if (_selectedRange != range) {
                  setState(() => _selectedRange = range);
                  _loadReportData();
                }
              },
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.borderLight,
                    width: 1.2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(50),
                            blurRadius: 4.0,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.calendar_today_rounded,
                      size: 14.0,
                      color: isSelected ? Colors.white : AppColors.textMutedLight,
                    ),
                    const SizedBox(width: 6.0),
                    Text(
                      range,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKpiSection(double maxWidth) {
    final m = _reportData?.metrics ?? const ReportMetrics();

    final double avgDeposit = m.totalCustomers > 0 ? (m.totalCollected / m.totalCustomers) : 0.0;

    final cards = [
      _buildKpiCard(
        title: 'Total Initial Collected',
        amount: CurrencyFormatter.format(m.totalCollected),
        subtitle: 'Collected across ${_reportData?.range ?? _selectedRange}',
        icon: Icons.check_circle_rounded,
        accentColor: AppColors.success,
        bgColor: AppColors.successContainer,
      ),
      _buildKpiCard(
        title: 'Average Initial Deposit',
        amount: CurrencyFormatter.format(avgDeposit),
        subtitle: 'Average per enrolled borrower',
        icon: Icons.currency_rupee_rounded,
        accentColor: AppColors.primary,
        bgColor: AppColors.primaryContainer,
      ),
      _buildKpiCard(
        title: 'Active Borrowers',
        amount: '${m.activeCustomers} Active',
        subtitle: '${m.totalCustomers} total registered',
        icon: Icons.people_alt_rounded,
        accentColor: AppColors.info,
        bgColor: AppColors.surfaceLight,
      ),
      _buildKpiCard(
        title: 'Outstanding Principal',
        amount: CurrencyFormatter.format(m.outstandingPrincipal),
        subtitle: m.outstandingPrincipal > 0 ? 'Remaining to recover' : 'All loans recovered',
        icon: Icons.account_balance_wallet_rounded,
        accentColor: AppColors.secondary,
        bgColor: AppColors.secondaryContainer,
      ),
    ];

    if (maxWidth < 560) {
      // 2x2 Clean Grid on mobile phones
      final double cardWidth = (maxWidth - (AppSpacing.md * 2) - 10.0) / 2;

      return Wrap(
        spacing: 10.0,
        runSpacing: 10.0,
        children: cards.map((c) {
          return SizedBox(
            width: cardWidth,
            child: c,
          );
        }).toList(),
      );
    }

    if (maxWidth < 900) {
      // 2 columns on small tablets
      final double cardWidth = (maxWidth - (AppSpacing.md * 2) - AppSpacing.md) / 2;
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
      );
    }

    // 4 columns on large screens
    return Row(
      children: cards
          .map((c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  child: c,
                ),
              ))
          .toList(),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String amount,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(color: AppColors.borderLight),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMutedLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5.0),
                decoration: BoxDecoration(
                  color: bgColor.withAlpha(160),
                  borderRadius: AppSpacing.roundedSm,
                ),
                child: Icon(icon, color: accentColor, size: 16.0),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryLight,
              ),
            ),
          ),
          const SizedBox(height: 2.0),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.textMutedLight,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioHealthCard(BuildContext context) {
    final m = _reportData?.metrics ?? const ReportMetrics();

    if (m.totalCustomers == 0 && m.totalLoans == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: AppEmptyState(
            title: 'No Portfolio Activity in this Range',
            subtitle: 'Portfolio performance and collection trends will appear automatically as records are created.',
            icon: Icons.analytics_outlined,
          ),
        ),
      );
    }

    final double recoveryRate = m.totalRepaymentExpected > 0
        ? (m.totalCollected / m.totalRepaymentExpected).clamp(0.0, 1.0)
        : (m.totalCustomers > 0 ? (m.activeCustomers / m.totalCustomers) : 0.0);

    final double recoveryPercent = recoveryRate * 100;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Portfolio Health & Recovery',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        'Performance summary for $_selectedRange',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textMutedLight,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: AppColors.successContainer,
                    borderRadius: AppSpacing.roundedSm,
                  ),
                  child: Text(
                    '${recoveryPercent.toStringAsFixed(1)}% Recovery',
                    style: const TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSuccessContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Visual Progress Bar
            ClipRRect(
              borderRadius: AppSpacing.roundedSm,
              child: SizedBox(
                height: 10.0,
                child: LinearProgressIndicator(
                  value: recoveryRate,
                  backgroundColor: AppColors.surfaceContainerLowestLight,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Collected: ${CurrencyFormatter.format(m.totalCollected)}',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.success),
                ),
                Text(
                  'Outstanding: ${CurrencyFormatter.format(m.outstandingPrincipal)}',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.secondary),
                ),
              ],
            ),
            const Divider(height: AppSpacing.lg),

            // Summary Information note
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16.0,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Total disbursed portfolio is ${CurrencyFormatter.format(m.totalPrincipalDisbursed)} with ${m.totalInstallments} scheduled installments. Tap "Export CSV" above to download the itemized statement for $_selectedRange.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondaryLight,
                          fontSize: 11.5,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
