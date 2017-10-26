create or replace function next_segmentation(
    out v_filename text,
    out v_seg_value double precision,
    out v_width integer,
    out v_height integer,
    out v_depth integer) as
$$
declare
    v_segmentation_frame_id bigint;
begin
    update segmentation_frame
    set status = 'processing'
    where(id) = (
        select id from segmentation_frame
        where status = 'queued'
        order by id
        limit 1 for update
    )
    returning id, filename into v_segmentation_frame_id, v_filename;

    select s.seg_value, if.width, if.height, if.depth
    into v_seg_value, v_width, v_height, v_depth
    from segmentation_frame as sf, segmentation as s, image_frame as if
    where sf.id = v_segmentation_frame_id
    and sf.segmentation_id = s.id
    and sf.image_frame_id = if.id;

end;
$$
language plpgsql;