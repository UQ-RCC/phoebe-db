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
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET search_path = public, pg_catalog;

--
-- Name: enqueue_work(text, integer, double precision); Type: FUNCTION; Schema: public; Owner: vizadmin
--

CREATE FUNCTION enqueue_work(indirectory text, inchannel integer, insegvalue double precision) RETURNS record
    LANGUAGE plpgsql
    AS $$
declare
	curs cursor (c_dir text, c_channel integer) for
		select id from frame where directory = c_dir
			and channel = c_channel
			and operation like 'convert%'
			order by file_name;
	rowvar record;
	seq integer;
	maxPriority integer;
	numFrames integer;
begin
	seq := 0;

	select count(*) into numFrames from frame
	where directory = inDirectory
	and channel = inChannel
	and operation like 'sub%'
	group by directory;

	select coalesce(max(priority), 0) into maxPriority from segmentation;
	open curs(inDirectory, inChannel);
	loop
		fetch curs into rowvar;
		exit when not found;
		insert into segmentation (frame_seq, frame_id, priority, status, seg_value) values 
			(seq, rowvar.id, (maxPriority + numFrames) - seq, 'queued', inSegValue);
		seq := seq + 1;
		perform send_message(rowvar.id, inSegValue, 'queued');
	end loop;
	close curs;
	return rowvar;
end;
$$;


ALTER FUNCTION public.enqueue_work(indirectory text, inchannel integer, insegvalue double precision) OWNER TO vizadmin;

--
-- Name: get_directories(text); Type: FUNCTION; Schema: public; Owner: vizadmin
--

CREATE FUNCTION get_directories(v_directory text DEFAULT ''::text) RETURNS TABLE(directory text, frames bigint, channels json)
    LANGUAGE sql
    AS $$
	select directory, count(*) as frame_count,
		(
			select array_to_json(array_agg(row_to_json(c)))
			from (
				select channel, channel_type,
				(
					select array_to_json(array_agg(row_to_json(s)))
					from (
						select seg_value as value
						from seg_view as sv
						where sv.directory = frame.directory
						and sv.channel = f2.channel
						and seg_value is not null
						order by sv.seg_value
					) s
				) as segValues
				from frame as f2
				where f2.directory = frame.directory
				group by 1, 2
				order by 1
			) c
		) as channels
	from frame
	where operation like 'conver%'
	and ((v_directory is null) or (directory like v_directory || '%'))
	group by directory
	order by 1
$$;


ALTER FUNCTION public.get_directories(v_directory text) OWNER TO vizadmin;

--
-- Name: get_operations(text, integer); Type: FUNCTION; Schema: public; Owner: vizadmin
--

CREATE FUNCTION get_operations(v_directory text, v_channel integer) RETURNS TABLE(operation text, seg_value double precision)
    LANGUAGE sql
    AS $$
	select 'segmentation'::text, seg_value
	from seg_view
	where directory = v_directory
	and channel = v_channel
	and seg_value is not null
	order by seg_value
$$;


ALTER FUNCTION public.get_operations(v_directory text, v_channel integer) OWNER TO vizadmin;

--
-- Name: get_raw_files(text); Type: FUNCTION; Schema: public; Owner: vizadmin
--

CREATE FUNCTION get_raw_files(v_directory text) RETURNS TABLE(file_name text, pixel_file_name text)
    LANGUAGE sql
    AS $$
	select file_name, pixel_file_name
	from frame
	where directory = v_directory
$$;


ALTER FUNCTION public.get_raw_files(v_directory text) OWNER TO vizadmin;

--
-- Name: get_seg_status(text, integer, double precision); Type: FUNCTION; Schema: public; Owner: vizadmin
--

CREATE FUNCTION get_seg_status(v_directory text, v_channel integer, v_seg_value double precision) RETURNS TABLE(file_name text, status text)
    LANGUAGE sql
    AS $$
	select f.file_name, s.status
	from frame as f
	left outer join segmentation as s
	on (f.id = s.frame_id and s.seg_value = v_seg_value)
	where f.directory = v_directory
	and f.operation like 'convert%'
$$;


ALTER FUNCTION public.get_seg_status(v_directory text, v_channel integer, v_seg_value double precision) OWNER TO vizadmin;

--
-- Name: get_work_id(text, integer, double precision); Type: FUNCTION; Schema: public; Owner: vizadmin
--

CREATE FUNCTION get_work_id(indirectory text, inchannel integer, insegvalue double precision) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
declare
	channelID uuid;
begin
	insert into log(description) values('dir: '||inDirectory);
	insert into log(description) values('value inserted');
	insert into monitor_work(directory, channel, seg_iso)
	values (inDirectory, inChannel, inSegValue)
	on conflict do nothing
	returning channel_id into channelID;

	channelID =  coalesce(channelID,
		(select channel_id from monitor_work
		where directory = inDirectory
		and channel = inChannel
		and seg_iso = inSegValue)
	);

	return channelID;
end;
$$;


ALTER FUNCTION public.get_work_id(indirectory text, inchannel integer, insegvalue double precision) OWNER TO vizadmin;

--
-- Name: inc(integer); Type: FUNCTION; Schema: public; Owner: vizadmin
--

CREATE FUNCTION inc(val integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$

begin
return val + 10;
end;

$$;


ALTER FUNCTION public.inc(val integer) OWNER TO vizadmin;

--
-- Name: insert_mesh(integer, text, text, integer, integer, integer, double precision, text); Type: FUNCTION; Schema: public; Owner: vizadmin
--

CREATE FUNCTION insert_mesh(v_frame_id integer, v_directory text, v_file_name text, v_object_count integer, v_cell_count integer, v_index_count integer, v_seg_iso double precision, v_process_code text) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into mesh values(v_frame_id, v_directory, v_file_name, v_object_count, v_cell_count, v_index_count,
		v_seg_iso, v_process_code);

	update mesh_queue set status = 'complete', end_time = now() where frame_id = V_frame_id;
end;
$$;


ALTER FUNCTION public.insert_mesh(v_frame_id integer, v_directory text, v_file_name text, v_object_count integer, v_cell_count integer, v_index_count integer, v_seg_iso double precision, v_process_code text) OWNER TO vizadmin;

--
-- Name: insert_mesh(integer, text, text, integer, integer, integer, integer, text); Type: FUNCTION; Schema: public; Owner: vizadmin
--

CREATE FUNCTION insert_mesh(v_frame_id integer, v_directory text, v_file_name text, v_object_count integer, v_cell_count integer, v_index_count integer, v_seg_iso integer, v_process_code text) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into mesh values(v_frame_id, v_directory, v_file_name, v_object_count, v_cell_count, v_index_count,
		v_seg_iso, v_process_code);

	update mesh_queue set status = 'complete', end_time = now() where frame_id = V_frame_id;
end;
$$;


ALTER FUNCTION public.insert_mesh(v_frame_id integer, v_directory text, v_file_name text, v_object_count integer, v_cell_count integer, v_index_count integer, v_seg_iso integer, v_process_code text) OWNER TO vizadmin;

--
-- Name: insert_mesh(integer, text, text, integer, integer, integer, numeric, text); Type: FUNCTION; Schema: public; Owner: vizadmin
--

CREATE FUNCTION insert_mesh(v_frame_id integer, v_directory text, v_file_name text, v_object_count integer, v_cell_count integer, v_index_count integer, v_seg_iso numeric, v_process_code text) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into mesh values(v_frame_id, v_directory, v_file_name, v_object_count, v_cell_count, v_index_count,
		v_seg_iso, v_process_code);

	update mesh_queue set status = 'complete', end_time = now() where frame_id = V_frame_id;
end;
$$;


ALTER FUNCTION public.insert_mesh(v_frame_id integer, v_directory text, v_file_name text, v_object_count integer, v_cell_count integer, v_index_count integer, v_seg_iso numeric, v_process_code text) OWNER TO vizadmin;

--
-- Name: insert_mesh(integer, text, text, integer, numeric, integer, integer, text); Type: FUNCTION; Schema: public; Owner: vizadmin
--

CREATE FUNCTION insert_mesh(v_frame_id integer, v_directory text, v_file_name text, v_object_count integer, v_cell_count numeric, v_index_count integer, v_seg_iso integer, v_process_code text) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into mesh values(v_frame_id, v_directory, v_file_name, v_object_count, v_cell_count, v_index_count,
		v_seg_iso, v_process_code);

	update mesh_queue set status = 'complete', end_time = now() where frame_id = V_frame_id;
end;
$$;


ALTER FUNCTION public.insert_mesh(v_frame_id integer, v_directory text, v_file_name text, v_object_count integer, v_cell_count numeric, v_index_count integer, v_seg_iso integer, v_process_code text) OWNER TO vizadmin;

--
-- Name: insert_mesh(integer, text, text, integer, integer, integer, double precision, text, text); Type: FUNCTION; Schema: public; Owner: vizadmin
--

CREATE FUNCTION insert_mesh(v_frame_id integer, v_directory text, v_file_name text, v_object_count integer, v_cell_count integer, v_index_count integer, v_seg_iso double precision, v_process_code text, v_mesh_code text) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	insert into mesh values(v_frame_id, v_directory, v_file_name, v_object_count, v_cell_count, v_index_count,
		v_seg_iso, v_process_code, v_mesh_code);

	update mesh_queue set status = 'complete', end_time = now() where frame_id = V_frame_id;
end;
$$;


ALTER FUNCTION public.insert_mesh(v_frame_id integer, v_directory text, v_file_name text, v_object_count integer, v_cell_count integer, v_index_count integer, v_seg_iso double precision, v_process_code text, v_mesh_code text) OWNER TO vizadmin;

--
-- Name: insert_segmentation(integer, double precision, text, integer, integer, integer, text); Type: FUNCTION; Schema: public; Owner: vizadmin
--

CREATE FUNCTION insert_segmentation(v_frame_id integer, v_seg_value double precision, v_file_name text, v_object_count integer, v_cell_count integer, v_index_count integer, v_status text) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
	updateCount integer;
begin

	insert into log values(v_frame_id, v_seg_value);

	update segmentation set file_name = v_file_name, object_count = v_object_count,
		cell_count = v_cell_count, index_count = v_index_count, status = v_status,
		end_time = now(), priority = 0
		where frame_id = v_frame_id
		and seg_value = v_seg_value;

	get diagnostics updateCount = row_count;

	if updateCount = 0 then
		perform send_message(v_frame_id, v_seg_value, 'completion failed');
	else
		perform send_message(v_frame_id, v_seg_value, 'complete');
	end if;

end;
$$;


ALTER FUNCTION public.insert_segmentation(v_frame_id integer, v_seg_value double precision, v_file_name text, v_object_count integer, v_cell_count integer, v_index_count integer, v_status text) OWNER TO vizadmin;

--
-- Name: next_mesh(text); Type: FUNCTION; Schema: public; Owner: vizadmin
--

CREATE FUNCTION next_mesh(v_worker text, OUT v_frame integer, OUT v_directory text, OUT v_file_name text, OUT v_width integer, OUT v_height integer, OUT v_depth integer) RETURNS record
    LANGUAGE plpgsql
    AS $$
declare
	fid integer;
begin
	update mesh_queue set status = 'processing', start_time = now(), worker = v_worker
	where frame_id = (
		select frame_id from mesh_queue where status = 'new'
		order by directory, file_name limit 1 for update
	)
	returning frame_id into fid;

	select id, directory, pixel_file_name, width, height, depth
	into v_frame, v_directory, v_file_name, v_width, v_height, v_depth
	from frame where id = fid;
end;
$$;


ALTER FUNCTION public.next_mesh(v_worker text, OUT v_frame integer, OUT v_directory text, OUT v_file_name text, OUT v_width integer, OUT v_height integer, OUT v_depth integer) OWNER TO vizadmin;

--
-- Name: next_mesh_job(); Type: FUNCTION; Schema: public; Owner: vizadmin
--

CREATE FUNCTION next_mesh_job(OUT frame_id integer, OUT directory text, OUT file_name text) RETURNS record
    LANGUAGE sql
    AS $$
	select id, directory, file_name from frame limit 1
$$;


ALTER FUNCTION public.next_mesh_job(OUT frame_id integer, OUT directory text, OUT file_name text) OWNER TO vizadmin;

--
-- Name: next_segmentation(text); Type: FUNCTION; Schema: public; Owner: vizadmin
--

CREATE FUNCTION next_segmentation(v_worker text, OUT v_frame integer, OUT v_seg_value double precision, OUT v_directory text, OUT v_file_name text, OUT v_width integer, OUT v_height integer, OUT v_depth integer) RETURNS record
    LANGUAGE plpgsql
    AS $$
declare
	fid integer;
	sVal double precision;
	updateCount integer;
begin
	update segmentation set status = 'processing', start_time = now(), worker = v_worker
	where (frame_id, seg_value) = (
		select frame_id, seg_value from segmentation where status = 'queued' 
		order by priority desc, file_name limit 1 for update
	)
	returning frame_id, seg_value into fid, sVal;

	select s.frame_id, s.seg_value, f.directory, f.pixel_file_name, f.width, f.height, f.depth
	into v_frame, v_seg_value, v_directory, v_file_name, v_width, v_height, v_depth
	from segmentation as s, frame as f where
		s.frame_id = fid and
		s.seg_value = sVal and
		s.frame_id = f.id;

	get diagnostics updateCount = row_count;

	if updateCount = 1 then
		perform send_message(fid, sVal, 'processing');
	end if;
end;
$$;


ALTER FUNCTION public.next_segmentation(v_worker text, OUT v_frame integer, OUT v_seg_value double precision, OUT v_directory text, OUT v_file_name text, OUT v_width integer, OUT v_height integer, OUT v_depth integer) OWNER TO vizadmin;

--
-- Name: send_message(integer, double precision, text); Type: FUNCTION; Schema: public; Owner: vizadmin
--

CREATE FUNCTION send_message(v_frame_id integer, v_seg_iso double precision, v_status text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
declare
	v_json jsonb;
begin
	select to_jsonb(v_row) into v_json 
	from (select s.status, s.frame_seq, s.file_name, f.directory, f.channel, m.channel_id
		from frame f
		join monitor_work m on (f.directory = m.directory and f.channel = m.channel)
		left join segmentation s on (f.id = s.frame_id)
		where f.id = v_frame_id
	) as v_row;
	perform pg_notify('proc_status', v_json::text);
	return v_json;
end
$$;


ALTER FUNCTION public.send_message(v_frame_id integer, v_seg_iso double precision, v_status text) OWNER TO vizadmin;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: file_list; Type: TABLE; Schema: public; Owner: vizadmin
--

CREATE TABLE file_list (
    directory text NOT NULL,
    file_name text NOT NULL,
    status text NOT NULL,
    worker text,
    start_time timestamp with time zone,
    end_time timestamp with time zone
);


ALTER TABLE file_list OWNER TO vizadmin;

--
-- Name: frame; Type: TABLE; Schema: public; Owner: vizadmin
--

CREATE TABLE frame (
    id integer NOT NULL,
    directory text NOT NULL,
    file_name text NOT NULL,
    channel integer NOT NULL,
    parent integer,
    operation text NOT NULL,
    min real NOT NULL,
    max real NOT NULL,
    mean real NOT NULL,
    median real NOT NULL,
    bins integer,
    histogram integer[],
    width integer NOT NULL,
    height integer NOT NULL,
    depth integer NOT NULL,
    pixel_type text NOT NULL,
    msec integer,
    channel_type text,
    std_dev real,
    pixel_file_name text
);


ALTER TABLE frame OWNER TO vizadmin;

--
-- Name: frame_id_seq; Type: SEQUENCE; Schema: public; Owner: vizadmin
--

CREATE SEQUENCE frame_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE frame_id_seq OWNER TO vizadmin;

--
-- Name: frame_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vizadmin
--

ALTER SEQUENCE frame_id_seq OWNED BY frame.id;


--
-- Name: frame_summary; Type: VIEW; Schema: public; Owner: vizadmin
--

CREATE VIEW frame_summary AS
 SELECT frame.directory,
    frame.channel_type,
    max(frame.width) AS w,
    max(frame.height) AS h,
    max(frame.depth) AS d,
    count(*) AS frames
   FROM frame
  WHERE (frame.operation ~~ 'con%'::text)
  GROUP BY frame.directory, frame.channel_type
  ORDER BY (count(*)), frame.directory, frame.channel_type;


ALTER TABLE frame_summary OWNER TO vizadmin;

--
-- Name: log; Type: TABLE; Schema: public; Owner: vizadmin
--

CREATE TABLE log (
    id integer,
    seg double precision,
    description text
);


ALTER TABLE log OWNER TO vizadmin;

--
-- Name: mesh; Type: TABLE; Schema: public; Owner: vizadmin
--

CREATE TABLE mesh (
    frame_id integer,
    directory text,
    file_name text,
    object_count integer,
    cell_count integer,
    index_count integer,
    seg_iso double precision,
    process_code text,
    mesh_code text
);


ALTER TABLE mesh OWNER TO vizadmin;

--
-- Name: mesh_queue; Type: TABLE; Schema: public; Owner: vizadmin
--

CREATE TABLE mesh_queue (
    frame_id integer,
    status text,
    worker text,
    start_time timestamp without time zone,
    end_time timestamp without time zone,
    directory text,
    file_name text
);


ALTER TABLE mesh_queue OWNER TO vizadmin;

--
-- Name: monitor_work; Type: TABLE; Schema: public; Owner: vizadmin
--

CREATE TABLE monitor_work (
    directory text NOT NULL,
    channel integer NOT NULL,
    seg_iso double precision NOT NULL,
    channel_id uuid DEFAULT gen_random_uuid()
);


ALTER TABLE monitor_work OWNER TO vizadmin;

--
-- Name: neo_seg_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW neo_seg_view AS
 SELECT f.directory,
    f.channel,
    f.channel_type,
    s.seg_value,
    count(*) AS count
   FROM frame f,
    ( SELECT '90210'::numeric AS seg_value) s
  WHERE (f.operation = 'convert to byte'::text)
  GROUP BY f.directory, f.channel, f.channel_type, s.seg_value
  ORDER BY f.directory, f.channel;


ALTER TABLE neo_seg_view OWNER TO postgres;

--
-- Name: segmentation; Type: TABLE; Schema: public; Owner: vizadmin
--

CREATE TABLE segmentation (
    frame_seq integer,
    frame_id integer NOT NULL,
    priority integer,
    status text,
    worker text,
    seg_value double precision NOT NULL,
    object_count integer,
    cell_count integer,
    index_count integer,
    file_name text,
    start_time timestamp without time zone,
    end_time timestamp without time zone
);


ALTER TABLE segmentation OWNER TO vizadmin;

--
-- Name: seg_view; Type: VIEW; Schema: public; Owner: vizadmin
--

CREATE VIEW seg_view AS
 SELECT f.directory,
    f.channel,
    f.channel_type,
    s.seg_value,
    count(*) AS count
   FROM (frame f
     LEFT JOIN segmentation s ON ((f.id = s.frame_id)))
  WHERE (f.operation = 'convert to byte'::text)
  GROUP BY f.directory, f.channel, f.channel_type, s.seg_value
  ORDER BY f.directory, f.channel;


ALTER TABLE seg_view OWNER TO vizadmin;

--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vizadmin
--

ALTER TABLE ONLY frame ALTER COLUMN id SET DEFAULT nextval('frame_id_seq'::regclass);


--
-- Name: file_list_pkey; Type: CONSTRAINT; Schema: public; Owner: vizadmin
--

ALTER TABLE ONLY file_list
    ADD CONSTRAINT file_list_pkey PRIMARY KEY (directory, file_name);


--
-- Name: frame_pkey; Type: CONSTRAINT; Schema: public; Owner: vizadmin
--

ALTER TABLE ONLY frame
    ADD CONSTRAINT frame_pkey PRIMARY KEY (id);


--
-- Name: segmentation_pkey; Type: CONSTRAINT; Schema: public; Owner: vizadmin
--

ALTER TABLE ONLY segmentation
    ADD CONSTRAINT segmentation_pkey PRIMARY KEY (frame_id, seg_value);


--
-- Name: file_list_idx; Type: INDEX; Schema: public; Owner: vizadmin
--

CREATE UNIQUE INDEX file_list_idx ON file_list USING btree (directory, file_name);


--
-- Name: frame_1_idx; Type: INDEX; Schema: public; Owner: vizadmin
--

CREATE INDEX frame_1_idx ON frame USING btree (directory, operation);


--
-- Name: frame_2_idx; Type: INDEX; Schema: public; Owner: vizadmin
--

CREATE INDEX frame_2_idx ON frame USING btree (operation);


--
-- Name: frame_directory_file_name_operation_idx; Type: INDEX; Schema: public; Owner: vizadmin
--

CREATE UNIQUE INDEX frame_directory_file_name_operation_idx ON frame USING btree (directory, file_name, operation);


--
-- Name: frame_id_idx; Type: INDEX; Schema: public; Owner: vizadmin
--

CREATE UNIQUE INDEX frame_id_idx ON mesh_queue USING btree (frame_id);


--
-- Name: monitor_idx; Type: INDEX; Schema: public; Owner: vizadmin
--

CREATE UNIQUE INDEX monitor_idx ON monitor_work USING btree (directory, channel, seg_iso);


--
-- Name: name_order_idx; Type: INDEX; Schema: public; Owner: vizadmin
--

CREATE INDEX name_order_idx ON mesh_queue USING btree (directory, file_name);


--
-- Name: segmentation_frame_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vizadmin
--

ALTER TABLE ONLY segmentation
    ADD CONSTRAINT segmentation_frame_id_fkey FOREIGN KEY (frame_id) REFERENCES frame(id);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

