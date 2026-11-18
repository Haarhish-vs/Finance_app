-- Migration: Add Admins Table and Payment Day Column for Weekly Repayment Scheduling
-- Safe and idempotent: does not recreate or drop existing tables

-- 1. Admins Table for Secure Backend Authentication
CREATE TABLE IF NOT EXISTS public.admins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role VARCHAR(50) DEFAULT 'admin',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Add payment_day column to payment_plans for storing the selected weekday
ALTER TABLE public.payment_plans 
ADD COLUMN IF NOT EXISTS payment_day VARCHAR(20);

-- 3. Create index on installments due_date and plan_id for fast weekly collection aggregation
CREATE INDEX IF NOT EXISTS idx_installments_due_date ON public.installments(due_date);
CREATE INDEX IF NOT EXISTS idx_installments_customer_due ON public.installments(customer_id, due_date);

