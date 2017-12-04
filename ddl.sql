--
-- PostgreSQL database dump
--

-- Dumped from database version 9.5.7
-- Dumped by pg_dump version 9.5.7

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


SET search_path = public, pg_catalog;

--
-- Name: activate_frame(bigint, integer); Type: FUNCTION; Schema: public; Owner: phoebeadmin
--

CREATE FUNCTION activate_frame(v_segmentation_id bigint, v_frame integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    update segmentation set current_frame = v_frame
    where id = v_segmentation_id;
end;
$$;


ALTER FUNCTION public.activate_frame(v_segmentation_id bigint, v_frame integer) OWNER TO phoebeadmin;

--
-- Name: complete_image(bigint, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: phoebeadmin
--

CREATE FUNCTION complete_image(v_id bigint, v_width integer, v_height integer, v_depth integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    update image_frame
    set (status, width, height, depth) = 
    ('complete', v_width, v_height, v_depth)
    where id = v_id;
end;
$$;


ALTER FUNCTION public.complete_image(v_id bigint, v_width integer, v_height integer, v_depth integer) OWNER TO phoebeadmin;

--
-- Name: deactivate_frame(bigint); Type: FUNCTION; Schema: public; Owner: phoebeadmin
--

CREATE FUNCTION deactivate_frame(v_segmentation_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    update segmentation set current_frame = null
    where id = v_segmentation_id;
end;
$$;


ALTER FUNCTION public.deactivate_frame(v_segmentation_id bigint) OWNER TO phoebeadmin;

--
-- Name: delete_segmentation(bigint); Type: FUNCTION; Schema: public; Owner: phoebeadmin
--

CREATE FUNCTION delete_segmentation(v_segmentation_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.delete_segmentation(v_segmentation_id bigint) OWNER TO phoebeadmin;

--
-- Name: end_log(bigint, text, bigint, text); Type: FUNCTION; Schema: public; Owner: phoebeadmin
--

CREATE FUNCTION end_log(v_id bigint, v_type text, v_f_key bigint, v_message text) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin    
    update log set
    (end_time, type, f_key, message) = (current_timestamp, v_type, v_f_key, v_message::jsonb)
    where id = v_id;
end;
$$;


ALTER FUNCTION public.end_log(v_id bigint, v_type text, v_f_key bigint, v_message text) OWNER TO phoebeadmin;

--
-- Name: enqueue_segmentation_job(integer, double precision); Type: FUNCTION; Schema: public; Owner: phoebeadmin
--

CREATE FUNCTION enqueue_segmentation_job(v_channel_id integer, v_seg_value double precision, OUT v_segmentation_id bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
begin

    insert into segmentation(channel_id, seg_value)
    values (v_channel_id, v_seg_value)
    returning id into v_segmentation_id;

    insert into segmentation_frame(segmentation_id, image_frame_id, filename, status, frame_number)
    select v_segmentation_id, i.id, uuid_generate_v4(), 'queued', row_number() over(order by msec)
    from image_frame as i
    where i.channel_id = v_channel_id;
end;
$$;


ALTER FUNCTION public.enqueue_segmentation_job(v_channel_id integer, v_seg_value double precision, OUT v_segmentation_id bigint) OWNER TO phoebeadmin;

--
-- Name: get_directories(text); Type: FUNCTION; Schema: public; Owner: phoebeadmin
--

CREATE FUNCTION get_directories(v_directory text DEFAULT NULL::text) RETURNS TABLE(id bigint, directory text, frames bigint, channels json)
    LANGUAGE sql
    AS $$
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
$$;


ALTER FUNCTION public.get_directories(v_directory text) OWNER TO phoebeadmin;

--
-- Name: get_image_frame_id(text); Type: FUNCTION; Schema: public; Owner: phoebeadmin
--

CREATE FUNCTION get_image_frame_id(v_path text, OUT v_image_frame_id bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.get_image_frame_id(v_path text, OUT v_image_frame_id bigint) OWNER TO phoebeadmin;

--
-- Name: get_seg_status(bigint); Type: FUNCTION; Schema: public; Owner: phoebeadmin
--

CREATE FUNCTION get_seg_status(v_segmentation_id bigint) RETURNS TABLE(msec integer, filename uuid, status text, id bigint)
    LANGUAGE sql
    AS $$
        select f.msec, s.filename, s.status, s.id
        from segmentation_frame as s, image_frame as f
        where s.segmentation_id = v_segmentation_id  
        and s.image_frame_id = f.id
        order by 1;
$$;


ALTER FUNCTION public.get_seg_status(v_segmentation_id bigint) OWNER TO phoebeadmin;

--
-- Name: insert_image(text, text, integer, text, integer); Type: FUNCTION; Schema: public; Owner: phoebeadmin
--

CREATE FUNCTION insert_image(v_directory text, v_original_filename text, v_channel_number integer, v_channel_name text, v_msec integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.insert_image(v_directory text, v_original_filename text, v_channel_number integer, v_channel_name text, v_msec integer) OWNER TO phoebeadmin;

--
-- Name: insert_image_stats(bigint, text, double precision, double precision); Type: FUNCTION; Schema: public; Owner: phoebeadmin
--

CREATE FUNCTION insert_image_stats(v_image_frame_id bigint, v_operation text, v_min double precision, v_max double precision) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    insert into image_frame_stats (image_frame_id, operation, min, max)
    values (v_image_frame_id, v_operation, v_min, v_max);  
    update image_frame set status = 'complete' where id = v_image_frame_id;
end;
$$;


ALTER FUNCTION public.insert_image_stats(v_image_frame_id bigint, v_operation text, v_min double precision, v_max double precision) OWNER TO phoebeadmin;

--
-- Name: insert_path(text); Type: FUNCTION; Schema: public; Owner: phoebeadmin
--

CREATE FUNCTION insert_path(v_path text) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.insert_path(v_path text) OWNER TO phoebeadmin;

--
-- Name: insert_segmentation(bigint, integer, integer, text); Type: FUNCTION; Schema: public; Owner: phoebeadmin
--

CREATE FUNCTION insert_segmentation(v_segmentation_frame_id bigint, v_object_count integer, v_cell_count integer, v_status text) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
        v_message jsonb;
begin
    update segmentation_frame
    set (object_count, cell_count, status) = 
        (v_object_count, v_cell_count, v_status)
    where id = v_segmentation_frame_id;

    if found then
        select to_jsonb(m) into v_message from
        (select s.channel_id, sf.segmentation_id, sf.id as segmentation_frame_id, sf.status
        from segmentation_frame as sf, segmentation s
        where sf.segmentation_id = s.id
        and sf.id = v_segmentation_frame_id) as m;

        perform pg_notify('proc_status', v_message::text);
    end if;


end;
$$;


ALTER FUNCTION public.insert_segmentation(v_segmentation_frame_id bigint, v_object_count integer, v_cell_count integer, v_status text) OWNER TO phoebeadmin;

--
-- Name: log(text, text, bigint); Type: FUNCTION; Schema: public; Owner: phoebeadmin
--

CREATE FUNCTION log(v_type text, v_message text, v_f_key bigint DEFAULT NULL::bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
    v_time timestamp with time zone := current_timestamp;
begin
    insert into log (start_time, end_time, type, f_key, message)
    values (v_time, v_time, v_type, v_f_key, v_message::jsonb);    
end;
$$;


ALTER FUNCTION public.log(v_type text, v_message text, v_f_key bigint) OWNER TO phoebeadmin;

--
-- Name: log_seg_frame_delete(); Type: FUNCTION; Schema: public; Owner: phoebeadmin
--

CREATE FUNCTION log_seg_frame_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    if (old.status) = 'complete' then
        insert into deleted_files (filename) values (old.filename);
    end if;
    return old;
end;
$$;


ALTER FUNCTION public.log_seg_frame_delete() OWNER TO phoebeadmin;

--
-- Name: neo_next_segmentation(); Type: FUNCTION; Schema: public; Owner: phoebeadmin
--

CREATE FUNCTION neo_next_segmentation(OUT v_segmentation_frame_id bigint, OUT v_frame_number integer, OUT v_source_filename text, OUT v_directory text, OUT v_channel_number integer, OUT v_destination_filename text, OUT v_seg_value double precision, OUT v_width integer, OUT v_height integer, OUT v_depth integer) RETURNS record
    LANGUAGE plpgsql
    AS $$    
begin

    perform pg_advisory_xact_lock(1);
    
    update segmentation_frame
    set status = 'processing'
    where(id) =
    (   
        select sf.id
        from segmentation_frame as sf, segmentation as s, channel as c
        where sf.segmentation_id = s.id
        and s.channel_id = c.id        
        and sf.status = 'queued'
        and s.current_frame is not null
        order by s.priority desc nulls last, shift(coalesce(sf.frame_number, 0), s.current_frame, c.frame_count)
        limit 1 for update
    )
    returning id into v_segmentation_frame_id;
    
    select s.seg_value, if.width, if.height, if.depth, if.filename, sf.filename, e.directory, c.channel_number, coalesce(sf.frame_number, -1)
    into v_seg_value, v_width, v_height, v_depth, v_source_filename, v_destination_filename, v_directory, v_channel_number, v_frame_number
    from segmentation_frame as sf, segmentation as s, image_frame as if,  channel c, experiment e
    where sf.id = v_segmentation_frame_id
    and sf.segmentation_id = s.id
    and sf.image_frame_id = if.id
    and if.channel_id = c.id
    and c.experiment_id = e.id;

end;
$$;


ALTER FUNCTION public.neo_next_segmentation(OUT v_segmentation_frame_id bigint, OUT v_frame_number integer, OUT v_source_filename text, OUT v_directory text, OUT v_channel_number integer, OUT v_destination_filename text, OUT v_seg_value double precision, OUT v_width integer, OUT v_height integer, OUT v_depth integer) OWNER TO phoebeadmin;

--
-- Name: next_deleted_file(text, text); Type: FUNCTION; Schema: public; Owner: phoebeadmin
--

CREATE FUNCTION next_deleted_file(INOUT v_filename text, v_status text) RETURNS text
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.next_deleted_file(INOUT v_filename text, v_status text) OWNER TO phoebeadmin;

--
-- Name: next_image(); Type: FUNCTION; Schema: public; Owner: phoebeadmin
--

CREATE FUNCTION next_image(OUT v_id bigint, OUT v_directory text, OUT v_original_filename text, OUT v_filename text) RETURNS record
    LANGUAGE plpgsql
    AS $$
begin
    update image_frame f set status = 'processing'
    from image_view iv
    where f.id = (
        select id from image_frame
        where status = 'scanned'
        order by id limit 1 for update
    )
    and f.id = iv.id
    returning f.id, iv.directory, f.original_filename, f.filename
    into v_id, v_directory, v_original_filename, v_filename;
end;
$$;


ALTER FUNCTION public.next_image(OUT v_id bigint, OUT v_directory text, OUT v_original_filename text, OUT v_filename text) OWNER TO phoebeadmin;

--
-- Name: next_segmentation(); Type: FUNCTION; Schema: public; Owner: phoebeadmin
--

CREATE FUNCTION next_segmentation(OUT v_segmentation_frame_id bigint, OUT v_source_filename text, OUT v_destination_filename text, OUT v_seg_value double precision, OUT v_width integer, OUT v_height integer, OUT v_depth integer) RETURNS record
    LANGUAGE plpgsql
    AS $$    
begin
    update segmentation_frame
    set status = 'processing'
    where(id) = (
        select sf.id
        from segmentation_frame sf, image_frame i        
        where sf.status = 'queued'
        and sf.image_frame_id = i.id
        order by i.msec
        limit 1 for update
    )
    returning id into v_segmentation_frame_id;

    select s.seg_value, if.width, if.height, if.depth, if.filename, sf.filename
    into v_seg_value, v_width, v_height, v_depth, v_source_filename, v_destination_filename
    from segmentation_frame as sf, segmentation as s, image_frame as if
    where sf.id = v_segmentation_frame_id
    and sf.segmentation_id = s.id
    and sf.image_frame_id = if.id;
end;
$$;


ALTER FUNCTION public.next_segmentation(OUT v_segmentation_frame_id bigint, OUT v_source_filename text, OUT v_destination_filename text, OUT v_seg_value double precision, OUT v_width integer, OUT v_height integer, OUT v_depth integer) OWNER TO phoebeadmin;

--
-- Name: shift(bigint, bigint, bigint); Type: FUNCTION; Schema: public; Owner: phoebeadmin
--

CREATE FUNCTION shift(v_value bigint, v_pivot bigint, v_max bigint, OUT v_pivot_value bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
declare
    v_temp_value bigint;
begin
    v_temp_value := v_value - v_pivot;
    if v_temp_value < 0 then
        v_temp_value := abs(v_temp_value) + v_max;
    end if;
    v_pivot_value := v_temp_value;
end;
$$;


ALTER FUNCTION public.shift(v_value bigint, v_pivot bigint, v_max bigint, OUT v_pivot_value bigint) OWNER TO phoebeadmin;

--
-- Name: start_log(); Type: FUNCTION; Schema: public; Owner: phoebeadmin
--

CREATE FUNCTION start_log(OUT v_id bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
begin
    insert into log (start_time) values (current_timestamp) returning id into v_id;
end;
$$;


ALTER FUNCTION public.start_log(OUT v_id bigint) OWNER TO phoebeadmin;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: channel; Type: TABLE; Schema: public; Owner: phoebeadmin
--

CREATE TABLE channel (
    id bigint NOT NULL,
    experiment_id bigint,
    channel_number integer NOT NULL,
    name text,
    frame_count integer
);


ALTER TABLE channel OWNER TO phoebeadmin;

--
-- Name: channel_id_seq; Type: SEQUENCE; Schema: public; Owner: phoebeadmin
--

CREATE SEQUENCE channel_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE channel_id_seq OWNER TO phoebeadmin;

--
-- Name: channel_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: phoebeadmin
--

ALTER SEQUENCE channel_id_seq OWNED BY channel.id;


--
-- Name: deleted_files; Type: TABLE; Schema: public; Owner: phoebeadmin
--

CREATE TABLE deleted_files (
    id bigint NOT NULL,
    filename uuid,
    status text DEFAULT 'waiting'::text
);


ALTER TABLE deleted_files OWNER TO phoebeadmin;

--
-- Name: deleted_files_id_seq; Type: SEQUENCE; Schema: public; Owner: phoebeadmin
--

CREATE SEQUENCE deleted_files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE deleted_files_id_seq OWNER TO phoebeadmin;

--
-- Name: deleted_files_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: phoebeadmin
--

ALTER SEQUENCE deleted_files_id_seq OWNED BY deleted_files.id;


--
-- Name: experiment; Type: TABLE; Schema: public; Owner: phoebeadmin
--

CREATE TABLE experiment (
    id bigint NOT NULL,
    directory text NOT NULL
);


ALTER TABLE experiment OWNER TO phoebeadmin;

--
-- Name: experiment_id_seq; Type: SEQUENCE; Schema: public; Owner: phoebeadmin
--

CREATE SEQUENCE experiment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE experiment_id_seq OWNER TO phoebeadmin;

--
-- Name: experiment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: phoebeadmin
--

ALTER SEQUENCE experiment_id_seq OWNED BY experiment.id;


--
-- Name: image_frame; Type: TABLE; Schema: public; Owner: phoebeadmin
--

CREATE TABLE image_frame (
    id bigint NOT NULL,
    channel_id bigint NOT NULL,
    msec integer NOT NULL,
    filename uuid NOT NULL,
    original_filename text,
    status text,
    width integer,
    height integer,
    depth integer
);


ALTER TABLE image_frame OWNER TO phoebeadmin;

--
-- Name: image_frame_id_seq; Type: SEQUENCE; Schema: public; Owner: phoebeadmin
--

CREATE SEQUENCE image_frame_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE image_frame_id_seq OWNER TO phoebeadmin;

--
-- Name: image_frame_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: phoebeadmin
--

ALTER SEQUENCE image_frame_id_seq OWNED BY image_frame.id;


--
-- Name: image_frame_stats; Type: TABLE; Schema: public; Owner: phoebeadmin
--

CREATE TABLE image_frame_stats (
    id bigint NOT NULL,
    image_frame_id bigint,
    operation text,
    min double precision,
    max double precision,
    histogram bigint[]
);


ALTER TABLE image_frame_stats OWNER TO phoebeadmin;

--
-- Name: image_frame_stats_id_seq; Type: SEQUENCE; Schema: public; Owner: phoebeadmin
--

CREATE SEQUENCE image_frame_stats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE image_frame_stats_id_seq OWNER TO phoebeadmin;

--
-- Name: image_frame_stats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: phoebeadmin
--

ALTER SEQUENCE image_frame_stats_id_seq OWNED BY image_frame_stats.id;


--
-- Name: image_view; Type: VIEW; Schema: public; Owner: phoebeadmin
--

CREATE VIEW image_view AS
 SELECT e.directory,
    c.channel_number,
    f.msec,
    f.original_filename,
    f.filename,
    f.status,
    f.id
   FROM experiment e,
    channel c,
    image_frame f
  WHERE ((e.id = c.experiment_id) AND (c.id = f.channel_id))
  ORDER BY e.directory, c.channel_number, f.msec;


ALTER TABLE image_view OWNER TO phoebeadmin;

--
-- Name: log; Type: TABLE; Schema: public; Owner: phoebeadmin
--

CREATE TABLE log (
    id bigint NOT NULL,
    start_time timestamp with time zone,
    end_time timestamp with time zone,
    type text,
    f_key bigint,
    message jsonb
);


ALTER TABLE log OWNER TO phoebeadmin;

--
-- Name: log_id_seq; Type: SEQUENCE; Schema: public; Owner: phoebeadmin
--

CREATE SEQUENCE log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE log_id_seq OWNER TO phoebeadmin;

--
-- Name: log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: phoebeadmin
--

ALTER SEQUENCE log_id_seq OWNED BY log.id;


--
-- Name: segmentation; Type: TABLE; Schema: public; Owner: phoebeadmin
--

CREATE TABLE segmentation (
    id bigint NOT NULL,
    channel_id bigint NOT NULL,
    seg_value double precision,
    current_frame integer,
    priority integer
);


ALTER TABLE segmentation OWNER TO phoebeadmin;

--
-- Name: segmentation_frame; Type: TABLE; Schema: public; Owner: phoebeadmin
--

CREATE TABLE segmentation_frame (
    id bigint NOT NULL,
    segmentation_id bigint,
    image_frame_id bigint,
    filename uuid,
    status text,
    object_count integer,
    cell_count integer,
    frame_number integer
);


ALTER TABLE segmentation_frame OWNER TO phoebeadmin;

--
-- Name: queue_view; Type: VIEW; Schema: public; Owner: phoebeadmin
--

CREATE VIEW queue_view AS
 SELECT iv.directory,
    iv.channel_number,
    seg.id AS seg_id,
    seg.seg_value,
    s.status,
    count(s.id) AS count
   FROM segmentation_frame s,
    image_view iv,
    segmentation seg
  WHERE ((s.image_frame_id = iv.id) AND (seg.id = s.segmentation_id))
  GROUP BY iv.directory, iv.channel_number, seg.id, seg.seg_value, s.status;


ALTER TABLE queue_view OWNER TO phoebeadmin;

--
-- Name: segmentation_channel_id_seq; Type: SEQUENCE; Schema: public; Owner: phoebeadmin
--

CREATE SEQUENCE segmentation_channel_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE segmentation_channel_id_seq OWNER TO phoebeadmin;

--
-- Name: segmentation_channel_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: phoebeadmin
--

ALTER SEQUENCE segmentation_channel_id_seq OWNED BY segmentation.channel_id;


--
-- Name: segmentation_frame_id_seq; Type: SEQUENCE; Schema: public; Owner: phoebeadmin
--

CREATE SEQUENCE segmentation_frame_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE segmentation_frame_id_seq OWNER TO phoebeadmin;

--
-- Name: segmentation_frame_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: phoebeadmin
--

ALTER SEQUENCE segmentation_frame_id_seq OWNED BY segmentation_frame.id;


--
-- Name: segmentation_id_seq; Type: SEQUENCE; Schema: public; Owner: phoebeadmin
--

CREATE SEQUENCE segmentation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE segmentation_id_seq OWNER TO phoebeadmin;

--
-- Name: segmentation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: phoebeadmin
--

ALTER SEQUENCE segmentation_id_seq OWNED BY segmentation.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY channel ALTER COLUMN id SET DEFAULT nextval('channel_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY deleted_files ALTER COLUMN id SET DEFAULT nextval('deleted_files_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY experiment ALTER COLUMN id SET DEFAULT nextval('experiment_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY image_frame ALTER COLUMN id SET DEFAULT nextval('image_frame_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY image_frame_stats ALTER COLUMN id SET DEFAULT nextval('image_frame_stats_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY log ALTER COLUMN id SET DEFAULT nextval('log_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY segmentation ALTER COLUMN id SET DEFAULT nextval('segmentation_id_seq'::regclass);


--
-- Name: channel_id; Type: DEFAULT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY segmentation ALTER COLUMN channel_id SET DEFAULT nextval('segmentation_channel_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY segmentation_frame ALTER COLUMN id SET DEFAULT nextval('segmentation_frame_id_seq'::regclass);


--
-- Name: channel_pkey; Type: CONSTRAINT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY channel
    ADD CONSTRAINT channel_pkey PRIMARY KEY (id);


--
-- Name: deleted_files_pkey; Type: CONSTRAINT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY deleted_files
    ADD CONSTRAINT deleted_files_pkey PRIMARY KEY (id);


--
-- Name: experiment_directory_key; Type: CONSTRAINT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY experiment
    ADD CONSTRAINT experiment_directory_key UNIQUE (directory);


--
-- Name: experiment_pkey; Type: CONSTRAINT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY experiment
    ADD CONSTRAINT experiment_pkey PRIMARY KEY (id);


--
-- Name: image_frame_filename_key; Type: CONSTRAINT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY image_frame
    ADD CONSTRAINT image_frame_filename_key UNIQUE (filename);


--
-- Name: image_frame_pkey; Type: CONSTRAINT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY image_frame
    ADD CONSTRAINT image_frame_pkey PRIMARY KEY (id);


--
-- Name: image_frame_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY image_frame_stats
    ADD CONSTRAINT image_frame_stats_pkey PRIMARY KEY (id);


--
-- Name: log_pkey; Type: CONSTRAINT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY log
    ADD CONSTRAINT log_pkey PRIMARY KEY (id);


--
-- Name: segmentation_frame_pkey; Type: CONSTRAINT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY segmentation_frame
    ADD CONSTRAINT segmentation_frame_pkey PRIMARY KEY (id);


--
-- Name: segmentation_pkey; Type: CONSTRAINT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY segmentation
    ADD CONSTRAINT segmentation_pkey PRIMARY KEY (id);


--
-- Name: channel_id_channel_number_idx; Type: INDEX; Schema: public; Owner: phoebeadmin
--

CREATE UNIQUE INDEX channel_id_channel_number_idx ON channel USING btree (id, channel_number);


--
-- Name: deleted_files_filename_idx; Type: INDEX; Schema: public; Owner: phoebeadmin
--

CREATE INDEX deleted_files_filename_idx ON deleted_files USING btree (filename);


--
-- Name: image_frame_channel_id_msec_idx; Type: INDEX; Schema: public; Owner: phoebeadmin
--

CREATE UNIQUE INDEX image_frame_channel_id_msec_idx ON image_frame USING btree (channel_id, msec);


--
-- Name: image_frame_stats_image_frame_id_operation_idx; Type: INDEX; Schema: public; Owner: phoebeadmin
--

CREATE UNIQUE INDEX image_frame_stats_image_frame_id_operation_idx ON image_frame_stats USING btree (image_frame_id, operation);


--
-- Name: segmentation_channel_id_seg_value_idx; Type: INDEX; Schema: public; Owner: phoebeadmin
--

CREATE UNIQUE INDEX segmentation_channel_id_seg_value_idx ON segmentation USING btree (channel_id, seg_value);


--
-- Name: delete_trigger; Type: TRIGGER; Schema: public; Owner: phoebeadmin
--

CREATE TRIGGER delete_trigger AFTER DELETE ON segmentation_frame FOR EACH ROW EXECUTE PROCEDURE log_seg_frame_delete();


--
-- Name: channel_experiment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY channel
    ADD CONSTRAINT channel_experiment_id_fkey FOREIGN KEY (experiment_id) REFERENCES experiment(id) ON DELETE CASCADE;


--
-- Name: image_frame_channel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY image_frame
    ADD CONSTRAINT image_frame_channel_id_fkey FOREIGN KEY (channel_id) REFERENCES channel(id) ON DELETE CASCADE;


--
-- Name: image_frame_stats_image_frame_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY image_frame_stats
    ADD CONSTRAINT image_frame_stats_image_frame_id_fkey FOREIGN KEY (image_frame_id) REFERENCES image_frame(id) ON DELETE CASCADE;


--
-- Name: segmentation_channel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY segmentation
    ADD CONSTRAINT segmentation_channel_id_fkey FOREIGN KEY (channel_id) REFERENCES channel(id) ON DELETE CASCADE;


--
-- Name: segmentation_frame_image_frame_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY segmentation_frame
    ADD CONSTRAINT segmentation_frame_image_frame_id_fkey FOREIGN KEY (image_frame_id) REFERENCES image_frame(id);


--
-- Name: segmentation_frame_segmentation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY segmentation_frame
    ADD CONSTRAINT segmentation_frame_segmentation_id_fkey FOREIGN KEY (segmentation_id) REFERENCES segmentation(id) ON DELETE CASCADE;


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- Name: channel; Type: ACL; Schema: public; Owner: phoebeadmin
--

REVOKE ALL ON TABLE channel FROM PUBLIC;
REVOKE ALL ON TABLE channel FROM phoebeadmin;
GRANT ALL ON TABLE channel TO phoebeadmin;
GRANT SELECT,INSERT ON TABLE channel TO dataimport;
GRANT SELECT ON TABLE channel TO phoebeuser;


--
-- Name: channel_id_seq; Type: ACL; Schema: public; Owner: phoebeadmin
--

REVOKE ALL ON SEQUENCE channel_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE channel_id_seq FROM phoebeadmin;
GRANT ALL ON SEQUENCE channel_id_seq TO phoebeadmin;
GRANT ALL ON SEQUENCE channel_id_seq TO dataimport;


--
-- Name: deleted_files; Type: ACL; Schema: public; Owner: phoebeadmin
--

REVOKE ALL ON TABLE deleted_files FROM PUBLIC;
REVOKE ALL ON TABLE deleted_files FROM phoebeadmin;
GRANT ALL ON TABLE deleted_files TO phoebeadmin;
GRANT SELECT,UPDATE ON TABLE deleted_files TO dataimport;


--
-- Name: experiment; Type: ACL; Schema: public; Owner: phoebeadmin
--

REVOKE ALL ON TABLE experiment FROM PUBLIC;
REVOKE ALL ON TABLE experiment FROM phoebeadmin;
GRANT ALL ON TABLE experiment TO phoebeadmin;
GRANT SELECT,INSERT ON TABLE experiment TO dataimport;
GRANT SELECT ON TABLE experiment TO phoebeuser;


--
-- Name: experiment_id_seq; Type: ACL; Schema: public; Owner: phoebeadmin
--

REVOKE ALL ON SEQUENCE experiment_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE experiment_id_seq FROM phoebeadmin;
GRANT ALL ON SEQUENCE experiment_id_seq TO phoebeadmin;
GRANT ALL ON SEQUENCE experiment_id_seq TO dataimport;


--
-- Name: image_frame; Type: ACL; Schema: public; Owner: phoebeadmin
--

REVOKE ALL ON TABLE image_frame FROM PUBLIC;
REVOKE ALL ON TABLE image_frame FROM phoebeadmin;
GRANT ALL ON TABLE image_frame TO phoebeadmin;
GRANT SELECT,INSERT ON TABLE image_frame TO dataimport;
GRANT SELECT ON TABLE image_frame TO phoebeuser;


--
-- Name: image_frame.status; Type: ACL; Schema: public; Owner: phoebeadmin
--

REVOKE ALL(status) ON TABLE image_frame FROM PUBLIC;
REVOKE ALL(status) ON TABLE image_frame FROM phoebeadmin;
GRANT UPDATE(status) ON TABLE image_frame TO dataimport;


--
-- Name: image_frame.width; Type: ACL; Schema: public; Owner: phoebeadmin
--

REVOKE ALL(width) ON TABLE image_frame FROM PUBLIC;
REVOKE ALL(width) ON TABLE image_frame FROM phoebeadmin;
GRANT UPDATE(width) ON TABLE image_frame TO dataimport;


--
-- Name: image_frame.height; Type: ACL; Schema: public; Owner: phoebeadmin
--

REVOKE ALL(height) ON TABLE image_frame FROM PUBLIC;
REVOKE ALL(height) ON TABLE image_frame FROM phoebeadmin;
GRANT UPDATE(height) ON TABLE image_frame TO dataimport;


--
-- Name: image_frame.depth; Type: ACL; Schema: public; Owner: phoebeadmin
--

REVOKE ALL(depth) ON TABLE image_frame FROM PUBLIC;
REVOKE ALL(depth) ON TABLE image_frame FROM phoebeadmin;
GRANT UPDATE(depth) ON TABLE image_frame TO dataimport;


--
-- Name: image_frame_id_seq; Type: ACL; Schema: public; Owner: phoebeadmin
--

REVOKE ALL ON SEQUENCE image_frame_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE image_frame_id_seq FROM phoebeadmin;
GRANT ALL ON SEQUENCE image_frame_id_seq TO phoebeadmin;
GRANT ALL ON SEQUENCE image_frame_id_seq TO dataimport;


--
-- Name: image_frame_stats; Type: ACL; Schema: public; Owner: phoebeadmin
--

REVOKE ALL ON TABLE image_frame_stats FROM PUBLIC;
REVOKE ALL ON TABLE image_frame_stats FROM phoebeadmin;
GRANT ALL ON TABLE image_frame_stats TO phoebeadmin;
GRANT SELECT,INSERT,UPDATE ON TABLE image_frame_stats TO dataimport;


--
-- Name: image_frame_stats_id_seq; Type: ACL; Schema: public; Owner: phoebeadmin
--

REVOKE ALL ON SEQUENCE image_frame_stats_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE image_frame_stats_id_seq FROM phoebeadmin;
GRANT ALL ON SEQUENCE image_frame_stats_id_seq TO phoebeadmin;
GRANT SELECT,UPDATE ON SEQUENCE image_frame_stats_id_seq TO dataimport;


--
-- Name: image_view; Type: ACL; Schema: public; Owner: phoebeadmin
--

REVOKE ALL ON TABLE image_view FROM PUBLIC;
REVOKE ALL ON TABLE image_view FROM phoebeadmin;
GRANT ALL ON TABLE image_view TO phoebeadmin;
GRANT SELECT ON TABLE image_view TO dataimport;
GRANT SELECT ON TABLE image_view TO phoebeuser;


--
-- Name: log; Type: ACL; Schema: public; Owner: phoebeadmin
--

REVOKE ALL ON TABLE log FROM PUBLIC;
REVOKE ALL ON TABLE log FROM phoebeadmin;
GRANT ALL ON TABLE log TO phoebeadmin;
GRANT SELECT,INSERT,UPDATE ON TABLE log TO dataimport;


--
-- Name: log_id_seq; Type: ACL; Schema: public; Owner: phoebeadmin
--

REVOKE ALL ON SEQUENCE log_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE log_id_seq FROM phoebeadmin;
GRANT ALL ON SEQUENCE log_id_seq TO phoebeadmin;
GRANT SELECT,UPDATE ON SEQUENCE log_id_seq TO dataimport;


--
-- Name: segmentation; Type: ACL; Schema: public; Owner: phoebeadmin
--

REVOKE ALL ON TABLE segmentation FROM PUBLIC;
REVOKE ALL ON TABLE segmentation FROM phoebeadmin;
GRANT ALL ON TABLE segmentation TO phoebeadmin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE segmentation TO phoebeuser;


--
-- Name: segmentation_frame; Type: ACL; Schema: public; Owner: phoebeadmin
--

REVOKE ALL ON TABLE segmentation_frame FROM PUBLIC;
REVOKE ALL ON TABLE segmentation_frame FROM phoebeadmin;
GRANT ALL ON TABLE segmentation_frame TO phoebeadmin;
GRANT SELECT,INSERT ON TABLE segmentation_frame TO phoebeuser;


--
-- Name: segmentation_frame_id_seq; Type: ACL; Schema: public; Owner: phoebeadmin
--

REVOKE ALL ON SEQUENCE segmentation_frame_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE segmentation_frame_id_seq FROM phoebeadmin;
GRANT ALL ON SEQUENCE segmentation_frame_id_seq TO phoebeadmin;
GRANT SELECT,UPDATE ON SEQUENCE segmentation_frame_id_seq TO phoebeuser;


--
-- Name: segmentation_id_seq; Type: ACL; Schema: public; Owner: phoebeadmin
--

REVOKE ALL ON SEQUENCE segmentation_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE segmentation_id_seq FROM phoebeadmin;
GRANT ALL ON SEQUENCE segmentation_id_seq TO phoebeadmin;
GRANT SELECT,UPDATE ON SEQUENCE segmentation_id_seq TO phoebeuser;


--
-- PostgreSQL database dump complete
--

