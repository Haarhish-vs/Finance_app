-- Migration: Add Atomic Loan Origination PostgreSQL RPC Function
-- This function executes customer lookup/creation, loan plan insertion, and installment schedule insertion
-- inside a single atomic PostgreSQL transaction.

CREATE OR REPLACE FUNCTION public.originate_loan(
    p_customer_id UUID DEFAULT NULL,
    p_customer_name VARCHAR DEFAULT NULL,
    p_phone VARCHAR DEFAULT NULL,
    p_email VARCHAR DEFAULT NULL,
    p_address TEXT DEFAULT NULL,
    p_plan_code VARCHAR DEFAULT NULL,
    p_title VARCHAR DEFAULT NULL,
    p_principal_amount NUMERIC DEFAULT NULL,
    p_interest_rate NUMERIC DEFAULT NULL,
    p_total_amount NUMERIC DEFAULT NULL,
    p_down_payment NUMERIC DEFAULT 0,
    p_total_installments INTEGER DEFAULT NULL,
    p_frequency VARCHAR DEFAULT 'monthly',
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_installments JSONB DEFAULT '[]'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_customer_id UUID := p_customer_id;
    v_plan_id UUID;
    v_plan_code VARCHAR := COALESCE(p_plan_code, 'LN-' || FLOOR(EXTRACT(EPOCH FROM now()) * 1000)::text);
    v_installment JSONB;
    v_existing_plan JSONB;
BEGIN
    -- 1. Check for idempotency replay on plan_code
    SELECT to_jsonb(p) INTO v_existing_plan
    FROM public.payment_plans p
    WHERE p.plan_code = v_plan_code
    LIMIT 1;

    IF v_existing_plan IS NOT NULL THEN
        RETURN jsonb_build_object(
            'success', true,
            'plan_id', (v_existing_plan->>'id')::uuid,
            'plan_code', v_plan_code,
            'is_replay', true
        );
    END IF;

    -- 2. Resolve or insert customer
    IF v_customer_id IS NULL THEN
        IF p_phone IS NOT NULL AND trim(p_phone) <> '' THEN
            SELECT id INTO v_customer_id
            FROM public.customers
            WHERE phone = trim(p_phone)
            LIMIT 1;
        END IF;

        IF v_customer_id IS NULL THEN
            INSERT INTO public.customers (
                full_name,
                phone,
                email,
                address,
                status,
                notes
            ) VALUES (
                COALESCE(p_customer_name, 'Unknown Borrower'),
                p_phone,
                p_email,
                p_address,
                'active',
                'Originated via transactional RPC'
            )
            RETURNING id INTO v_customer_id;
        END IF;
    END IF;

    -- 3. Insert into payment_plans
    INSERT INTO public.payment_plans (
        plan_code,
        customer_id,
        title,
        principal_amount,
        interest_rate,
        total_amount,
        down_payment,
        total_installments,
        frequency,
        start_date,
        end_date,
        status,
        notes
    ) VALUES (
        v_plan_code,
        v_customer_id,
        COALESCE(p_title, 'Personal Loan - ' || v_plan_code),
        p_principal_amount,
        p_interest_rate,
        p_total_amount,
        COALESCE(p_down_payment, 0),
        p_total_installments,
        COALESCE(p_frequency, 'monthly'),
        p_start_date,
        p_end_date,
        'active',
        p_notes
    )
    RETURNING id INTO v_plan_id;

    -- 4. Bulk insert installments from JSON array
    IF jsonb_array_length(p_installments) > 0 THEN
        INSERT INTO public.installments (
            plan_id,
            customer_id,
            installment_number,
            due_date,
            amount_due,
            amount_paid,
            status
        )
        SELECT
            v_plan_id,
            v_customer_id,
            (elem->>'installment_number')::integer,
            (elem->>'due_date')::date,
            (elem->>'amount_due')::numeric,
            0,
            'pending'
        FROM jsonb_array_elements(p_installments) AS elem;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'plan_id', v_plan_id,
        'plan_code', v_plan_code,
        'customer_id', v_customer_id
    );
END;
$$;
