drop function next_segmentation();

create or replace function next_segmentation(
    out v_segmentation_frame_id bigint,
    out v_source_filename text,
    out v_destination_filename text,
    out v_seg_value double precision,
    out v_width integer,
    out v_height integer,
    out v_depth integer) as
$$    
begin
    update segmentation_frame
    set status = 'processing'
    where(id) = (
        select id from segmentation_frame
        where status = 'queued'
        order by id
        limit 1 for update
    )
    returning id into v_segmentation_frame_id;

    select s.seg_value, if.width, if.height, if.depth, if.filename, sf.filename
    into v_seg_value, v_width, v_height, v_depth, v_source_filename, v_destination_filename
    from segmentation_frame as sf, segmentation as s, image_frame as if
    where sf.id = v_segmentation_frame_id
    and sf.segmentation_id = s.id
    and sf.image_frame_id = if.id;
end;
$$
language plpgsql;