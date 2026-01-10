--
-- PostgreSQL database dump
--

\restrict pysjAmkdMZkoZh4gxeKJc9YAHpL1Uj7s646xZY2atPvcHAuRhYItrvbUXT6DTXY

-- Dumped from database version 16.11
-- Dumped by pg_dump version 16.11

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: alembic_version; Type: TABLE DATA; Schema: public; Owner: mpalys
--

INSERT INTO public.alembic_version VALUES ('0001_init');


--
-- Data for Name: audit_logs; Type: TABLE DATA; Schema: public; Owner: mpalys
--

INSERT INTO public.audit_logs VALUES (1, '2025-12-28 09:31:05.601991+00', 1, 'POST', '/api/items', 200, '192.168.65.1');
INSERT INTO public.audit_logs VALUES (2, '2025-12-28 12:46:03.516936+00', 1, 'POST', '/api/items', 200, '192.168.65.1');
INSERT INTO public.audit_logs VALUES (3, '2025-12-28 12:47:19.745916+00', 1, 'DELETE', '/api/items/2', 200, '192.168.65.1');
INSERT INTO public.audit_logs VALUES (4, '2025-12-28 12:47:30.190663+00', 1, 'POST', '/api/items', 200, '192.168.65.1');
INSERT INTO public.audit_logs VALUES (5, '2025-12-29 06:30:39.540107+00', 1, 'POST', '/api/items', 200, '192.168.65.1');
INSERT INTO public.audit_logs VALUES (6, '2025-12-29 06:30:45.186429+00', 1, 'DELETE', '/api/items/4', 200, '192.168.65.1');
INSERT INTO public.audit_logs VALUES (7, '2026-01-05 22:37:12.900487+00', 1, 'DELETE', '/api/items/3', 200, '192.168.65.1');
INSERT INTO public.audit_logs VALUES (8, '2026-01-05 22:37:13.066122+00', 1, 'DELETE', '/api/items/1', 200, '192.168.65.1');


--
-- Data for Name: items; Type: TABLE DATA; Schema: public; Owner: mpalys
--



--
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: mpalys
--

INSERT INTO public.roles VALUES (1, 'admin');
INSERT INTO public.roles VALUES (2, 'editor');
INSERT INTO public.roles VALUES (3, 'viewer');


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: mpalys
--

INSERT INTO public.users VALUES (1, 'admin@example.com', 'Admin', '$argon2id$v=19$m=65536,t=3,p=4$fs9ZCwEAgNA6J0ToXWuN0Q$Tq3atMvuUHui4vyILu2urq5yvJygJBYuwAlLaLrMisc', true, '2025-12-28 09:09:48.430712+00');


--
-- Data for Name: user_roles; Type: TABLE DATA; Schema: public; Owner: mpalys
--

INSERT INTO public.user_roles VALUES (1, 1);


--
-- Name: audit_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mpalys
--

SELECT pg_catalog.setval('public.audit_logs_id_seq', 8, true);


--
-- Name: items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mpalys
--

SELECT pg_catalog.setval('public.items_id_seq', 4, true);


--
-- Name: roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mpalys
--

SELECT pg_catalog.setval('public.roles_id_seq', 3, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mpalys
--

SELECT pg_catalog.setval('public.users_id_seq', 1, true);


--
-- PostgreSQL database dump complete
--

\unrestrict pysjAmkdMZkoZh4gxeKJc9YAHpL1Uj7s646xZY2atPvcHAuRhYItrvbUXT6DTXY

