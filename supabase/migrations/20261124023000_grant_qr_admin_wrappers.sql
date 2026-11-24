grant execute on function private.admin_create_qr_batch(uuid,uuid,integer,integer,timestamptz) to authenticated;
grant execute on function private.admin_list_qr_batches(integer) to authenticated;
grant execute on function private.admin_get_qr_batch_print_data(uuid) to authenticated;
grant execute on function private.admin_revoke_qr_batch(uuid) to authenticated;
