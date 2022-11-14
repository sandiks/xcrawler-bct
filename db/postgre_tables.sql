create user btuser with password 'test123';

GRANT ALL PRIVILEGES ON DATABASE "bittalk" to btuser;

GRANT ALL ON ALL TABLES IN SCHEMA "public" TO btuser;

CREATE TABLE forums (
  fid  integer PRIMARY KEY,
  "name" VARCHAR(255),
  "level" integer,
  parent_fid integer,
  title VARCHAR(255),
  "check" integer,
  bot_updated TIMESTAMP,
  descr VARCHAR(255)
);


CREATE TABLE threads  (
 tid integer NOT NULL,
 fid integer NOT NULL,
 title varchar(200) NOT NULL,
 created timestamp DEFAULT NULL,
 updated timestamp DEFAULT NULL,
 viewers integer DEFAULT NULL,
 responses integer DEFAULT NULL,
 descr varchar(100) DEFAULT NULL,
 bot_updated timestamp DEFAULT NULL,
 bot_tracked integer DEFAULT NULL,
 last_viewed timestamp DEFAULT NULL,
 reliable float DEFAULT NULL,
PRIMARY KEY ( tid , fid )
);

CREATE TABLE  tpages  (
   tid  integer NOT NULL,
   page  integer NOT NULL,
   postcount  integer DEFAULT NULL,
   fp_date  timestamp DEFAULT NULL,
  PRIMARY KEY ( tid , page )
);

CREATE TABLE  threads_responses  (
   fid  integer NOT NULL,
   tid  integer NOT NULL,
   responses  integer DEFAULT NULL,
   last_post_date  timestamp NOT NULL,
   parsed_at  timestamp DEFAULT NULL,
   day  integer DEFAULT NULL,
   hour  integer DEFAULT NULL,
  PRIMARY KEY ( tid , last_post_date   )
);

--ALTER TABLE forums_stat  ALTER COLUMN Id DROP DEFAULT;
CREATE TABLE  forums_stat  (
   fid  integer DEFAULT NULL,
   bot_action  varchar(100) DEFAULT NULL,
   bot_parsed  TIMESTAMP DEFAULT NULL,
   Id  serial,
  PRIMARY KEY ( Id )
);

CREATE TABLE  users  (
   name  varchar(50) NOT NULL,
   uid  integer  NOT NULL DEFAULT 0,
   rank  integer DEFAULT NULL,
   merit  integer DEFAULT NULL,
   created_at  TIMESTAMP  DEFAULT NULL,
  PRIMARY KEY ( uid )
);

CREATE TABLE  tpage_ranks  (
   tid  integer NOT NULL,
   page  integer NOT NULL,
   postcount  integer DEFAULT NULL,
   r1  integer DEFAULT 0,
   r2  integer DEFAULT 0,
   r3  integer DEFAULT 0,
   r4  integer DEFAULT 0,
   r5  integer DEFAULT 0,
   r11  integer DEFAULT 0,
   fp_date  TIMESTAMP  DEFAULT NULL,
  PRIMARY KEY ( tid , page )
);


CREATE TABLE  bct_user_bounty(
   uid  integer NOT NULL,
   bo_name  varchar(50) NOT NULL,
   created_at TIMESTAMP
);

CREATE TABLE user_merits(
   uid  integer NOT NULL,
   merit SMALLINT,
   date TIMESTAMP
);

