-- Fix: INSERT ... RETURNING could not see the new row through the helper function.
drop policy merchants_read on public.merchants;
create policy merchants_read on public.merchants for select to authenticated
  using (status = 'approved'
         or owner_id = (select auth.uid())
         or private.is_merchant_member(id)
         or private.is_admin());
