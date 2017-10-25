create or replace function get_seg_status(in v_directory text, in v_channel integer, in v_seg_value double precision)
returns table(frame_seq integer, file_name text, status text) as
$$
        select s.frame_seq, s.file_name, s.status
        from frame as f, segmentation as s
        where s.frame_id = f.id
        and s.seg_value = v_seg_value
        and f.directory = v_directory
        and f.operation like 'convert%'
        order by 1;
$$
language sql;
