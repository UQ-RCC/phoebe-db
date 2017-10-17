--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.2
-- Dumped by pg_dump version 9.6.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
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
    name text
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
-- Name: image_view; Type: VIEW; Schema: public; Owner: phoebeadmin
--

CREATE VIEW image_view AS
 SELECT e.directory,
    c.channel_number,
    f.msec,
    f.original_filename,
    f.filename,
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
-- Name: channel id; Type: DEFAULT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY channel ALTER COLUMN id SET DEFAULT nextval('channel_id_seq'::regclass);


--
-- Name: experiment id; Type: DEFAULT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY experiment ALTER COLUMN id SET DEFAULT nextval('experiment_id_seq'::regclass);


--
-- Name: image_frame id; Type: DEFAULT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY image_frame ALTER COLUMN id SET DEFAULT nextval('image_frame_id_seq'::regclass);


--
-- Name: log id; Type: DEFAULT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY log ALTER COLUMN id SET DEFAULT nextval('log_id_seq'::regclass);


--
-- Name: channel channel_pkey; Type: CONSTRAINT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY channel
    ADD CONSTRAINT channel_pkey PRIMARY KEY (id);


--
-- Name: experiment experiment_directory_key; Type: CONSTRAINT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY experiment
    ADD CONSTRAINT experiment_directory_key UNIQUE (directory);


--
-- Name: experiment experiment_pkey; Type: CONSTRAINT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY experiment
    ADD CONSTRAINT experiment_pkey PRIMARY KEY (id);


--
-- Name: image_frame image_frame_filename_key; Type: CONSTRAINT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY image_frame
    ADD CONSTRAINT image_frame_filename_key UNIQUE (filename);


--
-- Name: image_frame image_frame_pkey; Type: CONSTRAINT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY image_frame
    ADD CONSTRAINT image_frame_pkey PRIMARY KEY (id);


--
-- Name: log log_pkey; Type: CONSTRAINT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY log
    ADD CONSTRAINT log_pkey PRIMARY KEY (id);


--
-- Name: channel_id_channel_number_idx; Type: INDEX; Schema: public; Owner: phoebeadmin
--

CREATE UNIQUE INDEX channel_id_channel_number_idx ON channel USING btree (id, channel_number);


--
-- Name: image_frame_channel_id_msec_idx; Type: INDEX; Schema: public; Owner: phoebeadmin
--

CREATE UNIQUE INDEX image_frame_channel_id_msec_idx ON image_frame USING btree (channel_id, msec);


--
-- Name: channel channel_experiment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY channel
    ADD CONSTRAINT channel_experiment_id_fkey FOREIGN KEY (experiment_id) REFERENCES experiment(id) ON DELETE CASCADE;


--
-- Name: image_frame image_frame_channel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY image_frame
    ADD CONSTRAINT image_frame_channel_id_fkey FOREIGN KEY (channel_id) REFERENCES channel(id) ON DELETE CASCADE;


--
-- Name: channel; Type: ACL; Schema: public; Owner: phoebeadmin
--

GRANT SELECT,INSERT ON TABLE channel TO dataimport;


--
-- Name: channel_id_seq; Type: ACL; Schema: public; Owner: phoebeadmin
--

GRANT ALL ON SEQUENCE channel_id_seq TO dataimport;


--
-- Name: experiment; Type: ACL; Schema: public; Owner: phoebeadmin
--

GRANT SELECT,INSERT ON TABLE experiment TO dataimport;


--
-- Name: experiment_id_seq; Type: ACL; Schema: public; Owner: phoebeadmin
--

GRANT ALL ON SEQUENCE experiment_id_seq TO dataimport;


--
-- Name: image_frame; Type: ACL; Schema: public; Owner: phoebeadmin
--

GRANT SELECT,INSERT ON TABLE image_frame TO dataimport;


--
-- Name: image_frame.status; Type: ACL; Schema: public; Owner: phoebeadmin
--

GRANT UPDATE(status) ON TABLE image_frame TO dataimport;


--
-- Name: image_frame.width; Type: ACL; Schema: public; Owner: phoebeadmin
--

GRANT UPDATE(width) ON TABLE image_frame TO dataimport;


--
-- Name: image_frame.height; Type: ACL; Schema: public; Owner: phoebeadmin
--

GRANT UPDATE(height) ON TABLE image_frame TO dataimport;


--
-- Name: image_frame.depth; Type: ACL; Schema: public; Owner: phoebeadmin
--

GRANT UPDATE(depth) ON TABLE image_frame TO dataimport;


--
-- Name: image_frame_id_seq; Type: ACL; Schema: public; Owner: phoebeadmin
--

GRANT ALL ON SEQUENCE image_frame_id_seq TO dataimport;


--
-- Name: image_view; Type: ACL; Schema: public; Owner: phoebeadmin
--

GRANT SELECT ON TABLE image_view TO dataimport;


--
-- Name: log; Type: ACL; Schema: public; Owner: phoebeadmin
--

GRANT SELECT,INSERT,UPDATE ON TABLE log TO dataimport;


--
-- Name: log_id_seq; Type: ACL; Schema: public; Owner: phoebeadmin
--

GRANT SELECT,UPDATE ON SEQUENCE log_id_seq TO dataimport;


--
-- PostgreSQL database dump complete
--

