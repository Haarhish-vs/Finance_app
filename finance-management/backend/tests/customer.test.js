const http = require('http');
const app = require('../src/app');

async function runTests() {
  const PORT = 5011;
  const server = app.listen(PORT);

  function request(method, path, data = null) {
    return new Promise((resolve, reject) => {
      const payload = data ? JSON.stringify(data) : null;
      const r = http.request({
        hostname: 'localhost',
        port: PORT,
        path: '/api/v1' + path,
        method,
        headers: {
          'Content-Type': 'application/json',
          ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {})
        }
      }, res => {
        let b = '';
        res.on('data', c => b += c);
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode, body: JSON.parse(b) });
          } catch(e) {
            resolve({ status: res.statusCode, raw: b });
          }
        });
      });
      r.on('error', reject);
      if (payload) r.write(payload);
      r.end();
    });
  }

  try {
    console.log('Testing Customer API endpoints...');

    // 1. Validation error on missing name
    const vFail = await request('POST', '/customers', { initial_amount_collected: 100 });
    if (vFail.status !== 400) throw new Error('Expected 400 on missing name');
    console.log('✔ POST /customers validation check passed (400)');

    // 2. Validation error on negative amount
    const aFail = await request('POST', '/customers', { name: 'Fail User', initial_amount_collected: -20 });
    if (aFail.status !== 400) throw new Error('Expected 400 on negative initial amount');
    console.log('✔ POST /customers negative initial amount check passed (400)');

    // 3. Create customer
    const createData = {
      name: 'Automated Test Customer ' + Date.now(),
      phone: '+1555' + Date.now().toString().slice(-7),
      email: 'auto' + Date.now() + '@example.com',
      address: '456 Automation Lane',
      id_type: 'Driver License',
      id_number: 'DL-' + Date.now(),
      initial_amount_collected: 500.00,
      status: 'active',
      notes: 'Initial test deposit notes'
    };
    const created = await request('POST', '/customers', createData);
    if (created.status !== 201 || !created.body.data.id) {
      throw new Error('Failed to create customer: ' + JSON.stringify(created.body));
    }
    const customerId = created.body.data.id;
    console.log('✔ POST /customers created successfully (201, ID: ' + customerId + ')');

    // 4. List customers
    const list = await request('GET', '/customers?page=1&limit=5');
    if (list.status !== 200 || !Array.isArray(list.body.data.customers)) {
      throw new Error('Failed to list customers');
    }
    console.log('✔ GET /customers listed customers successfully (200, count: ' + list.body.data.customers.length + ')');

    // 5. Get customer by ID
    const single = await request('GET', '/customers/' + customerId);
    if (single.status !== 200 || single.body.data.id !== customerId) {
      throw new Error('Failed to get customer by ID');
    }
    if (single.body.data.initial_amount_collected !== 500) {
      throw new Error('Initial amount collected mismatch: ' + single.body.data.initial_amount_collected);
    }
    console.log('✔ GET /customers/:id retrieved customer and initial_amount_collected (200)');

    // 6. Update customer
    const updated = await request('PATCH', '/customers/' + customerId, {
      name: 'Renamed Customer',
      initial_amount_collected: 750.50,
      notes: 'Updated notes'
    });
    if (updated.status !== 200 || updated.body.data.full_name !== 'Renamed Customer' || updated.body.data.initial_amount_collected !== 750.50) {
      throw new Error('Failed to update customer: ' + JSON.stringify(updated.body));
    }
    console.log('✔ PATCH /customers/:id updated details successfully (200)');

    // 7. Update status to inactive
    const inactive = await request('PATCH', '/customers/' + customerId + '/status', { status: 'inactive' });
    if (inactive.status !== 200 || inactive.body.data.status !== 'inactive') {
      throw new Error('Failed to deactivate customer');
    }
    console.log('✔ PATCH /customers/:id/status set status to inactive (200)');

    // 8. Update status back to active
    const active = await request('PATCH', '/customers/' + customerId + '/status', { status: 'active' });
    if (active.status !== 200 || active.body.data.status !== 'active') {
      throw new Error('Failed to reactivate customer');
    }
    console.log('✔ PATCH /customers/:id/status set status to active (200)');

    // 9. 404 on nonexistent customer
    const notFound = await request('GET', '/customers/11111111-1111-1111-1111-111111111111');
    if (notFound.status !== 404) throw new Error('Expected 404 on nonexistent customer');
    console.log('✔ GET /customers/:id returned 404 for nonexistent UUID');

    // 10. Delete customer
    const delRes = await request('DELETE', '/customers/' + customerId);
    if (delRes.status !== 200 || delRes.body.success !== true) {
      throw new Error('Failed to delete customer');
    }
    console.log('✔ DELETE /customers/:id deleted customer from database (200)');

    // 11. Verify customer is gone
    const checkDeleted = await request('GET', '/customers/' + customerId);
    if (checkDeleted.status !== 404) throw new Error('Customer should be 404 after deletion');
    console.log('✔ GET /customers/:id confirmed customer no longer exists in database (404)');

    console.log('\nAll customer backend automated tests passed!');
  } catch (err) {
    console.error('Test execution failed:', err);
    process.exitCode = 1;
  } finally {
    server.close();
  }
}

runTests();
