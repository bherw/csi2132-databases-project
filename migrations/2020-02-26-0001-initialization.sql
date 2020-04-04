-- 1 up
CREATE TYPE property_types AS ENUM(
	-- Apartment
	'Apartment', 'Condominium', 'Casa particular (Cuba)', 'Loft', 'Serviced apartment',

	-- House
	'House', 'Bungalow', 'Cabin', 'Chalet', 'Cottage', 'Cycladic house (Greece)', 'Dammuso (Italy)', 'Dome house', 'Earth house', 'Farm stay', 'Houseboat', 'Hut', 'Lighthouse', 'Pension (South Korea)', 'Shepherds Hut (U.K., France)', 'Tiny house', 'Townhouse', 'Trullo (Italy)', 'Villa',

	-- Secondary unit
'Guesthouse', 'Guest suite',

-- Unique space
'Barn', 'Boat', 'Bus', 'Camper/RV', 'Campsite', 'Castle', 'Cave', 'Igloo', 'Island', 'Plane', 'Tent', 'Teepee', 'Train', 'Treehouse', 'Windmill', 'Yurt',

-- Bed and breakfast
'Minsu (Taiwan)', 'Nature lodge', 'Ryokan (Japan)',

-- Boutique hotel
'Boutique hotel', 'Aparthotel', 'Heritage hotel (India)', 'Hostel', 'Hotel', 'Resort', 'Kezhan (China)'
);

CREATE TYPE room_types AS ENUM('Entire place', 'Private room', 'Hotel room', 'Shared room');

-- Partially specified
CREATE TYPE currency_types AS ENUM('CAD', 'USD');

CREATE TYPE amenity_types AS ENUM('Essentials', 'Air conditioning', 'Heat', 'Hair dryer', 'Closet / drawers', 'Iron', 'TV', 'Fireplace', 'Private entrance', 'Shampoo', 'Wifi', 'Desk/workspace', 'Breakfast, coffee, tea', 'Fire extinguisher', 'Carbon monoxide detector', 'Smoke detector', 'First aid kit', 'Indoor fireplace', 'Hangers', 'Crib', 'High chair', 'Self check-in', 'Private bathroom', 'Beachfront', 'Waterfront', 'Ski-in/ski-out');
CREATE TYPE facility_types AS ENUM('Free parking', 'Gym', 'Hot tub', 'Pool', 'Kitchen', 'Laundry - washer', 'Laundry - dryer');
CREATE TYPE position_types AS ENUM('staff', 'manager', 'ceo');

-- Only partially specified
CREATE TYPE accessibility_types AS ENUM('No stairs or steps to enter', 'Wide entrance for guests', 'Well-lit path to entrance', 'Step-free path to entrance');

CREATE TYPE bed_types AS ENUM('King', 'Queen', 'Double', 'Single');

-- Only partially specified
CREATE TYPE host_languages AS ENUM('English', 'German', 'French', 'Japanese');

CREATE TYPE rental_agreement_payment_statuses AS ENUM('Pending', 'Payment ongoing', 'Complete');
CREATE TYPE payment_types AS ENUM('Credit', 'Debit', 'Cash');
CREATE TYPE payment_statuses AS ENUM('Pending', 'Approved', 'Complete');
CREATE TYPE password_hash_types AS ENUM('sha512_base64');

CREATE TABLE "person" (
  "person_id" uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  "first_name" varchar(255) NOT NULL,
  "middle_name" varchar(255) NOT NULL,
  "last_name" varchar(255) NOT NULL,
  "password" varchar NOT NULL,
  "password_type" password_hash_types NOT NULL,
  "street_address" varchar,
  "city" varchar,
  "state" varchar,
  "country" varchar,
  "postal_code" varchar,
  "email" varchar NOT NULL UNIQUE,
  "is_id_verified" boolean NOT NULL DEFAULT FALSE,
  "is_address_verified" boolean NOT NULL DEFAULT FALSE,
  "is_deleted" boolean NOT NULL DEFAULT FALSE
);

CREATE TABLE "property" (
  "property_id" uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  "host_id" uuid NOT NULL,
  "title" varchar NOT NULL DEFAULT 'Untitled Listing',
  "street_address" varchar NOT NULL DEFAULT '',
  "city" varchar NOT NULL DEFAULT '',
  "state" varchar NOT NULL DEFAULT '',
  "country" varchar NOT NULL DEFAULT '',
  "postal_code" varchar NOT NULL DEFAULT '',
  "is_published" boolean NOT NULL DEFAULT FALSE,
  "is_dedicated_guest_space" boolean NOT NULL DEFAULT FALSE,
  "is_instant_book_enabled" boolean NOT NULL DEFAULT FALSE,
  "property_type" property_types NOT NULL DEFAULT 'Apartment',
  "room_type" room_types NOT NULL DEFAULT 'Entire place',
  "neighborhood" varchar NOT NULL DEFAULT '',
  "num_bathrooms" int NOT NULL DEFAULT 0,
  "num_bedrooms" int NOT NULL DEFAULT 0,
  "num_beds" int NOT NULL DEFAULT 0,
  "checkin_time_from" time,
  "checkin_time_to" time,
  "checkout_time_from" time,
  "checkout_time_to" time,
  "requires_guest_id_validation" boolean NOT NULL DEFAULT FALSE,
  "requires_guest_good_reputation" boolean NOT NULL DEFAULT FALSE,
  "summary" text NOT NULL DEFAULT '',
  "your_space" text NOT NULL DEFAULT '',
  "your_availability" text NOT NULL DEFAULT '',
  "your_neighborhood" text NOT NULL DEFAULT '',
  "getting_around" text NOT NULL DEFAULT '',
  "days_of_notice_required" int NOT NULL DEFAULT 0,
  "sameday_booking_allowed_before_time" time,

  -- null value: indefinitely allowed
  -- value: 0: all days blocked by default, must manually unblock.
  "advance_booking_allowed_for_num_months" int,

  "min_stay_length" int NOT NULL DEFAULT 1,
  "max_stay_length" int NOT NULL DEFAULT 1,
  "base_price" numeric(12,2),
  "min_price" numeric(12,2),
  "max_price" numeric(12,2),
  "currency" currency_types,
  "weekly_discount" int NOT NULL DEFAULT 0 CHECK ("weekly_discount" BETWEEN 0 AND 100),
  "monthly_discount" int NOT NULL DEFAULT 0 CHECK ("monthly_discount" BETWEEN 0 AND 100),
  "is_deleted" boolean NOT NULL DEFAULT FALSE,

  -- house rules
  "is_suitable_for_children" boolean,
  "is_suitable_for_infants" boolean,
  "is_suitable_for_pets" boolean,
  "is_smoking_allowed" boolean,
  "is_events_or_parties_allowed" boolean,

  -- Additional details
  "must_climb_stairs" text,
  "potential_for_noise" text,
  "pets_live_on_property" text,
  "no_parking_on_property" text,
  "some_spaces_are_shared" text,
  "amenity_limitations" text,
  "surveillance_on_property" text,
  "weapons_on_property" text,
  "dangerous_animals_on_property" text,

  -- Cached rating values
  location float,
  communication float,
  accuracy float,
  check_in float,
  cleanliness float,
  "value" float,
  rating float,

  FOREIGN KEY ("host_id") REFERENCES "person" ("person_id"),
  CONSTRAINT property_check_is_published_implies_setup_complete CHECK (
    NOT is_published OR (
      "street_address" <> '' AND
      "state" <> '' AND
      "country" <> '' AND
      "postal_code" <> '' AND
      "checkin_time_from" IS NOT NULL AND
      "checkin_time_to" IS NOT NULL AND
      "checkout_time_from" IS NOT NULL AND
      "checkout_time_to" IS NOT NULL AND
      "base_price" IS NOT NULL AND
      "min_price" IS NOT NULL AND
      "max_price" IS NOT NULL AND
      "currency" IS NOT NULL AND
      NOT "is_deleted"
    )
  ),
  CONSTRAINT property_check_checkin_time_gt CHECK (NOT is_published OR "checkin_time_from" <= "checkin_time_to"),
  CONSTRAINT property_check_checkout_time_gt CHECK (NOT is_published OR "checkout_time_from" <= "checkout_time_to"),
  CONSTRAINT property_check_pricing CHECK (
    NOT is_published OR (
      base_price >= min_price AND base_price <= max_price AND min_price <= max_price
    )
  ),
  CONSTRAINT property_check_stay_length CHECK (NOT is_published OR min_stay_length <= max_stay_length)
);

CREATE TABLE "property_available_date" (
  "property_id" uuid,
  "starts_at" date,
  "ends_at" date NOT NULL CHECK (ends_at >= starts_at),
  PRIMARY KEY ("property_id", "starts_at"),
  FOREIGN KEY ("property_id") REFERENCES "property" ("property_id")
);

CREATE FUNCTION check_property_available_date_non_contiguous()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT * FROM property_available_date AD1 JOIN property_available_date AD2 ON AD1.property_id=AD2.property_id WHERE AD2.starts_at != AD1.starts_at AND (AD1.ends_at + 1 = AD2.starts_at OR AD2.starts_at BETWEEN AD1.starts_at AND AD1.ends_at OR AD2.ends_at BETWEEN AD1.starts_at AND AD1.ends_at)) then
        RAISE EXCEPTION 'property availability blocks must be non-contiguous';
    END IF;
    return new;
END
$$;

CREATE TRIGGER check_property_available_date_non_contiguous_on_insert BEFORE INSERT
   ON property_available_date
   FOR EACH ROW
   EXECUTE PROCEDURE check_property_available_date_non_contiguous();

CREATE TRIGGER check_property_available_date_non_contiguous_on_update BEFORE UPDATE
   ON property_available_date
   FOR EACH ROW
   EXECUTE PROCEDURE check_property_available_date_non_contiguous();

CREATE TABLE "property_amenity" (
  "property_id" uuid,
  "amenity" amenity_types,
  PRIMARY KEY ("property_id", "amenity"),
  FOREIGN KEY ("property_id") REFERENCES "property" ("property_id")
);

CREATE TABLE "property_accessibility" (
  "property_id" uuid,
  "accessibility" accessibility_types,
  PRIMARY KEY ("property_id", "accessibility"),
  FOREIGN KEY ("property_id") REFERENCES "property" ("property_id")
);

CREATE TABLE "property_bedroom" (
  "property_id" uuid,
  "bedroom_number" int,
  "bed_type" bed_types,
  "num_beds" int NOT NULL,
  PRIMARY KEY ("property_id", "bedroom_number", "bed_type"),
  FOREIGN KEY ("property_id") REFERENCES "property" ("property_id")
);

CREATE TABLE "property_host_language" (
  "property_id" uuid,
  "host_language" varchar,
  PRIMARY KEY ("property_id", "host_language"),
  FOREIGN KEY ("property_id") REFERENCES "property" ("property_id")
);

CREATE TABLE "property_photo" (
  "property_id" uuid,
  "photo_filename" varchar,
  PRIMARY KEY ("property_id", "photo_filename"),
  FOREIGN KEY ("property_id") REFERENCES "property" ("property_id")
);

CREATE TABLE "property_custom_house_rule" (
  "property_id" uuid,
  "custom_house_rule" text,
  PRIMARY KEY ("property_id", "custom_house_rule"),
  FOREIGN KEY ("property_id") REFERENCES "property" ("property_id")
);

CREATE TABLE "message" (
  "message_id" uuid  DEFAULT gen_random_uuid() PRIMARY KEY,
  "property_id" uuid NOT NULL,
  "sender_id" uuid NOT NULL,
  "receiver_id" uuid NOT NULL,
  "created_at" timestamp NOT NULL DEFAULT NOW(),
  "subject" varchar NOT NULL,
  "content" text NOT NULL,
  FOREIGN KEY ("property_id") REFERENCES "property" ("property_id"),
  FOREIGN KEY ("sender_id") REFERENCES "person" ("person_id"),
  FOREIGN KEY ("receiver_id") REFERENCES "person" ("person_id")
);

CREATE TABLE "reviews" (
  "property_id" uuid,
  "person_id" uuid,
  "created_at" timestamp NOT NULL DEFAULT NOW(),
  "updated_at" timestamp NOT NULL DEFAULT NOW(),
  "location" int NOT NULL CHECK ("location" BETWEEN 1 AND 5),
  "communication" int NOT NULL CHECK ("communication" BETWEEN 1 AND 5),
  "check_in" int NOT NULL CHECK ("check_in" BETWEEN 1 AND 5),
  "accuracy" int NOT NULL CHECK ("accuracy" BETWEEN 1 AND 5),
  "cleanliness" int NOT NULL CHECK ("cleanliness" BETWEEN 1 AND 5),
  "value" int NOT NULL CHECK ("value" BETWEEN 1 AND 5),
  "comments" text NOT NULL DEFAULT '',
  PRIMARY KEY ("property_id", "person_id"),
  FOREIGN KEY ("property_id") REFERENCES "property" ("property_id"),
  FOREIGN KEY ("person_id") REFERENCES "person" ("person_id")
);

CREATE FUNCTION insert_property_review_scores()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    PERFORM update_property_review_scores_internal(NEW.property_id);
    RETURN NEW;
END;
$$;

CREATE FUNCTION update_property_review_scores()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    PERFORM update_property_review_scores_internal(OLD.property_id);
    RETURN NEW;
END;
$$;

CREATE FUNCTION update_property_review_scores_internal(review_property_id uuid)
RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
    avg_location float;
    avg_communication float;
    avg_accuracy float;
    avg_check_in float;
    avg_cleanliness float;
    avg_value float;
BEGIN
    SELECT AVG(reviews.location), AVG(reviews.communication), AVG(reviews.check_in), AVG(reviews.accuracy), AVG(reviews.cleanliness), AVG(reviews."value")
           INTO avg_location, avg_communication, avg_check_in, avg_accuracy, avg_cleanliness, avg_value
           FROM reviews
           WHERE reviews.property_id = review_property_id;
    UPDATE property SET
        location      = avg_location,
        communication = avg_communication,
        check_in      = avg_check_in,
        accuracy      = avg_accuracy,
        cleanliness   = avg_cleanliness,
        "value"       = avg_value,
        rating        = (avg_location + avg_communication + avg_check_in + avg_accuracy + avg_cleanliness + avg_value) / 6
        WHERE "property_id" = review_property_id;
END;
$$;

CREATE TRIGGER reviews_on_update
    AFTER INSERT ON reviews
    FOR EACH ROW
    EXECUTE PROCEDURE insert_property_review_scores();

CREATE TRIGGER reviews_update
    AFTER UPDATE OF location, communication, check_in, accuracy, cleanliness, "value" ON reviews
    FOR EACH ROW
    EXECUTE PROCEDURE update_property_review_scores();

CREATE TRIGGER reviews_on_delete
    AFTER DELETE ON reviews
    FOR EACH ROW
    EXECUTE PROCEDURE update_property_review_scores();


CREATE TABLE "rental_agreement" (
  "rental_id" uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  "property_id" uuid NOT NULL,
  "person_id" uuid NOT NULL,
  "signed_at" timestamp NOT NULL CHECK (signed_at <= starts_at),
  "starts_at" date NOT NULL,
  "ends_at" date NOT NULL CHECK (ends_at >= starts_at),
  "payment_status" rental_agreement_payment_statuses NOT NULL,
  "total_price" numeric(12,2) NOT NULL,
  FOREIGN KEY ("property_id") REFERENCES "property" ("property_id"),
  FOREIGN KEY ("person_id") REFERENCES "person" ("person_id")
);

CREATE TABLE "rental_requests" (
  "property_id" uuid NOT NULL,
  "person_id" uuid NOT NULL,
  "created_at" timestamp NOT NULL DEFAULT NOW(),
  "starts_at" date NOT NULL,
  "ends_at" date NOT NULL CHECK (ends_at >= starts_at),
  FOREIGN KEY ("property_id") REFERENCES "property" ("property_id"),
  FOREIGN KEY ("person_id") REFERENCES "person" ("person_id")
);

CREATE TABLE "payment" (
  "rental_id" uuid NOT NULL,
  "created_at" timestamp NOT NULL,
  "completed_at" timestamp CHECK (completed_at >= created_at),
  "type" payment_types NOT NULL,
  "amount" numeric(12,2) NOT NULL,
  "status" payment_statuses NOT NULL,
  PRIMARY KEY ("rental_id", "created_at"),
  FOREIGN KEY ("rental_id") REFERENCES "rental_agreement" ("rental_id")
);

CREATE TABLE "person_phone_number" (
  "person_id" uuid,
  "phone_number" varchar,
  PRIMARY KEY ("person_id", "phone_number"),
  FOREIGN KEY ("person_id") REFERENCES "person" ("person_id")
);

CREATE TABLE "employee" (
  "person_id" uuid PRIMARY KEY,
  "manager_id" uuid,
  "workplace" varchar NOT NULL,
  "position" position_types NOT NULL,
  "salary" numeric(12,2) NOT NULL,
  FOREIGN KEY ("person_id") REFERENCES "person" ("person_id") DEFERRABLE INITIALLY IMMEDIATE,
  FOREIGN KEY ("manager_id") REFERENCES "employee" ("person_id") DEFERRABLE INITIALLY IMMEDIATE
);

CREATE TABLE "branch" (
  "country" varchar PRIMARY KEY,
  "manager_id" uuid NOT NULL,
  FOREIGN KEY ("manager_id") REFERENCES "employee" ("person_id") DEFERRABLE INITIALLY IMMEDIATE
);

ALTER TABLE "employee" ADD FOREIGN KEY ("workplace") REFERENCES "branch" ("country") ON UPDATE CASCADE DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "property" ADD FOREIGN KEY ("country") REFERENCES "branch" ("country") ON UPDATE CASCADE;

-- 1 down
DROP TABLE IF EXISTS "employee" CASCADE;
DROP TABLE IF EXISTS "branch" CASCADE;
DROP TABLE IF EXISTS "person_phone_number" CASCADE;
DROP TABLE IF EXISTS "person" CASCADE;
DROP TABLE IF EXISTS "property" CASCADE;
DROP TABLE IF EXISTS "property_available_date" CASCADE;
DROP TABLE IF EXISTS "property_amenity" CASCADE;
DROP TABLE IF EXISTS "property_accessibility" CASCADE;
DROP TABLE IF EXISTS "property_bedroom" CASCADE;
DROP TABLE IF EXISTS "property_host_language" CASCADE;
DROP TABLE IF EXISTS "property_photo" CASCADE;
DROP TABLE IF EXISTS "property_custom_house_rule" CASCADE;
DROP TABLE IF EXISTS "message" CASCADE;
DROP TABLE IF EXISTS "reviews" CASCADE;
DROP TABLE IF EXISTS "rental_requests" CASCADE;
DROP TABLE IF EXISTS "rental_agreement" CASCADE;
DROP TABLE IF EXISTS "payment" CASCADE;

DROP FUNCTION insert_property_review_scores;
DROP FUNCTION update_property_review_scores;
DROP FUNCTION update_property_review_scores_internal;
DROP FUNCTION check_property_available_date_non_contiguous;

DROP TYPE IF EXISTS property_types;
DROP TYPE IF EXISTS room_types;
DROP TYPE IF EXISTS currency_types;
DROP TYPE IF EXISTS amenity_types;
DROP TYPE IF EXISTS facility_types;
DROP TYPE IF EXISTS position_types;
DROP TYPE IF EXISTS accessibility_types;
DROP TYPE IF EXISTS bed_types;
DROP TYPE IF EXISTS rental_agreement_payment_statuses;
DROP TYPE IF EXISTS payment_types;
DROP TYPE IF EXISTS payment_statuses;
DROP TYPE IF EXISTS host_languages;
DROP TYPE IF EXISTS password_hash_types;
