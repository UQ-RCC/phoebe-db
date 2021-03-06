DROP FUNCTION get_directories(text);

create or replace function get_directories(v_directory text default null)
returns table(id bigint, directory text, frames bigint, channels json) as
$$
        select e.id as id, e.directory as directory, max(fc.frames) as frames,
        (
            select array_to_json(array_agg(row_to_json(c)))
            from (
                    select c.id, c.channel_number, c.name,
                    (
                        select array_to_json(array_agg(row_to_json(s)))
                        from (
                                select s.id, s.seg_value as value
                                from segmentation as s
                                where s.channel_id = c.id                                
                                order by s.seg_value
                        ) as s
                    ) as segValues
                    from channel as c
                    where c.experiment_id = e.id                    
                    order by 2
            ) c
        ) as channels
        from experiment e, channel c,
            lateral (
                select count(*) as frames from image_frame
                where channel_id = c.id
            ) as fc
        where c.experiment_id = e.id
        and ((v_directory is null) or (directory like v_directory || '%'))
        group by 1, 2
        order by 1
$$
language sql;
