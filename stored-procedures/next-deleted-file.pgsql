create or replace function next_deleted_file(
    inout v_filename text,
    in v_status text    
) as
$$
begin
    if v_filename is not null then    
        update deleted_files set status = v_status
        where filename = v_filename::uuid;        
    end if;    
    update deleted_files set status = 'processing'
    where id = (
        select id from deleted_files
        where status = 'waiting'
        limit 1 for update
    )
    returning filename::text into v_filename;
end;
$$
language plpgsql;