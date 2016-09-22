--
-- Copyright (C) 2015 Glyptodon LLC
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--

--
-- Connection group types
--

CREATE EXTENSION pgcrypto;


CREATE TYPE guacamole_connection_group_type AS ENUM(
    'ORGANIZATIONAL',
    'BALANCING'
);

--
-- Object permission types
--

CREATE TYPE guacamole_object_permission_type AS ENUM(
    'READ',
    'UPDATE',
    'DELETE',
    'ADMINISTER'
);

--
-- System permission types
--

CREATE TYPE guacamole_system_permission_type AS ENUM(
    'CREATE_CONNECTION',
    'CREATE_CONNECTION_GROUP',
    'CREATE_USER',
    'ADMINISTER'
);

--
-- Table of connection groups. Each connection group has a name.
--

CREATE TABLE guacamole_connection_group (

  connection_group_id   serial       NOT NULL,
  parent_id             integer,
  connection_group_name varchar(128) NOT NULL,
  type                  guacamole_connection_group_type
                        NOT NULL DEFAULT 'ORGANIZATIONAL',

  -- Concurrency limits
  max_connections          integer,
  max_connections_per_user integer,

  PRIMARY KEY (connection_group_id),

  CONSTRAINT connection_group_name_parent
    UNIQUE (connection_group_name, parent_id),

  CONSTRAINT guacamole_connection_group_ibfk_1
    FOREIGN KEY (parent_id)
    REFERENCES guacamole_connection_group (connection_group_id)
    ON DELETE CASCADE

);

CREATE INDEX ON guacamole_connection_group(parent_id);

--
-- Table of connections. Each connection has a name, protocol, and
-- associated set of parameters.
-- A connection may belong to a connection group.
--

CREATE TABLE guacamole_connection (

  connection_id       serial       NOT NULL,
  connection_name     varchar(128) NOT NULL,
  parent_id           integer,
  protocol            varchar(32)  NOT NULL,
  
  -- Concurrency limits
  max_connections          integer,
  max_connections_per_user integer,

  PRIMARY KEY (connection_id),

  CONSTRAINT connection_name_parent
    UNIQUE (connection_name, parent_id),

  CONSTRAINT guacamole_connection_ibfk_1
    FOREIGN KEY (parent_id)
    REFERENCES guacamole_connection_group (connection_group_id)
    ON DELETE CASCADE

);

CREATE INDEX ON guacamole_connection(parent_id);

--
-- Table of users. Each user has a unique username and a hashed password
-- with corresponding salt. Although the authentication system will always set
-- salted passwords, other systems may set unsalted passwords by simply not
-- providing the salt.
--

CREATE TABLE guacamole_user (

  user_id       serial       NOT NULL,

  -- Username and optionally-salted password
  username      varchar(128) NOT NULL,
  password_hash bytea        NOT NULL,
  password_salt bytea,

  -- Account disabled/expired status
  disabled      boolean      NOT NULL DEFAULT FALSE,
  expired       boolean      NOT NULL DEFAULT FALSE,

  -- Time-based access restriction
  access_window_start    time,
  access_window_end      time,

  -- Date-based access restriction
  valid_from  date,
  valid_until date,

  -- Timezone used for all date/time comparisons and interpretation
  timezone varchar(64),

  PRIMARY KEY (user_id),

  CONSTRAINT username
    UNIQUE (username)

);

--
-- Table of connection parameters. Each parameter is simply a name/value pair
-- associated with a connection.
--

CREATE TABLE guacamole_connection_parameter (

  connection_id   integer       NOT NULL,
  parameter_name  varchar(128)  NOT NULL,
  parameter_value varchar(4096) NOT NULL,

  PRIMARY KEY (connection_id,parameter_name),

  CONSTRAINT guacamole_connection_parameter_ibfk_1
    FOREIGN KEY (connection_id)
    REFERENCES guacamole_connection (connection_id) ON DELETE CASCADE

);

CREATE INDEX ON guacamole_connection_parameter(connection_id);

--
-- Table of connection permissions. Each connection permission grants a user
-- specific access to a connection.
--

CREATE TABLE guacamole_connection_permission (

  user_id       integer NOT NULL,
  connection_id integer NOT NULL,
  permission    guacamole_object_permission_type NOT NULL,

  PRIMARY KEY (user_id,connection_id,permission),

  CONSTRAINT guacamole_connection_permission_ibfk_1
    FOREIGN KEY (connection_id)
    REFERENCES guacamole_connection (connection_id) ON DELETE CASCADE,

  CONSTRAINT guacamole_connection_permission_ibfk_2
    FOREIGN KEY (user_id)
    REFERENCES guacamole_user (user_id) ON DELETE CASCADE

);

CREATE INDEX ON guacamole_connection_permission(connection_id);
CREATE INDEX ON guacamole_connection_permission(user_id);

--
-- Table of connection group permissions. Each group permission grants a user
-- specific access to a connection group.
--

CREATE TABLE guacamole_connection_group_permission (

  user_id             integer NOT NULL,
  connection_group_id integer NOT NULL,
  permission          guacamole_object_permission_type NOT NULL,

  PRIMARY KEY (user_id,connection_group_id,permission),

  CONSTRAINT guacamole_connection_group_permission_ibfk_1
    FOREIGN KEY (connection_group_id)
    REFERENCES guacamole_connection_group (connection_group_id) ON DELETE CASCADE,

  CONSTRAINT guacamole_connection_group_permission_ibfk_2
    FOREIGN KEY (user_id)
    REFERENCES guacamole_user (user_id) ON DELETE CASCADE

);

CREATE INDEX ON guacamole_connection_group_permission(connection_group_id);
CREATE INDEX ON guacamole_connection_group_permission(user_id);

--
-- Table of system permissions. Each system permission grants a user a
-- system-level privilege of some kind.
--

CREATE TABLE guacamole_system_permission (

  user_id    integer NOT NULL,
  permission guacamole_system_permission_type NOT NULL,

  PRIMARY KEY (user_id,permission),

  CONSTRAINT guacamole_system_permission_ibfk_1
    FOREIGN KEY (user_id)
    REFERENCES guacamole_user (user_id) ON DELETE CASCADE

);

CREATE INDEX ON guacamole_system_permission(user_id);

--
-- Table of user permissions. Each user permission grants a user access to
-- another user (the "affected" user) for a specific type of operation.
--

CREATE TABLE guacamole_user_permission (

  user_id          integer NOT NULL,
  affected_user_id integer NOT NULL,
  permission       guacamole_object_permission_type NOT NULL,

  PRIMARY KEY (user_id,affected_user_id,permission),

  CONSTRAINT guacamole_user_permission_ibfk_1
    FOREIGN KEY (affected_user_id)
    REFERENCES guacamole_user (user_id) ON DELETE CASCADE,

  CONSTRAINT guacamole_user_permission_ibfk_2
    FOREIGN KEY (user_id)
    REFERENCES guacamole_user (user_id) ON DELETE CASCADE

);

CREATE INDEX ON guacamole_user_permission(affected_user_id);
CREATE INDEX ON guacamole_user_permission(user_id);

--
-- Table of connection history records. Each record defines a specific user's
-- session, including the connection used, the start time, and the end time
-- (if any).
--

CREATE TABLE guacamole_connection_history (

  history_id    serial      NOT NULL,
  user_id       integer     NOT NULL,
  connection_id integer     NOT NULL,
  start_date    timestamptz NOT NULL,
  end_date      timestamptz DEFAULT NULL,

  PRIMARY KEY (history_id),

  CONSTRAINT guacamole_connection_history_ibfk_1
    FOREIGN KEY (user_id)
    REFERENCES guacamole_user (user_id) ON DELETE CASCADE,

  CONSTRAINT guacamole_connection_history_ibfk_2
    FOREIGN KEY (connection_id)
    REFERENCES guacamole_connection (connection_id) ON DELETE CASCADE

);

CREATE INDEX ON guacamole_connection_history(user_id);
CREATE INDEX ON guacamole_connection_history(connection_id);
CREATE INDEX ON guacamole_connection_history(start_date);
CREATE INDEX ON guacamole_connection_history(end_date);
--
-- Copyright (C) 2015 Glyptodon LLC
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--


-- Create default user "guacadmin" with password "guacadmin"
INSERT INTO guacamole_user (username, password_hash, password_salt)
VALUES ('guacadmin',
    E'\\xCA458A7D494E3BE824F5E1E175A1556C0F8EEF2C2D7DF3633BEC4A29C4411960',  -- 'guacadmin'
    E'\\xFE24ADC5E11E2B25288D1704ABE67A79E342ECC26064CE69C5B3177795A82264');

-- Grant this user all system permissions
INSERT INTO guacamole_system_permission
SELECT user_id, permission::guacamole_system_permission_type
FROM (
    VALUES
        ('guacadmin', 'CREATE_CONNECTION'),
        ('guacadmin', 'CREATE_CONNECTION_GROUP'),
        ('guacadmin', 'CREATE_USER'),
        ('guacadmin', 'ADMINISTER')
) permissions (username, permission)
JOIN guacamole_user ON permissions.username = guacamole_user.username;

-- Grant admin permission to read/update/administer self
INSERT INTO guacamole_user_permission
SELECT guacamole_user.user_id, affected.user_id, permission::guacamole_object_permission_type
FROM (
    VALUES
        ('guacadmin', 'guacadmin', 'READ'),
        ('guacadmin', 'guacadmin', 'UPDATE'),
        ('guacadmin', 'guacadmin', 'ADMINISTER')
) permissions (username, affected_username, permission)
JOIN guacamole_user          ON permissions.username = guacamole_user.username
JOIN guacamole_user affected ON permissions.affected_username = affected.username;

--=================================================================================
-- COMPUTERS
--=================================================================================

-----------------------------------------------------------------------------------
-- WINDOWSMACHINE
-- Let's add a connection
INSERT INTO guacamole_connection (connection_name, protocol) VALUES ('WindowsMachine', 'rdp');

-- Set up the settings for machine we just added
INSERT INTO guacamole_connection_parameter VALUES (
	(SELECT connection_id FROM guacamole_connection WHERE connection_name = 'WindowsMachine' AND parent_id IS NULL)
	, 'username', 'atumsoft');
INSERT INTO guacamole_connection_parameter VALUES (
	(SELECT connection_id FROM guacamole_connection WHERE connection_name = 'WindowsMachine' AND parent_id IS NULL)
	, 'password', 'pean51');
INSERT INTO guacamole_connection_parameter VALUES (
	(SELECT connection_id FROM guacamole_connection WHERE connection_name = 'WindowsMachine' AND parent_id IS NULL)
	, 'hostname', 'atumsoft.ftp.sh');
INSERT INTO guacamole_connection_parameter VALUES (
	(SELECT connection_id FROM guacamole_connection WHERE connection_name = 'WindowsMachine' AND parent_id IS NULL)
	, 'port', '13389');
INSERT INTO guacamole_connection_parameter VALUES (
	(SELECT connection_id FROM guacamole_connection WHERE connection_name = 'WindowsMachine' AND parent_id IS NULL)
	, 'security', 'nla');
INSERT INTO guacamole_connection_parameter VALUES (
	(SELECT connection_id FROM guacamole_connection WHERE connection_name = 'WindowsMachine' AND parent_id IS NULL)
	, 'ignore-cert', 'true');
-----------------------------------------------------------------------------------

-----------------------------------------------------------------------------------
-- LINUXMACHINE
-- Let's add a connection
INSERT INTO guacamole_connection (connection_name, protocol) VALUES ('LinuxMachine', 'rdp');

-- Set up the settings for machine we just added
INSERT INTO guacamole_connection_parameter VALUES (
	(SELECT connection_id FROM guacamole_connection WHERE connection_name = 'LinuxMachine' AND parent_id IS NULL)
	, 'username', 'atumsoft');
INSERT INTO guacamole_connection_parameter VALUES (
	(SELECT connection_id FROM guacamole_connection WHERE connection_name = 'LinuxMachine' AND parent_id IS NULL)
	, 'password', 'pean51');
INSERT INTO guacamole_connection_parameter VALUES (
	(SELECT connection_id FROM guacamole_connection WHERE connection_name = 'LinuxMachine' AND parent_id IS NULL)
	, 'hostname', 'atumsoft.ftp.sh');
INSERT INTO guacamole_connection_parameter VALUES (
	(SELECT connection_id FROM guacamole_connection WHERE connection_name = 'LinuxMachine' AND parent_id IS NULL)
	, 'port', '23389');
-----------------------------------------------------------------------------------

-----------------------------------------------------------------------------------
-- LINUXMACHINE2
-- Let's add a connection
INSERT INTO guacamole_connection (connection_name, protocol) VALUES ('LinuxMachine2', 'rdp');

-- Set up the settings for machine we just added
INSERT INTO guacamole_connection_parameter VALUES (
	(SELECT connection_id FROM guacamole_connection WHERE connection_name = 'LinuxMachine2' AND parent_id IS NULL)
	, 'username', 'atumsoft');
INSERT INTO guacamole_connection_parameter VALUES (
	(SELECT connection_id FROM guacamole_connection WHERE connection_name = 'LinuxMachine2' AND parent_id IS NULL)
	, 'password', 'pean51');
INSERT INTO guacamole_connection_parameter VALUES (
	(SELECT connection_id FROM guacamole_connection WHERE connection_name = 'LinuxMachine2' AND parent_id IS NULL)
	, 'hostname', 'atumsoft.ftp.sh');
INSERT INTO guacamole_connection_parameter VALUES (
	(SELECT connection_id FROM guacamole_connection WHERE connection_name = 'LinuxMachine2' AND parent_id IS NULL)
	, 'port', '23389');
-----------------------------------------------------------------------------------

--=================================================================================
-- USERS
--=================================================================================

-----------------------------------------------------------------------------------
-- atumate
-- Create user and hash password with salt
INSERT INTO guacamole_user (username, password_hash, password_salt)
     VALUES ('atumate', digest('atumate'||'D67C5CBF5B01C9F91932E3B8DEF5E5F8','sha256'), E'\\xD67C5CBF5B01C9F91932E3B8DEF5E5F8');

-- Grant our user permission to an added machine 
INSERT INTO guacamole_connection_permission VALUES (
  (SELECT user_id FROM guacamole_user WHERE username = 'atumate'), 
  (SELECT connection_id FROM guacamole_connection WHERE connection_name = 'WindowsMachine' AND parent_id IS NULL), 
  'READ');
INSERT INTO guacamole_connection_permission VALUES (
  (SELECT user_id FROM guacamole_user WHERE username = 'atumate'), 
  (SELECT connection_id FROM guacamole_connection WHERE connection_name = 'LinuxMachine' AND parent_id IS NULL), 
  'READ');
INSERT INTO guacamole_connection_permission VALUES (
  (SELECT user_id FROM guacamole_user WHERE username = 'atumate'), 
  (SELECT connection_id FROM guacamole_connection WHERE connection_name = 'LinuxMachine2' AND parent_id IS NULL), 
  'READ');
-----------------------------------------------------------------------------------

-----------------------------------------------------------------------------------
-- ADARE
-- Create user and hash password with salt
INSERT INTO guacamole_user (username, password_hash, password_salt)
     VALUES ('adare', digest('adare'||'D67C5CBF5B01C9F91932E3B8DEF5E5F8','sha256'), E'\\xD67C5CBF5B01C9F91932E3B8DEF5E5F8');

-- Grant our user permission to an added machine 
INSERT INTO guacamole_connection_permission VALUES (
  (SELECT user_id FROM guacamole_user WHERE username = 'adare'), 
  (SELECT connection_id FROM guacamole_connection WHERE connection_name = 'WindowsMachine' AND parent_id IS NULL), 
  'READ');
INSERT INTO guacamole_connection_permission VALUES (
  (SELECT user_id FROM guacamole_user WHERE username = 'adare'), 
  (SELECT connection_id FROM guacamole_connection WHERE connection_name = 'LinuxMachine' AND parent_id IS NULL), 
  'READ');
INSERT INTO guacamole_connection_permission VALUES (
  (SELECT user_id FROM guacamole_user WHERE username = 'adare'), 
  (SELECT connection_id FROM guacamole_connection WHERE connection_name = 'LinuxMachine2' AND parent_id IS NULL), 
  'READ');
-----------------------------------------------------------------------------------
