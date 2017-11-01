create or replace function insert_segmentation(
    in v_segmentation_frame_id bigint,
    in v_object_count integer,
    in v_cell_count integer,    
    in v_status text) returns void as
$$
declare
        updateCount integer;
begin
    update segmentation_frame
    set (object_count, cell_count, status) = 
        (v_object_count, v_cell_count, v_status)
    where id = v_segmentation_frame_id;
end;
$$
language plpgsql;
