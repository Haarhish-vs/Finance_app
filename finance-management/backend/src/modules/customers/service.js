const customerRepository = require('./repository');
const AppError = require('../../utils/api-error');

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Customer Service handling business logic, data normalization, and metadata encapsulation
 */
class CustomerService {
  /**
   * Helper to encode metadata into the database 'notes' column
   */
  _encodeNotes(initialAmountCollected, userNotes = '') {
    const meta = {
      initial_amount_collected: Number(initialAmountCollected) || 0,
      text: userNotes || '',
    };
    return JSON.stringify(meta);
  }

  /**
   * Helper to decode metadata from the database 'notes' column
   */
  _decodeCustomer(record) {
    if (!record) return null;

    let initialAmount = 0;
    let cleanNotes = record.notes || '';

    if (record.notes && typeof record.notes === 'string') {
      try {
        const parsed = JSON.parse(record.notes);
        if (parsed && typeof parsed === 'object') {
          if (parsed.initial_amount_collected !== undefined) {
            initialAmount = Number(parsed.initial_amount_collected) || 0;
          }
          cleanNotes = parsed.text || '';
        }
      } catch (_) {
        // Plain text notes fallback
        cleanNotes = record.notes;
      }
    }

    return {
      id: record.id,
      full_name: record.full_name,
      name: record.full_name, // Alias for convenience
      phone: record.phone || null,
      email: record.email || null,
      address: record.address || null,
      id_type: record.id_type || null,
      id_number: record.id_number || null,
      status: record.status || 'active',
      initial_amount_collected: initialAmount,
      notes: cleanNotes,
      created_at: record.created_at,
      updated_at: record.updated_at,
    };
  }

  /**
   * Validate UUID parameter
   */
  _validateId(id) {
    if (!id || typeof id !== 'string' || !UUID_REGEX.test(id)) {
      throw AppError.badRequest(
        'Invalid customer ID format. Must be a valid UUID.',
        null,
        'INVALID_CUSTOMER_ID'
      );
    }
  }

  /**
   * Create a customer
   */
  async createCustomer(data) {
    const fullName = (data.full_name || data.name || '').trim();
    if (!fullName) {
      throw AppError.badRequest(
        'Customer name is required',
        [{ field: 'name', message: 'Name is required and cannot be empty' }],
        'VALIDATION_ERROR'
      );
    }

    if (fullName.length > 150) {
      throw AppError.badRequest(
        'Customer name must not exceed 150 characters',
        [{ field: 'name', message: 'Maximum 150 characters allowed' }],
        'VALIDATION_ERROR'
      );
    }

    const phone = data.phone ? String(data.phone).trim() : null;
    if (phone && phone.length > 20) {
      throw AppError.badRequest(
        'Phone number must not exceed 20 characters',
        [{ field: 'phone', message: 'Maximum 20 characters allowed' }],
        'VALIDATION_ERROR'
      );
    }

    let initialAmount = 0;
    if (data.initial_amount_collected !== undefined && data.initial_amount_collected !== null) {
      initialAmount = Number(data.initial_amount_collected);
      if (isNaN(initialAmount) || initialAmount < 0) {
        throw AppError.badRequest(
          'Initial amount collected must be a non-negative number',
          [{ field: 'initial_amount_collected', message: 'Must be >= 0' }],
          'VALIDATION_ERROR'
        );
      }
    }

    const status = data.status === 'inactive' ? 'inactive' : 'active';
    const notesPayload = this._encodeNotes(initialAmount, data.notes);

    const recordPayload = {
      full_name: fullName,
      phone,
      email: data.email ? String(data.email).trim() : null,
      address: data.address ? String(data.address).trim() : null,
      id_type: data.id_type ? String(data.id_type).trim() : null,
      id_number: data.id_number ? String(data.id_number).trim() : null,
      status,
      notes: notesPayload,
    };

    try {
      const created = await customerRepository.create(recordPayload);
      return this._decodeCustomer(created);
    } catch (err) {
      // Check for PostgreSQL unique constraint violations
      if (err.code === '23505') {
        throw AppError.conflict(
          'A customer with this information already exists',
          'DUPLICATE_CUSTOMER',
          err.detail
        );
      }
      throw err;
    }
  }

  /**
   * List customers with search, status filtering, and pagination
   */
  async getCustomers({ search, status, page = 1, limit = 10 }) {
    const parsedPage = Math.max(1, parseInt(page, 10) || 1);
    const parsedLimit = Math.min(100, Math.max(1, parseInt(limit, 10) || 10));
    const offset = (parsedPage - 1) * parsedLimit;

    // Validate status filter if specified
    const validStatus = status === 'active' || status === 'inactive' ? status : 'all';

    const { customers, totalCount } = await customerRepository.findAll({
      search: search || '',
      status: validStatus,
      offset,
      limit: parsedLimit,
    });

    const totalPages = Math.ceil(totalCount / parsedLimit) || 1;

    return {
      customers: customers.map((c) => this._decodeCustomer(c)),
      pagination: {
        page: parsedPage,
        limit: parsedLimit,
        totalRecords: totalCount,
        totalPages,
        hasNextPage: parsedPage < totalPages,
        hasPrevPage: parsedPage > 1,
      },
    };
  }

  /**
   * Retrieve a customer by UUID
   */
  async getCustomerById(id) {
    this._validateId(id);

    const customer = await customerRepository.findById(id);
    if (!customer) {
      throw AppError.notFound(
        `Customer not found with ID ${id}`,
        'CUSTOMER_NOT_FOUND'
      );
    }

    return this._decodeCustomer(customer);
  }

  /**
   * Update customer details
   */
  async updateCustomer(id, data) {
    this._validateId(id);

    // Verify existing record
    const existing = await customerRepository.findById(id);
    if (!existing) {
      throw AppError.notFound(
        `Customer not found with ID ${id}`,
        'CUSTOMER_NOT_FOUND'
      );
    }

    const decodedExisting = this._decodeCustomer(existing);
    const updatePayload = {};

    if (data.full_name !== undefined || data.name !== undefined) {
      const name = (data.full_name || data.name || '').trim();
      if (!name) {
        throw AppError.badRequest(
          'Customer name cannot be empty',
          [{ field: 'name', message: 'Name cannot be empty' }],
          'VALIDATION_ERROR'
        );
      }
      if (name.length > 150) {
        throw AppError.badRequest(
          'Customer name must not exceed 150 characters',
          [{ field: 'name', message: 'Maximum 150 characters allowed' }],
          'VALIDATION_ERROR'
        );
      }
      updatePayload.full_name = name;
    }

    if (data.phone !== undefined) {
      const phone = data.phone ? String(data.phone).trim() : null;
      if (phone && phone.length > 20) {
        throw AppError.badRequest(
          'Phone number must not exceed 20 characters',
          [{ field: 'phone', message: 'Maximum 20 characters allowed' }],
          'VALIDATION_ERROR'
        );
      }
      updatePayload.phone = phone;
    }

    if (data.email !== undefined) {
      updatePayload.email = data.email ? String(data.email).trim() : null;
    }

    if (data.address !== undefined) {
      updatePayload.address = data.address ? String(data.address).trim() : null;
    }

    if (data.id_type !== undefined) {
      updatePayload.id_type = data.id_type ? String(data.id_type).trim() : null;
    }

    if (data.id_number !== undefined) {
      updatePayload.id_number = data.id_number ? String(data.id_number).trim() : null;
    }

    if (data.status !== undefined) {
      if (data.status !== 'active' && data.status !== 'inactive') {
        throw AppError.badRequest(
          'Status must be either active or inactive',
          [{ field: 'status', message: 'Must be active or inactive' }],
          'VALIDATION_ERROR'
        );
      }
      updatePayload.status = data.status;
    }

    // Handle initial amount and notes preservation
    let currentInitialAmount = decodedExisting.initial_amount_collected;
    if (data.initial_amount_collected !== undefined) {
      const amount = Number(data.initial_amount_collected);
      if (isNaN(amount) || amount < 0) {
        throw AppError.badRequest(
          'Initial amount collected must be a non-negative number',
          [{ field: 'initial_amount_collected', message: 'Must be >= 0' }],
          'VALIDATION_ERROR'
        );
      }
      currentInitialAmount = amount;
    }

    const currentNotes = data.notes !== undefined ? data.notes : decodedExisting.notes;
    updatePayload.notes = this._encodeNotes(currentInitialAmount, currentNotes);

    const updated = await customerRepository.update(id, updatePayload);
    return this._decodeCustomer(updated);
  }

  /**
   * Update active status for a customer
   */
  async updateCustomerStatus(id, newStatus) {
    this._validateId(id);

    let status = newStatus;
    if (typeof newStatus === 'boolean') {
      status = newStatus ? 'active' : 'inactive';
    }

    if (status !== 'active' && status !== 'inactive') {
      throw AppError.badRequest(
        "Invalid status. Must be 'active' or 'inactive'.",
        [{ field: 'status', message: "Must be 'active' or 'inactive'" }],
        'VALIDATION_ERROR'
      );
    }

    const existing = await customerRepository.findById(id);
    if (!existing) {
      throw AppError.notFound(
        `Customer not found with ID ${id}`,
        'CUSTOMER_NOT_FOUND'
      );
    }

    const updated = await customerRepository.updateStatus(id, status);
    return this._decodeCustomer(updated);
  }
}

module.exports = new CustomerService();
