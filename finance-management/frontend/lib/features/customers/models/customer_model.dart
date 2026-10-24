/// Customer data model matching Supabase database record structure
class CustomerModel {
  final String id;
  final String fullName;
  final String? phone;
  final String? email;
  final String? address;
  final String? idType;
  final String? idNumber;
  final String status;
  final double initialAmountCollected;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CustomerModel({
    required this.id,
    required this.fullName,
    this.phone,
    this.email,
    this.address,
    this.idType,
    this.idNumber,
    this.status = 'active',
    this.initialAmountCollected = 0.0,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status.toLowerCase() == 'active';

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? json['name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      address: json['address']?.toString(),
      idType: json['id_type']?.toString(),
      idNumber: json['id_number']?.toString(),
      status: json['status']?.toString() ?? 'active',
      initialAmountCollected: (json['initial_amount_collected'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (address != null) 'address': address,
      if (idType != null) 'id_type': idType,
      if (idNumber != null) 'id_number': idNumber,
      'status': status,
      'initial_amount_collected': initialAmountCollected,
      if (notes != null) 'notes': notes,
    };
  }

  CustomerModel copyWith({
    String? id,
    String? fullName,
    String? phone,
    String? email,
    String? address,
    String? idType,
    String? idNumber,
    String? status,
    double? initialAmountCollected,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      idType: idType ?? this.idType,
      idNumber: idNumber ?? this.idNumber,
      status: status ?? this.status,
      initialAmountCollected: initialAmountCollected ?? this.initialAmountCollected,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Pagination metadata container
class CustomerPagination {
  final int page;
  final int limit;
  final int totalRecords;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;

  const CustomerPagination({
    this.page = 1,
    this.limit = 10,
    this.totalRecords = 0,
    this.totalPages = 1,
    this.hasNextPage = false,
    this.hasPrevPage = false,
  });

  factory CustomerPagination.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CustomerPagination();
    return CustomerPagination(
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 10,
      totalRecords: json['totalRecords'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 1,
      hasNextPage: json['hasNextPage'] as bool? ?? false,
      hasPrevPage: json['hasPrevPage'] as bool? ?? false,
    );
  }
}

/// Combined Customer List response
class CustomerListResult {
  final List<CustomerModel> customers;
  final CustomerPagination pagination;

  const CustomerListResult({
    required this.customers,
    required this.pagination,
  });
}
