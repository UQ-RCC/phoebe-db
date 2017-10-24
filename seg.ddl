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

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: segmentation; Type: TABLE; Schema: public; Owner: phoebeadmin
--

CREATE TABLE segmentation (
    id bigint NOT NULL,
    frame_id bigint,
    seg_value double precision,
    status text
);


ALTER TABLE segmentation OWNER TO phoebeadmin;

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

ALTER TABLE ONLY segmentation ALTER COLUMN id SET DEFAULT nextval('segmentation_id_seq'::regclass);


--
-- Name: segmentation_pkey; Type: CONSTRAINT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY segmentation
    ADD CONSTRAINT segmentation_pkey PRIMARY KEY (id);


--
-- Name: segmentation_frame_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: phoebeadmin
--

ALTER TABLE ONLY segmentation
    ADD CONSTRAINT segmentation_frame_id_fkey FOREIGN KEY (frame_id) REFERENCES image_frame(id);


--
-- PostgreSQL database dump complete
--

