create or replace function complete_image(
    in v_id bigint,
    in v_width integer,
    in v_height integer,
    in v_depth integer
) returns void as
$$
begin
    update image_frame
    set (status, width, height, depth) = 
    ('complete', v_width, v_height, v_depth)
    where id = v_id;
end;
$$
language plpgsql;