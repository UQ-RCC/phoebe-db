create or replace function delete_segmentation(
    in v_segmentation_id bigint) returns void as
$$
declare
    v_message jsonb;
begin

    select to_jsonb(m) into v_message from
        (select s.channel_id, id as segmentation_id, null as segmentation_frame_id, 'deleted' as status
        from segmentation s
        where id = v_segmentation_id) as m;

    delete from segmentation where id = v_segmentation_id;
    
    if found then
        perform pg_notify('proc_status', v_message::text);
    end if;
end;
$$
language plpgsql;