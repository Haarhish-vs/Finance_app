const authService = require('../src/modules/auth/service');
const loanCalculator = require('../src/utils/loan-calculator');
const dashboardService = require('../src/modules/dashboard/service');
const app = require('../src/app');

async function runTests() {
  console.log('========================================================');
  console.log('RUNNING TESTS FOR NEW FEATURES: AUTH, WEEKDAY, DASHBOARD');
  console.log('========================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(condition, message) {
    if (!condition) {
      failed++;
      console.error(`  ✖ FAIL: ${message}`);
      throw new Error(message);
    }
    passed++;
    console.log(`  ✔ PASS: ${message}`);
  }

  // 1. ADMIN AUTHENTICATION TESTS
  console.log('--- 1. Testing Admin Authentication & Seeding ---');
  {
    // Seed initial admin
    const seeded = await authService.seedInitialAdmin();
    assert(Boolean(seeded), 'Initial admin seeded successfully');
    assert(seeded.email === 'ashokfinapp', 'Seeded admin email matches ashokfinapp');
    assert(Boolean(seeded.password_hash), 'Password is securely hashed');
    assert(seeded.password_hash !== 'ashokfinpass', 'Password is not plaintext');

    // Attempt login with wrong password
    let failedLogin = false;
    try {
      await authService.login({ email: 'ashokfinapp', password: 'wrongpassword' });
    } catch (err) {
      failedLogin = true;
      assert(err.statusCode === 401, 'Wrong password returns 401 Unauthorized');
    }
    assert(failedLogin, 'Login failed with wrong password as expected');

    // Attempt login with correct password
    const loginResult = await authService.login({ email: 'ashokfinapp', password: 'ashokfinpass' });
    assert(Boolean(loginResult.token), 'Login returns JWT token');
    assert(loginResult.admin.email === 'ashokfinapp', 'Returned admin profile has email');

    // Verify token
    const decoded = authService.verifyToken(loginResult.token);
    assert(decoded.email === 'ashokfinapp', 'Decoded token email matches');
  }

  // 2. WEEKLY PAYMENT DAY SELECTION TESTS
  console.log('\n--- 2. Testing Weekly Payment Day Selection & Scheduling ---');
  {
    // Test: Wednesday selected for a weekly loan
    const wednesdaySchedule = loanCalculator.generateSchedule({
      principal: 20000,
      interestRate: 5,
      frequency: 'weekly',
      totalInstallments: 8,
      startDate: '2026-11-18', // 2026-11-18 is a Wednesday
      paymentDay: 'Wednesday',
    });

    assert(wednesdaySchedule.summary.frequency === 'weekly', 'Frequency is weekly');
    assert(wednesdaySchedule.summary.paymentDay === 'Wednesday', 'Payment day preserved as Wednesday');
    assert(wednesdaySchedule.installments.length === 8, '8 weekly installments generated');

    // Verify EVERY installment falls on Wednesday (day 3 in UTC)
    for (const inst of wednesdaySchedule.installments) {
      const d = new Date(inst.due_date);
      const day = d.getUTCDay();
      assert(day === 3, `Installment #${inst.installment_number} due date ${inst.due_date} is Wednesday (day 3)`);
    }

    // Test: Sunday selected for a weekly loan starting on a Wednesday
    const sundaySchedule = loanCalculator.generateSchedule({
      principal: 15000,
      interestRate: 4,
      frequency: 'weekly',
      totalInstallments: 6,
      startDate: '2026-11-18', // Wednesday
      paymentDay: 'Sunday',
    });

    assert(sundaySchedule.summary.paymentDay === 'Sunday', 'Payment day preserved as Sunday');
    // First due date must be next Sunday (2026-11-22)
    assert(sundaySchedule.summary.firstDueDate === '2026-11-22', 'First due date is next upcoming Sunday 2026-11-22');

    // Verify EVERY installment falls on Sunday (day 0 in UTC)
    for (const inst of sundaySchedule.installments) {
      const d = new Date(inst.due_date);
      const day = d.getUTCDay();
      assert(day === 0, `Installment #${inst.installment_number} due date ${inst.due_date} is Sunday (day 0)`);
    }

    // Test: Preserve existing monthly flow
    const monthlySchedule = loanCalculator.generateSchedule({
      principal: 50000,
      interestRate: 5,
      frequency: 'monthly',
      totalInstallments: 5,
      startDate: '2026-10-25',
    });
    assert(monthlySchedule.summary.frequency === 'monthly', 'Monthly flow is preserved');
    assert(monthlySchedule.summary.firstDueDate === '2026-11-25', 'Monthly due date adds 1 month');
  }

  // 3. WEEKLY COLLECTION DASHBOARD TESTS
  console.log('\n--- 3. Testing Weekly Collection Dashboard ---');
  {
    // Retrieve weekly collection for week containing 2026-06-23 (where known test data exists)
    const collections = await dashboardService.getWeeklyCollections({
      weekDate: '2026-06-23',
    });

    assert(Boolean(collections.week_start), 'Collections has week_start');
    assert(Boolean(collections.week_end), 'Collections has week_end');
    assert(collections.weekdays.length === 7, 'Overview contains all 7 weekdays Monday through Sunday');

    const tuesday = collections.weekdays.find((w) => w.weekday === 'Tuesday');
    assert(Boolean(tuesday), 'Tuesday exists in breakdown');
    assert(tuesday.customer_count > 0, `Tuesday has ${tuesday.customer_count} actual due installments in that week`);
    assert(tuesday.items.length > 0, 'Tuesday items list populated');
    const firstItem = tuesday.items[0];
    assert(Boolean(firstItem.customer_name), 'Item has customer name');
    assert(firstItem.installment_amount > 0, 'Item has weekly installment amount');
    assert(Boolean(firstItem.status), 'Item has status (paid/pending/overdue)');
    assert(firstItem.outstanding_balance >= 0, 'Item has outstanding balance');

    console.log(`\nSample Weekday Overview for week ${collections.week_start} to ${collections.week_end}:`);
    for (const day of collections.weekdays) {
      console.log(`  - ${day.weekday} — ${day.customer_count} customers (Total due: ₹${day.total_due})`);
    }
  }

  console.log(`\n========================================================`);
  console.log(`ALL TESTS PASSED! (${passed} checks passed, ${failed} failed)`);
  console.log(`========================================================`);
}

runTests().catch((err) => {
  console.error('Fatal test error:', err);
  process.exit(1);
});

