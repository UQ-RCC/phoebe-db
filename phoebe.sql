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
-- Name: insert_image(text, text, integer, text, uuid, integer); Type: FUNCTION; Schema: public; Owner: phoebeadmin
--

CREATE FUNCTION insert_image(v_directory text, v_original_filename text, v_channel_number integer, v_channel_name text, v_filename uuid, v_sequence integer, OUT v_id bigint) RETURNS bigint
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

    insert into image_frame(channel_id, sequence, filename, original_filename)
    values (v_channel_id, v_sequence, v_filename, v_original_filename)
    returning id into v_id;

end;
$$;


ALTER FUNCTION public.insert_image(v_directory text, v_original_filename text, v_channel_number integer, v_channel_name text, v_filename uuid, v_sequence integer, OUT v_id bigint) OWNER TO phoebeadmin;

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
    sequence integer NOT NULL,
    filename uuid NOT NULL,
    original_filename text
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
-- Name: channel_id_channel_number_idx; Type: INDEX; Schema: public; Owner: phoebeadmin
--

CREATE UNIQUE INDEX channel_id_channel_number_idx ON channel USING btree (id, channel_number);


--
-- Name: image_frame_channel_id_sequence_idx; Type: INDEX; Schema: public; Owner: phoebeadmin
--

CREATE UNIQUE INDEX image_frame_channel_id_sequence_idx ON image_frame USING btree (channel_id, sequence);


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
-- PostgreSQL database dump complete
--

