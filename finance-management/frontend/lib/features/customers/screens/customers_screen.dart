import 'package:flutter/material.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_text_field.dart';
import '../models/customer_model.dart';
import '../repositories/customer_repository.dart';
import 'customer_details_screen.dart';
import 'customer_form_dialog.dart';

/// Customers Screen connected to real Express/Supabase backend with search and pagination
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final CustomerRepository _repository = CustomerRepository();
  final TextEditingController _searchController = TextEditingController();

  List<CustomerModel> _customers = [];
  CustomerPagination _pagination = const CustomerPagination();
  bool _isLoading = true;
  String? _errorMessage;

  String _selectedStatus = 'all';
  int _currentPage = 1;
  final int _limit = 10;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomers({bool resetPage = false}) async {
    if (resetPage) {
      _currentPage = 1;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _repository.getCustomers(
        search: _searchController.text.trim(),
        status: _selectedStatus,
        page: _currentPage,
        limit: _limit,
      );

      if (mounted) {
        setState(() {
          _customers = result.customers;
          _pagination = result.pagination;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load customers: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openAddCustomerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => CustomerFormDialog(
        onSaved: () => _fetchCustomers(resetPage: true),
      ),
    );
  }

  void _navigateToCustomerDetails(CustomerModel customer) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => CustomerDetailsScreen(
          customerId: customer.id,
          initialCustomer: customer,
        ),
      ),
    );
    // Refresh list on return to capture any status or name changes
    _fetchCustomers();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < AppSpacing.tabletBreakpoint;

        return Padding(
          padding: isMobile ? AppSpacing.pagePaddingMobile : AppSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Action Bar (Responsive row)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customers',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Manage verified borrower profiles and contact records.',
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    text: 'Add Customer',
                    icon: Icons.person_add_rounded,
                    onPressed: _openAddCustomerDialog,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Search Input Field
              AppTextField(
                controller: _searchController,
                hint: 'Search customers by name, phone or ID...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18.0),
                        onPressed: () {
                          _searchController.clear();
                          _fetchCustomers(resetPage: true);
                        },
                      )
                    : null,
                onChanged: (_) {
                  // Instant search debounce or submit
                  _fetchCustomers(resetPage: true);
                },
              ),
              const SizedBox(height: AppSpacing.sm),

              // Horizontally Scrollable Filter Chips (Prevents horizontal RenderFlex overflow)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('all', 'All Customers'),
                    const SizedBox(width: AppSpacing.xs),
                    _buildFilterChip('active', 'Active'),
                    const SizedBox(width: AppSpacing.xs),
                    _buildFilterChip('inactive', 'Inactive'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Body Content: Loading, Error, Empty, or Customer List
              Expanded(
                child: _buildListContent(),
              ),

              // Pagination Footer
              if (!_isLoading && _customers.isNotEmpty && _pagination.totalPages > 1) ...[
                const SizedBox(height: AppSpacing.sm),
                _buildPaginationFooter(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedStatus = value);
        _fetchCustomers(resetPage: true);
      },
    );
  }

  Widget _buildListContent() {
    if (_isLoading) {
      return const AppLoadingIndicator(message: 'Loading customers...');
    }

    if (_errorMessage != null) {
      return AppEmptyState(
        title: 'No Customers Found',
        subtitle: 'Could not retrieve customer records. Pull down to refresh.',
        icon: Icons.people_outline_rounded,
        actionText: 'Retry',
        onAction: () => _fetchCustomers(resetPage: true),
      );
    }

    if (_customers.isEmpty) {
      final isSearching = _searchController.text.trim().isNotEmpty || _selectedStatus != 'all';
      return AppEmptyState(
        title: isSearching ? 'No Matching Customers' : 'No Customers Yet',
        subtitle: isSearching
            ? 'No customer records match your search criteria.'
            : 'No customer records found in database. Tap below to register your first customer.',
        icon: isSearching ? Icons.person_search_rounded : Icons.people_outline_rounded,
        actionText: isSearching ? 'Clear Filter' : 'Add Customer',
        onAction: isSearching
            ? () {
                _searchController.clear();
                setState(() => _selectedStatus = 'all');
                _fetchCustomers(resetPage: true);
              }
            : _openAddCustomerDialog,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchCustomers(resetPage: false),
      child: ListView.separated(
        itemCount: _customers.length,
        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final customer = _customers[index];
          final isActive = customer.isActive;

          return Card(
            child: InkWell(
              borderRadius: AppSpacing.roundedMd,
              onTap: () => _navigateToCustomerDetails(customer),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22.0,
                      backgroundColor: AppColors.primaryContainer,
                      child: Text(
                        customer.fullName.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  customer.fullName,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                                decoration: BoxDecoration(
                                  color: isActive ? AppColors.successContainer : AppColors.secondaryContainer,
                                  borderRadius: AppSpacing.roundedXs,
                                ),
                                child: Text(
                                  customer.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10.0,
                                    fontWeight: FontWeight.bold,
                                    color: isActive ? AppColors.onSuccessContainer : AppColors.secondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3.0),
                          Wrap(
                            spacing: AppSpacing.md,
                            runSpacing: 2.0,
                            children: [
                              if (customer.phone != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.phone, size: 13.0, color: AppColors.secondary),
                                    const SizedBox(width: 4.0),
                                    Text(customer.phone!, style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                ),
                              if (customer.idNumber != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.badge, size: 13.0, color: AppColors.secondary),
                                    const SizedBox(width: 4.0),
                                    Text(
                                      '${customer.idType ?? 'ID'}: ${customer.idNumber}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(customer.initialAmountCollected),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSuccessContainer,
                              ),
                        ),
                        const SizedBox(height: 2.0),
                        const Text(
                          'Initial Deposit',
                          style: TextStyle(fontSize: 10.0, color: AppColors.textMutedLight),
                        ),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textMutedLight, size: 20.0),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaginationFooter() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Page ${_pagination.page} of ${_pagination.totalPages} (${_pagination.totalRecords} total)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: 'Previous Page',
                  onPressed: _pagination.hasPrevPage
                      ? () {
                          setState(() => _currentPage--);
                          _fetchCustomers();
                        }
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: 'Next Page',
                  onPressed: _pagination.hasNextPage
                      ? () {
                          setState(() => _currentPage++);
                          _fetchCustomers();
                        }
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
