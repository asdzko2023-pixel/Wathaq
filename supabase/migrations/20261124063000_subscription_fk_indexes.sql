-- Cover subscription history and actor foreign keys for the new plan model.
create index if not exists merchant_subscriptions_created_by_idx
  on public.merchant_subscriptions(created_by)
  where created_by is not null;
create index if not exists merchant_subscriptions_changed_by_idx
  on public.merchant_subscriptions(changed_by)
  where changed_by is not null;
create index if not exists subscription_history_subscription_idx
  on public.subscription_history(subscription_id)
  where subscription_id is not null;
create index if not exists subscription_history_actor_idx
  on public.subscription_history(actor_user_id)
  where actor_user_id is not null;
create index if not exists subscription_history_from_plan_idx
  on public.subscription_history(from_plan_key)
  where from_plan_key is not null;
create index if not exists subscription_history_to_plan_idx
  on public.subscription_history(to_plan_key)
  where to_plan_key is not null;
