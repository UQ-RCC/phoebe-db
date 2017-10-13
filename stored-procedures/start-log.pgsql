create or replace function start_log(out v_id bigint) as
$$
begin
    insert into log (start_time) values (current_timestamp) returning id into v_id;
end;
$$
language plpgsql;