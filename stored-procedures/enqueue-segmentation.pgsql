create or replace function enqueue_segmentation_job(
    in v_channel_id integer,
    in v_seg_value double precision,
    out v_segmentation_id bigint) as
$$
begin

    insert into segmentation(channel_id, seg_value)
    values (v_channel_id, v_seg_value)
    returning id into v_segmentation_id;

    insert into segmentation_frame(segmentation_id, image_frame_id, filename, status, frame_number)
    select v_segmentation_id, i.id, uuid_generate_v4(), 'queued', row_number() over(order by msec)
    from image_frame as i
    where i.channel_id = v_channel_id;
end;
$$

language plpgsql;
