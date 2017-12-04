create or replace function insert_image_stats(
    in v_image_frame_id bigint,
    in v_operation text,
    in v_min double precision,
    in v_max double precision    
) returns void as
$$
begin
    insert into image_frame_stats (image_frame_id, operation, min, max)
    values (v_image_frame_id, v_operation, v_min, v_max);  
    update image_frame set status = 'complete' where id = v_image_frame_id;
end;
$$
language plpgsql;