drop function neo_next_segmentation();

create or replace function neo_next_segmentation(
    out v_segmentation_frame_id bigint,
    out v_frame_number integer,
    out v_source_filename text,
    out v_directory text,
    out v_channel_number integer,
    out v_destination_filename text,
    out v_seg_value double precision,
    out v_width integer,
    out v_height integer,
    out v_depth integer) as
$$    
begin

    perform pg_advisory_xact_lock(1);
    
    update segmentation_frame
    set status = 'processing'
    where(id) =
    (   
        select sf.id
        from segmentation_frame as sf, segmentation as s, channel as c
        where sf.segmentation_id = s.id
        and s.channel_id = c.id        
        and sf.status = 'queued'
        and s.current_frame is not null
        order by s.priority desc nulls last, shift(coalesce(sf.frame_number, 0), s.current_frame, c.frame_count)
        limit 1 for update
    )
    returning id into v_segmentation_frame_id;
    
    select s.seg_value, if.width, if.height, if.depth, if.filename, sf.filename, e.directory, c.channel_number, coalesce(sf.frame_number, -1)
    into v_seg_value, v_width, v_height, v_depth, v_source_filename, v_destination_filename, v_directory, v_channel_number, v_frame_number
    from segmentation_frame as sf, segmentation as s, image_frame as if,  channel c, experiment e
    where sf.id = v_segmentation_frame_id
    and sf.segmentation_id = s.id
    and sf.image_frame_id = if.id
    and if.channel_id = c.id
    and c.experiment_id = e.id;

end;
$$
language plpgsql;