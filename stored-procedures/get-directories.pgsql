create or replace function get_directories(v_directory text default null)
returns table(directory text, frame_count bigint, channels json) as
$$
        select directory,
        (
            select max(frame_count) from
            (
                select c.id, count(*) as frame_count from image_frame as if, channel as c
                where if.channel_id = c.id
                and c.experiment_id = e.id
                group by 1 order by 2
            ) frame_channel_count
        ) as frame_count,
        (
            select array_to_json(array_agg(row_to_json(c)))
            from (
                    select c.channel_number, c.name,
                    (
                        select array_to_json(array_agg(row_to_json(s)))
                        from (
                                select seg_value as value
                                from segmentation as s, image_frame as if
                                where s.frame_id = if.id
                                and if.channel_id = c.id
                                and s.status = 'complete'
                                order by s.seg_value
                        ) s
                    ) as segValues
                    from channel as c
                    where c.experiment_id = e.id                    
                    order by 2
            ) c
        ) as channels
        from experiment e
        where ((v_directory is null) or (directory like v_directory || '%'))
        order by 1
$$
language sql;
