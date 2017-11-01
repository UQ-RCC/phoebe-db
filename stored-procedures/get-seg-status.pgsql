

create or replace function get_seg_status(in v_segmentation_id bigint)
returns table(msec integer, filename uuid, status text) as
$$
        select f.msec, s.filename, s.status
        from segmentation_frame as s, image_frame as f
        where s.segmentation_id = v_segmentation_id  
        and s.image_frame_id = f.id
        order by 1;
$$
language sql;
