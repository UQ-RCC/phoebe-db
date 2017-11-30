create or replace function log_seg_frame_delete() returns trigger as
$$
begin
    if (old.status) = 'complete' then
        insert into deleted_files (filename) values (old.filename);
    end if;
    return old;
end;
$$
language plpgsql;

drop trigger if exists delete_trigger on segmentation_frame;

create trigger delete_trigger after delete on segmentation_frame
for each row execute procedure log_seg_frame_delete();