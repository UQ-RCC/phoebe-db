create or replace function complete_image(
    in v_id bigint
) returns void as
$$
begin
    update image_frame set status = 'complete'
    where id = v_id;
end;
$$
language plpgsql;