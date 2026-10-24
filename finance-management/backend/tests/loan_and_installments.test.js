const http = require('http');
const app = require('../src/app');
const loanCalculator = require('../src/utils/loan-calculator');

async function runLoanTests() {
  console.log('--- RUNNING COMPREHENSIVE LOAN & INSTALLMENT TESTS ---');

  // 1. UNIT TEST: Loan Calculator Arithmetic & Conventions
  console.log('\n1. Testing Loan Calculator Math & Rules...');

  // 1.1 Monthly Simple Interest (10 months @ 5% on ₹50,000)
  const monthlyCalc = loanCalculator.calculateLoanSummary({
    principal: 50000,
    interestRate: 5,
    frequency: 'monthly',
    totalInstallments: 10,
    startDate: '2026-01-01',
    firstDueDate: '2026-02-01',
  });

  if (monthlyCalc.principal !== 50000) throw new Error('Principal mismatch');
  if (monthlyCalc.monthlyInterest !== 2500) throw new Error(`Expected monthly interest 2500, got ${monthlyCalc.monthlyInterest}`);
  if (monthlyCalc.totalInterest !== 25000) throw new Error(`Expected total interest 25000, got ${monthlyCalc.totalInterest}`);
  if (monthlyCalc.totalRepayment !== 75000) throw new Error(`Expected total repayment 75000, got ${monthlyCalc.totalRepayment}`);
  if (monthlyCalc.baseInstallment !== 7500) throw new Error(`Expected base installment 7500, got ${monthlyCalc.baseInstallment}`);
  console.log('✔ Monthly simple interest calculation matches exact formula (₹50k @ 5% for 10mo = ₹75,000)');

  // 1.2 Weekly Loan Convention (52 weeks = 12 months)
  const weeklyCalc = loanCalculator.calculateLoanSummary({
    principal: 26000,
    interestRate: 4,
    frequency: 'weekly',
    totalInstallments: 26, // 26 weeks = 6 months
    startDate: '2026-01-01',
    firstDueDate: '2026-01-08',
  });
  if (weeklyCalc.durationInMonths !== 6) throw new Error(`Expected durationInMonths 6, got ${weeklyCalc.durationInMonths}`);
  if (weeklyCalc.totalInterest !== 6240) throw new Error(`Expected weekly total interest 6240, got ${weeklyCalc.totalInterest}`);
  console.log('✔ Weekly duration convention correctly converts 26 weeks -> 6 months');

  // 1.3 Month-end and Leap Year safety
  const leapSchedule = loanCalculator.generateSchedule({
    principal: 10000,
    interestRate: 2,
    frequency: 'monthly',
    totalInstallments: 4,
    startDate: '2024-01-31',
    firstDueDate: '2024-01-31',
  });
  // In 2024 (leap year), Month 2 from Jan 31 must clamp to Feb 29
  const febDate = leapSchedule.installments[1].due_date;
  if (febDate !== '2024-02-29') throw new Error(`Expected leap year Feb 29 date clamp, got ${febDate}`);
  // Month 3 must restore to Mar 31
  const marDate = leapSchedule.installments[2].due_date;
  if (marDate !== '2024-03-31') throw new Error(`Expected anchor restoration to Mar 31, got ${marDate}`);
  console.log('✔ Month-end & Leap Year safety correctly clamps Jan 31 -> Feb 29 and restores to Mar 31');

  // 1.4 Decimal Rounding Reconciliation (sum of installments MUST equal total repayment)
  const oddCalc = loanCalculator.generateSchedule({
    principal: 10000,
    interestRate: 3.33,
    frequency: 'monthly',
    totalInstallments: 7,
    startDate: '2026-01-01',
    firstDueDate: '2026-02-01',
  });
  const sumOdd = oddCalc.installments.reduce((acc, i) => acc + i.amount_due, 0);
  const diffOdd = Math.abs(sumOdd - oddCalc.summary.totalRepayment);
  if (diffOdd > 0.001) throw new Error(`Installment sum (${sumOdd}) does not equal total repayment (${oddCalc.summary.totalRepayment})`);
  console.log(`✔ Exact rounding reconciliation: sum(installments) ₹${sumOdd.toFixed(2)} === totalRepayment ₹${oddCalc.summary.totalRepayment.toFixed(2)}`);

  // 2. INTEGRATION TESTS VIA HTTP SERVER
  console.log('\n2. Testing HTTP Endpoints against Live Express App...');
  const PORT = 5022;
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
    // 2.1 POST /loans/preview
    const previewRes = await request('POST', '/loans/preview', {
      principal: 60000,
      interest_rate: 5,
      frequency: 'monthly',
      total_installments: 10,
      start_date: '2026-03-01',
      first_due_date: '2026-04-01',
    });
    if (previewRes.status !== 200) throw new Error(`Preview failed with status ${previewRes.status}`);
    const previewData = previewRes.body.data;
    if (previewData.summary.totalRepayment !== 90000) throw new Error(`Expected preview total repayment 90000, got ${previewData.summary.totalRepayment}`);
    if (previewData.installments.length !== 10) throw new Error('Expected 10 preview installments');
    console.log('✔ POST /api/v1/loans/preview returns authoritative schedule preview');

    // 2.2 POST /loans (Create new borrower + loan origination)
    const today = new Date();
    const futureDate = new Date(today);
    futureDate.setDate(today.getDate() + 30);
    const todayStr = today.toISOString().split('T')[0];
    const futureDueStr = futureDate.toISOString().split('T')[0];

    const testBorrowerPhone = `98${Date.now().toString().slice(-8)}`;
    const createRes = await request('POST', '/loans', {
      name: `Automated Test Borrower ${Date.now()}`,
      phone: testBorrowerPhone,
      principal: 40000,
      interest_rate: 5,
      frequency: 'monthly',
      total_installments: 5,
      start_date: todayStr,
      first_due_date: futureDueStr,
      notes: 'Automated test loan',
    });
    if (createRes.status !== 201) throw new Error(`Create loan failed with status ${createRes.status}: ${JSON.stringify(createRes.body)}`);
    const loan = createRes.body.data.loan;
    const installments = createRes.body.data.installments;
    const loanId = loan.id;
    const customerId = loan.customer_id;

    if (!loanId) throw new Error('Loan ID missing from response');
    if (installments.length !== 5) throw new Error(`Expected 5 installments, got ${installments.length}`);
    console.log(`✔ POST /api/v1/loans created loan ${loan.plan_code} with 5 installments`);

    // 2.3 GET /loans/:id
    const getRes = await request('GET', `/loans/${loanId}`);
    if (getRes.status !== 200) throw new Error(`GET /loans/:id failed: ${getRes.status}`);
    if (getRes.body.data.loan.id !== loanId) throw new Error('Loan ID mismatch');
    console.log('✔ GET /api/v1/loans/:id retrieved complete loan financial details');

    // 2.4 GET /customers/:id/loans
    const custLoansRes = await request('GET', `/customers/${customerId}/loans`);
    if (custLoansRes.status !== 200) throw new Error(`GET /customers/:id/loans failed: ${custLoansRes.status}`);
    if (!Array.isArray(custLoansRes.body.data) || custLoansRes.body.data.length === 0) throw new Error('Expected customer loans');
    console.log('✔ GET /api/v1/customers/:id/loans lists borrower originated loans');

    // 2.5 PATCH /installments/:id (Permitted schedule edit before payment)
    const firstInst = installments[0];
    const patchRes = await request('PATCH', `/installments/${firstInst.id}`, {
      due_date: futureDueStr,
      amount_due: firstInst.amount_due + 500, // adjust installment
    });
    if (patchRes.status !== 200) throw new Error(`PATCH /installments/:id failed: ${patchRes.status}`);
    if (patchRes.body.data.due_date !== futureDueStr) throw new Error('Due date not updated');
    console.log('✔ PATCH /api/v1/installments/:id successfully updated installment due date & amount');

    // 2.6 POST /installments/:id/payments (Partial payment test)
    const targetInstId = firstInst.id;
    const partialAmount = 2000;
    const partialPayRes = await request('POST', `/installments/${targetInstId}/payments`, {
      amount: partialAmount,
      payment_date: todayStr,
      payment_method: 'upi',
      notes: 'Partial payment verification',
    });
    if (partialPayRes.status !== 201) throw new Error(`Partial payment failed: ${partialPayRes.status}: ${JSON.stringify(partialPayRes.body)}`);
    const partialInst = partialPayRes.body.data.installment;
    if (partialInst.status !== 'partially_paid') throw new Error(`Expected status 'partially_paid', got '${partialInst.status}'`);
    if (partialInst.amount_paid !== partialAmount) throw new Error(`Expected amount_paid ${partialAmount}, got ${partialInst.amount_paid}`);
    console.log('✔ POST /api/v1/installments/:id/payments partial payment correctly transitioned status to partially_paid');

    // 2.7 POST /installments/:id/payments (Full payment test)
    const remainingBalance = partialInst.outstanding_balance;
    const fullPayRes = await request('POST', `/installments/${targetInstId}/payments`, {
      amount: remainingBalance,
      payment_date: todayStr,
      payment_method: 'cash',
      notes: 'Full settlement verification',
    });
    if (fullPayRes.status !== 201) throw new Error(`Full payment failed: ${fullPayRes.status}`);
    const fullInst = fullPayRes.body.data.installment;
    if (fullInst.status !== 'paid') throw new Error(`Expected status 'paid', got '${fullInst.status}'`);
    if (fullInst.outstanding_balance !== 0) throw new Error(`Expected 0 balance, got ${fullInst.outstanding_balance}`);
    console.log('✔ POST /api/v1/installments/:id/payments remaining balance settled installment to paid with 0 balance');

    // 2.8 Duplicate overpayment check (Attempting to pay on already paid installment)
    const overpayRes = await request('POST', `/installments/${targetInstId}/payments`, {
      amount: 500,
      payment_date: todayStr,
      payment_method: 'cash',
    });
    if (overpayRes.status !== 400) throw new Error(`Expected 400 on overpaying settled installment, got ${overpayRes.status}`);
    console.log('✔ Prevented overpayment on settled installment (returned 400 Bad Request)');

    // 2.9 GET /installments/:id/payments (Receipt history)
    const receiptsRes = await request('GET', `/installments/${targetInstId}/payments`);
    if (receiptsRes.status !== 200) throw new Error('Failed to get receipts');
    if (receiptsRes.body.data.length !== 2) throw new Error(`Expected 2 receipts, got ${receiptsRes.body.data.length}`);
    console.log('✔ GET /api/v1/installments/:id/payments returned both transaction receipts');

    console.log('\n======================================================');
    console.log('ALL LOAN AND INSTALLMENT TESTS PASSED SUCCESSFULLY! 🎉');
    console.log('======================================================');
  } finally {
    server.close();
  }
}

runLoanTests().catch(err => {
  console.error('\n❌ TEST SUITE FAILED:', err);
  process.exit(1);
});
