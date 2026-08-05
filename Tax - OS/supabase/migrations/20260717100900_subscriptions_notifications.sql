-- Migration: 20260717100900_subscriptions_notifications
-- Description: Tenant-level billing and in-app notifications
-- Author: TaxOS Engineering
-- Date: 2026-07-17
--
-- down:
--   DROP TABLE IF EXISTS public.notifications CASCADE;
--   DROP TABLE IF EXISTS public.subscriptions CASCADE;

-- ---------------------------------------------------------------------------
-- subscriptions — one active plan per accountant (tenant billing)
-- Decision: Subscription at tenant level, not per client. Webhook updates via service_role.
-- ---------------------------------------------------------------------------
CREATE TABLE public.subscriptions (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  accountant_id            uuid NOT NULL UNIQUE REFERENCES public.accountants (id) ON DELETE CASCADE,
  plan_id                  public.subscription_plan NOT NULL DEFAULT 'free',
  status                   public.subscription_status NOT NULL DEFAULT 'active',
  provider                 text,
  provider_subscription_id text,
  current_period_start     timestamptz,
  current_period_end       timestamptz,
  cancelled_at             timestamptz,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT subscriptions_provider_check CHECK (
    provider IS NULL OR provider IN ('apple', 'google', 'stripe')
  )
);

CREATE INDEX idx_subscriptions_accountant ON public.subscriptions (accountant_id);
CREATE INDEX idx_subscriptions_status ON public.subscriptions (status);

CREATE TRIGGER subscriptions_updated_at
  BEFORE UPDATE ON public.subscriptions
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ---------------------------------------------------------------------------
-- notifications — scoped to accountant (tenant-wide alerts)
-- Decision: Notifications are for the accountant user, not end clients in Sprint 1.
-- ---------------------------------------------------------------------------
CREATE TABLE public.notifications (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  accountant_id   uuid NOT NULL REFERENCES public.accountants (id) ON DELETE CASCADE,
  client_id       uuid REFERENCES public.clients (id) ON DELETE SET NULL,
  type            public.notification_type NOT NULL,
  title           text NOT NULL,
  body            text NOT NULL,
  data            jsonb NOT NULL DEFAULT '{}',
  read_at         timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_notifications_accountant_created ON public.notifications (accountant_id, created_at DESC);
CREATE INDEX idx_notifications_unread ON public.notifications (accountant_id, created_at DESC)
  WHERE read_at IS NULL;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Accountants can read their subscription; writes via service_role webhook only
CREATE POLICY subscriptions_select_own ON public.subscriptions
  FOR SELECT TO authenticated
  USING (accountant_id = public.current_accountant_id());

CREATE POLICY notifications_select_own ON public.notifications
  FOR SELECT TO authenticated
  USING (accountant_id = public.current_accountant_id());

CREATE POLICY notifications_update_own ON public.notifications
  FOR UPDATE TO authenticated
  USING (accountant_id = public.current_accountant_id())
  WITH CHECK (accountant_id = public.current_accountant_id());

-- No INSERT/UPDATE/DELETE policies for subscriptions (service_role bypasses RLS)
-- No INSERT policy for notifications (Edge Functions use service_role)
