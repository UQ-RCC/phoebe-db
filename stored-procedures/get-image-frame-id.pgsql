create or replace function get_image_frame_id(
    in v_path text,
    out v_image_frame_id bigint
) as
$$
declare
    v_regex_result text[];
    v_directory text;
    v_filename text;    
begin
    v_regex_result := regexp_matches(v_path,'(.*)(?:\/)(.*)');
    v_directory := v_regex_result[1];
    v_filename := v_regex_result[2];    
    select id into v_image_frame_id from image_view
    where directory = v_directory
    and original_filename = v_filename;
end;
$$
language plpgsql;
