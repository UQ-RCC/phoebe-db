create or replace function insert_path(
    in v_path text    
) returns void as
$$
declare
    v_regex_result text[];
    v_directory text;
    v_filename text;
    v_channel integer;
    v_msec integer;
begin
    v_regex_result := regexp_matches(v_path,'(.*)(?:\/)(.*)');
    v_directory := v_regex_result[1];
    v_filename := v_regex_result[2];
    v_channel := (regexp_matches(v_filename,'(?:_ch)([0-9]+)(?:_)'))[1]::integer;
    v_msec := (regexp_matches(v_filename,'(?:_)([0-9]+)(?:msec_)'))[1]::integer;
    perform insert_image(v_directory, v_filename, v_channel, null, v_msec);
end;
$$
language plpgsql;
