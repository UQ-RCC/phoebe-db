create or replace function deactivate_frame(in v_segmentation_id bigint)
returns void as
$$
begin
    update segmentation set current_frame = null
    where id = v_segmentation_id;
end;
$$
language plpgsql;
