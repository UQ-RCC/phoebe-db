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

SET search_path = public, pg_catalog;

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
-- Name: image_view; Type: ACL; Schema: public; Owner: phoebeadmin
--

REVOKE ALL ON TABLE image_view FROM PUBLIC;
REVOKE ALL ON TABLE image_view FROM phoebeadmin;
GRANT ALL ON TABLE image_view TO phoebeadmin;
GRANT SELECT ON TABLE image_view TO dataimport;


--
-- PostgreSQL database dump complete
--

