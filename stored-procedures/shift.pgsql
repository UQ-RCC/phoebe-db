create or replace function shift(
    in v_value bigint,
    in v_pivot bigint,
    in v_max bigint,
    out v_pivot_value bigint
) as
$$
declare
    v_temp_value bigint;
begin
    v_temp_value := v_value - v_pivot;
    if v_temp_value < 0 then
        v_temp_value := abs(v_temp_value) + v_max;
    end if;
    v_pivot_value := v_temp_value;
end;
$$
language plpgsql;