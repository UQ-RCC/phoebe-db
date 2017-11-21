create or replace function insert_segmentation(
    in v_segmentation_frame_id bigint,
    in v_object_count integer,
    in v_cell_count integer,    
    in v_status text) returns void as
$$
declare
        v_message jsonb;
begin
    update segmentation_frame
    set (object_count, cell_count, status) = 
        (v_object_count, v_cell_count, v_status)
    where id = v_segmentation_frame_id;

    select to_jsonb(m) into v_message from
    (select id as segmentation_frame_id, segmentation_id, status
    from segmentation_frame
    where id = v_segmentation_frame_id) as m;

    perform pg_notify('proc_status', v_message::text);


end;
$$
language plpgsql;
