create or replace function next_image(
    out v_id bigint,
    out v_directory text,
    out v_original_filename text,
    out v_filename text
) as
$$
begin
    update image_frame f set status = 'processing'
    from image_view iv
    where id = (
        select id from image_frame
        where status = 'scanned'
        order by id limit 1 for update
    )
    and f.id = iv.id
    returning f.id, iv.directory, f.originale_filename, f.filename
    into v_id, v_directory, v_original_filename, v_filename;
end;
$$
language plpgsql;