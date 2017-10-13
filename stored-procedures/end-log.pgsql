create or replace function end_log(
    in v_id bigint,
    in v_type text,
    in v_f_key bigint,
    in v_message text
) returns void as
$$
begin
    update log set
    (end_time, type, f_key, message) = (current_timestamp, v_type, v_f_key, v_message::jsonb);
end;
$$
language plpgsql;
