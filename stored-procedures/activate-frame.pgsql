create or replace function active_frame(in v_segmentation_id bigint, in v_frame integer)
returns void as
$$
begin
    update segmentation set current_frame = v_frame
    where id = v_segmentation_id;
end;
$$
language plpgsql;