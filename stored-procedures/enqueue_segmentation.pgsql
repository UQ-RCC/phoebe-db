create or replace function enqueue_segmentation_job(
    v_channel_id integer,
    v_seg_value double precision) returns void as
$$
declare
    v_segmentation_id bigint;
begin
    insert into segmentation(channel_id, seg_value)
    values (v_channel_id, v_seg_value)
    returning id into v_segmentation_id;

    insert into segmentation_frame(segmentation_id, image_frame_id, filename, status)    
    select v_segmentation_id, i.id, uuid_generate_v4(), 'queued'
    from image_frame as i
    where i.channel_id = v_channel_id;

end;
$$

language plpgsql;
