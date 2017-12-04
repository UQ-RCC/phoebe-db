create or replace function insert_image(
    in v_directory text,
    in v_original_filename text,
    in v_channel_number integer,
    in v_channel_name text,    
    in v_msec integer) returns void as
$$
declare
    v_experiment_id bigint;
    v_channel_id bigint;
begin
    
    select id into v_experiment_id
    from experiment
    where directory = v_directory;

    if v_experiment_id is null then
        insert into experiment(directory) values(v_directory)        
        returning id into v_experiment_id;  
    end if;

    select id into v_channel_id
    from channel
    where experiment_id = v_experiment_id
    and channel_number = v_channel_number;

    if  v_channel_id is null then
        insert into channel(experiment_id, channel_number, name)
        values(v_experiment_id, v_channel_number, v_channel_name)
        returning id into v_channel_id;
    end if;

    insert into image_frame(channel_id, msec, filename, original_filename, status)
    values (v_channel_id, v_msec, uuid_generate_v4(), v_original_filename, 'scanned');

end;
$$
language plpgsql;