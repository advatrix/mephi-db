-- postgres

CREATE TABLE pricelist_category (
	id serial NOT NULL PRIMARY KEY,
	description varchar(255) NULL
);

CREATE TABLE pricelist (
	id serial NOT NULL PRIMARY KEY,
	category_id int NOT NULL REFERENCES pricelist_category ON DELETE RESTRICT,
	created date NOT NULL DEFAULT current_date,
	UNIQUE (category_id, created)
);

CREATE TABLE good (
	id serial NOT NULL PRIMARY KEY,
	"name" varchar(255) NOT NULL UNIQUE,
	quantity int NOT NULL CHECK (quantity >= 0)
);

CREATE TABLE customer (
	id serial NOT NULL PRIMARY KEY,
	pricelist_category_id int NOT NULL REFERENCES pricelist_category ON DELETE RESTRICT, 
	registered date NOT NULL DEFAULT current_date,
	"type" char NOT NULL CHECK ("type" IN ('l', 'p')),
	code int NOT NULL UNIQUE
);

CREATE TABLE person (
	id int NOT NULL PRIMARY KEY REFERENCES customer ON DELETE CASCADE,
	first_name varchar(50) NOT NULL,
	second_name varchar(50) NULL,
	last_name varchar(50) NOT NULL,
	passport int NOT NULL UNIQUE
);

CREATE TABLE legal (
	id int NOT NULL PRIMARY KEY REFERENCES customer ON DELETE CASCADE,
	inn int NOT NULL UNIQUE,
	"name" varchar(256) NOT NULL UNIQUE,
	payment_account int NOT NULL UNIQUE
);

CREATE TABLE pricelist_item (
	good_id int NOT NULL REFERENCES good ON DELETE RESTRICT,
	pricelist_id int NOT NULL REFERENCES pricelist ON DELETE RESTRICT,
	price decimal(8, 2) CHECK (price > 0),
	PRIMARY KEY (good_id, pricelist_id)
);

CREATE TABLE consignment_note (
	id serial NOT NULL PRIMARY KEY,
	customer_id int NOT NULL REFERENCES customer ON DELETE CASCADE,
	pricelist_id int NOT NULL REFERENCES pricelist ON DELETE RESTRICT,
	created timestamp NOT NULL DEFAULT current_timestamp,
	paid timestamp NULL CHECK (paid >= created),
	payment_document_id int NULL
);

CREATE TABLE consignment_note_item (
	consignment_note_id int NOT NULL REFERENCES consignment_note ON DELETE CASCADE,
	good_id int NOT NULL REFERENCES good ON DELETE RESTRICT,
	pricelist_id int NOT NULL REFERENCES pricelist ON DELETE RESTRICT,
	ordered int NOT NULL CHECK (ordered > 0),
	reserved int NOT NULL CHECK (reserved >= 0) default 0,
	released timestamp NULL,
	PRIMARY KEY (consignment_note_id, good_id, pricelist_id)
);

CREATE TABLE payment_document (
	id serial NOT NULL PRIMARY KEY,
	consignment_note_id int NOT NULL REFERENCES consignment_note ON DELETE CASCADE,
	payment DECIMAL(8, 2) CHECK (payment > 0),
	created timestamp NOT NULL DEFAULT current_timestamp
);

ALTER TABLE consignment_note
	ADD FOREIGN KEY (payment_document_id) REFERENCES payment_document ON DELETE RESTRICT;

