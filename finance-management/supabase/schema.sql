-- Supabase PostgreSQL Schema for Finance Management App
-- Matched from active Supabase database schema (Read-only inspection)
-- Do not run migrations that recreate or rename existing tables

-- 1. Customers Table
CREATE TABLE IF NOT EXISTS public.customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name VARCHAR(150) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(100),
    address TEXT,
    id_type VARCHAR(50),
    id_number VARCHAR(100),
    status VARCHAR(20) DEFAULT 'active',
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Payment Plans Table
CREATE TABLE IF NOT EXISTS public.payment_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_code VARCHAR(50),
    customer_id UUID REFERENCES public.customers(id) ON DELETE CASCADE,
    title VARCHAR(150),
    total_amount NUMERIC NOT NULL,
    down_payment NUMERIC DEFAULT 0,
    principal_amount NUMERIC,
    interest_rate NUMERIC DEFAULT 0,
    total_installments INTEGER,
    frequency VARCHAR(20) DEFAULT 'monthly',
    start_date DATE,
    end_date DATE,
    status VARCHAR(20) DEFAULT 'active',
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Installments Table
CREATE TABLE IF NOT EXISTS public.installments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_id UUID REFERENCES public.payment_plans(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES public.customers(id) ON DELETE CASCADE,
    installment_number INTEGER NOT NULL,
    due_date DATE,
    amount_due NUMERIC NOT NULL,
    amount_paid NUMERIC DEFAULT 0,
    status VARCHAR(20) DEFAULT 'pending',
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 4. Payments Table
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_reference VARCHAR(100),
    customer_id UUID REFERENCES public.customers(id) ON DELETE SET NULL,
    plan_id UUID REFERENCES public.payment_plans(id) ON DELETE SET NULL,
    installment_id UUID REFERENCES public.installments(id) ON DELETE SET NULL,
    amount NUMERIC NOT NULL,
    payment_date TIMESTAMPTZ DEFAULT now(),
    payment_method VARCHAR(30) DEFAULT 'cash',
    notes TEXT,
    receipt_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);
