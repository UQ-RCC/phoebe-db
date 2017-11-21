create or replace function log(
    in v_type text,
    in v_message text,
    in v_f_key bigint default null
) returns void as
$$
declare
    v_time timestamp with time zone := current_timestamp;
begin
    insert into log (start_time, end_time, type, f_key, message)
    values (v_time, v_time, v_type, v_f_key, v_message::jsonb);    
end;
$$
language plpgsql;