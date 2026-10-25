const http = require('http');
const https = require('https');
const app = require('../src/app');
const loanCalculator = require('../src/utils/loan-calculator');

async function runProductionReadinessTests() {
  console.log('========================================================');
  console.log('STARTING PRODUCTION READINESS TEST SUITE');
  console.log('========================================================\n');

  let passedCount = 0;
  let failedCount = 0;

  function assert(condition, message) {
    if (!condition) {
      failedCount++;
      console.error(`  ✖ FAIL: ${message}`);
      throw new Error(`Assertion failed: ${message}`);
    }
    passedCount++;
    console.log(`  ✔ PASS: ${message}`);
  }

  // 1. LOAN CALCULATOR & MONETARY PRECISION TESTS
  console.log('--- 1. Testing Financial Calculation Accuracy & Schedule Invariants ---');
  {
    // Test: 50,000 principal at 5% monthly for 10 months (matches screenshot)
    const summary = loanCalculator.calculateLoanSummary({
      principal: 50000,
      interestRate: 5,
      frequency: 'monthly',
      totalInstallments: 10,
      startDate: '2026-10-25',
      firstDueDate: '2026-11-25',
    });

    assert(summary.principal === 50000, 'Principal preserved at 50,000');
    assert(summary.monthlyInterest === 2500, 'Monthly interest is ₹2,500');
    assert(summary.totalInterest === 25000, 'Total interest is ₹25,000');
    assert(summary.totalRepayment === 75000, 'Total repayment is ₹75,000');
    assert(summary.baseInstallment === 7500, 'Monthly installment is ₹7,500');

    // Test: Weekly duration conversion (52 weeks = 12 months)
    const weeklySummary = loanCalculator.calculateLoanSummary({
      principal: 10000,
      interestRate: 5,
      frequency: 'weekly',
      totalInstallments: 26, // 26 weeks = 6 months
      startDate: '2026-10-25',
    });
    assert(weeklySummary.durationInMonths === 6, '26 weeks accurately equates to 6 months');
    assert(weeklySummary.totalInterest === 3000, 'Weekly simple interest accurately computed');

    // Test: Schedule generation exact paise reconciliation
    const schedule = loanCalculator.generateSchedule({
      principal: 10000,
      interestRate: 3.5,
      frequency: 'monthly',
      totalInstallments: 3,
      startDate: '2026-01-15',
    });
    const sumInstallments = schedule.installments.reduce((sum, inst) => sum + inst.amount_due, 0);
    const roundedSum = Math.round(sumInstallments * 100) / 100;
    assert(
      roundedSum === schedule.summary.totalRepayment,
      `Schedule is fully reconciled without lost paise: sum=${roundedSum}, total=${schedule.summary.totalRepayment}`
    );
  }

  // Start local server for HTTP endpoint tests
  const TEST_PORT = 5022;
  const server = app.listen(TEST_PORT);

  function localRequest(method, path, data = null) {
    return new Promise((resolve, reject) => {
      const payload = data ? JSON.stringify(data) : null;
      const req = http.request(
        {
          hostname: '127.0.0.1',
          port: TEST_PORT,
          path: '/api/v1' + path,
          method,
          headers: {
            'Content-Type': 'application/json',
            ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
          },
        },
        (res) => {
          let body = '';
          res.on('data', (c) => (body += c));
          res.on('end', () => {
            try {
              resolve({ status: res.statusCode, body: JSON.parse(body) });
            } catch (_) {
              resolve({ status: res.statusCode, raw: body });
            }
          });
        }
      );
      req.on('error', reject);
      if (payload) req.write(payload);
      req.end();
    });
  }

  console.log('\n--- 2. Testing Input Validation & Error Responses ---');
  {
    // Test: Missing customer name
    const res1 = await localRequest('POST', '/customers', { phone: '9876543210' });
    assert(res1.status === 400, 'Missing customer name rejected with 400 Bad Request');
    assert(res1.body.success === false, 'Error response has success: false');

    // Test: Invalid phone number length
    const res2 = await localRequest('POST', '/customers', {
      name: 'Test',
      phone: '1234567890123456789012345',
    });
    assert(res2.status === 400, 'Excessively long phone rejected with 400');

    // Test: Negative principal loan
    const res3 = await localRequest('POST', '/loans/preview', {
      principal: -5000,
      interest_rate: 5,
      total_installments: 10,
    });
    assert(res3.status === 400, 'Negative principal rejected with 400');

    // Test: Invalid customer ID format
    const res4 = await localRequest('GET', '/customers/not-a-valid-uuid');
    assert(res4.status === 400, 'Malformed UUID rejected with 400');
  }

  console.log('\n--- 3. Testing Idempotency & Deduplication ---');
  {
    const uniquePhone = '99' + Date.now().toString().slice(-8);
    const planCode = `LN-IDEMP-${Date.now()}`;

    // First loan origination
    const payload = {
      customer_name: 'Idempotency Test User',
      phone: uniquePhone,
      principal: 20000,
      interest_rate: 4,
      frequency: 'monthly',
      total_installments: 5,
      start_date: '2026-10-25',
      first_due_date: '2026-11-25',
      plan_code: planCode,
    };

    const firstRes = await localRequest('POST', '/loans', payload);
    assert(firstRes.status === 201, `First loan originated with HTTP 201 (Plan Code: ${planCode})`);
    const originalLoanId = firstRes.body.data.loan.id;

    // Second loan origination with exact same planCode (simulating network retry or double-click)
    const secondRes = await localRequest('POST', '/loans', payload);
    assert(secondRes.status === 201, 'Idempotent replay handled successfully with HTTP 201');
    assert(secondRes.body.data.loan.id === originalLoanId, 'Returned existing loan ID without creating duplicate');
    assert(secondRes.body.data.is_idempotent_replay === true, 'Flagged as idempotent replay correctly');
  }

  console.log('\n--- 4. Testing Live Production Render Backend Connectivity ---');
  {
    function testHttps(url) {
      return new Promise((resolve) => {
        const req = https.get(url, { timeout: 15000 }, (res) => {
          let b = '';
          res.on('data', (c) => (b += c));
          res.on('end', () => {
            try {
              resolve({ ok: res.statusCode === 200, status: res.statusCode, body: JSON.parse(b) });
            } catch (_) {
              resolve({ ok: res.statusCode === 200, status: res.statusCode, raw: b });
            }
          });
        });
        req.on('error', (err) => resolve({ ok: false, error: err.message }));
        req.on('timeout', () => {
          req.destroy();
          resolve({ ok: false, error: 'Request timed out' });
        });
      });
    }

    const prodHealth = await testHttps('https://finance-app-odjk.onrender.com/api/v1/health');
    assert(prodHealth.ok === true, `Deployed Render backend health verified (HTTP ${prodHealth.status})`);

    const prodDbHealth = await testHttps('https://finance-app-odjk.onrender.com/api/v1/health/db');
    assert(prodDbHealth.ok === true, `Deployed Render backend Supabase PostgreSQL verified (HTTP ${prodDbHealth.status})`);
  }

  server.close();
  console.log('\n========================================================');
  console.log(`PRODUCTION READINESS TESTS COMPLETE: ${passedCount} PASSED, ${failedCount} FAILED`);
  console.log('========================================================');
}

runProductionReadinessTests()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Fatal test error:', err);
    process.exit(1);
  });
