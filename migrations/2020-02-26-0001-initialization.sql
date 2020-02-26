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
'Minsu (Taiwan)', 'Nature lodge', 'Ryokan (Japan)'

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

CREATE TABLE "person" (
  "person_id" SERIAL PRIMARY KEY,
  "first_name" varchar(255) NOT NULL,
  "middle_name" varchar(255) NOT NULL,
  "last_name" varchar(255) NOT NULL,
  "street_address" varchar,
  "city" varchar,
  "state" varchar,
  "country" varchar,
  "postal_code" varchar,
  "email" varchar NOT NULL,
  "is_id_verified" boolean NOT NULL DEFAULT FALSE,
  "is_address_verified" boolean NOT NULL DEFAULT FALSE
);

CREATE TABLE "property" (
  "property_id" SERIAL PRIMARY KEY,
  "title" varchar NOT NULL DEFAULT 'Untitled Listing',
  "street_address" varchar NOT NULL DEFAULT '',
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
  "advance_booking_allowed_for_num_months" int,
  "min_stay_length" int NOT NULL DEFAULT 1,
  "max_stay_length" int NOT NULL DEFAULT 1,
  "base_price" numeric(12,2),
  "min_price" numeric(12,2),
  "max_price" numeric(12,2),
  "currency" currency_types,
  "weekly_discount" int NOT NULL DEFAULT 0,
  "monthly_discount" int NOT NULL DEFAULT 0,

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

  CHECK (
    NOT is_published OR (
      "street_address" <> '' AND
      "state" <> '' AND
      "country" <> '' AND
      "postal_code" <> '' AND
      "checkin_time_from" IS NOT NULL AND
      "checkin_time_to" IS NOT NULL AND
      "checkout_time_from" IS NOT NULL AND
      "checkout_time_to" IS NOT NULL AND
      "sameday_booking_allowed_before_time" IS NOT NULL AND
      "advance_booking_allowed_for_num_months" IS NOT NULL AND
      "checkout_time_to" IS NOT NULL AND
      "base_price" IS NOT NULL AND
      "min_price" IS NOT NULL AND
      "max_price" IS NOT NULL AND
      "currency" IS NOT NULL AND
      "checkout_time_to" IS NOT NULL
    ) AND
    "weekly_discount" BETWEEN 0 AND 100 AND
    "monthly_discount" BETWEEN 0 AND 100
  )
);

CREATE TABLE "property_available_date" (
  "property_id" int,
  "available_date" date,
  PRIMARY KEY ("property_id", "available_date"),
  FOREIGN KEY ("property_id") REFERENCES "property" ("property_id")
);

CREATE TABLE "property_amenity" (
  "property_id" int,
  "amenity" amenity_types,
  PRIMARY KEY ("property_id", "amenity"),
  FOREIGN KEY ("property_id") REFERENCES "property" ("property_id")
);

CREATE TABLE "property_accessibility" (
  "property_id" int,
  "accessibility" accessibility_types,
  PRIMARY KEY ("property_id", "accessibility"),
  FOREIGN KEY ("property_id") REFERENCES "property" ("property_id")
);

CREATE TABLE "property_bedroom" (
  "property_id" int,
  "bedroom_number" int,
  "bed_type" bed_types,
  "num_beds" int NOT NULL,
  PRIMARY KEY ("property_id", "bedroom_number", "bed_type"),
  FOREIGN KEY ("property_id") REFERENCES "property" ("property_id")
);

CREATE TABLE "property_host_language" (
  "property_id" int,
  "host_language" varchar,
  PRIMARY KEY ("property_id", "host_language"),
  FOREIGN KEY ("property_id") REFERENCES "property" ("property_id")
);

CREATE TABLE "property_photo" (
  "property_id" int,
  "photo_filename" varchar,
  PRIMARY KEY ("property_id", "photo_filename"),
  FOREIGN KEY ("property_id") REFERENCES "property" ("property_id")
);

CREATE TABLE "property_custom_house_rule" (
  "property_id" int,
  "custom_house_rule" text,
  PRIMARY KEY ("property_id", "custom_house_rule"),
  FOREIGN KEY ("property_id") REFERENCES "property" ("property_id")
);

CREATE TABLE "message" (
  "message_id" int PRIMARY KEY,
  "property_id" int NOT NULL,
  "sender_id" int NOT NULL,
  "receiver_id" int NOT NULL,
  "created_at" timestamp NOT NULL DEFAULT NOW(),
  "subject" varchar NOT NULL,
  "content" text NOT NULL,
  FOREIGN KEY ("property_id") REFERENCES "property" ("property_id"),
  FOREIGN KEY ("sender_id") REFERENCES "person" ("person_id"),
  FOREIGN KEY ("receiver_id") REFERENCES "person" ("person_id")
);

CREATE TABLE "reviews" (
  "property_id" int,
  "person_id" int,
  "created_at" timestamp NOT NULL DEFAULT NOW(),
  "updated_at" timestamp NOT NULL DEFAULT NOW(),
  "location" int NOT NULL,
  "communication" int NOT NULL,
  "check_in" int NOT NULL,
  "accuracy" int NOT NULL,
  "cleanliness" int NOT NULL,
  "value" int NOT NULL,
  "comments" text NOT NULL DEFAULT '',
  PRIMARY KEY ("property_id", "person_id"),
  FOREIGN KEY ("property_id") REFERENCES "property" ("property_id"),
  FOREIGN KEY ("person_id") REFERENCES "person" ("person_id"),
  CHECK (
    "location" BETWEEN 1 AND 5 AND
    "communication" BETWEEN 1 AND 5 AND
    "check_in" BETWEEN 1 AND 5 AND
    "accuracy" BETWEEN 1 AND 5 AND
    "cleanliness" BETWEEN 1 AND 5 AND
    "value" BETWEEN 1 AND 5
  )
);

CREATE TABLE "rental_agreement" (
  "rental_id" SERIAL PRIMARY KEY,
  "property_id" int NOT NULL,
  "person_id" int NOT NULL,
  "signed_at" timestamp NOT NULL,
  "starts_at" timestamp NOT NULL,
  "ends_at" timestamp NOT NULL,
  "payment_status" rental_agreement_payment_statuses,
  "total_price" numeric(12,2) NOT NULL,
  FOREIGN KEY ("property_id") REFERENCES "property" ("property_id"),
  FOREIGN KEY ("person_id") REFERENCES "person" ("person_id")
);

CREATE TABLE "payment" (
  "rental_id" int NOT NULL,
  "created_at" timestamp NOT NULL,
  "completed_at" timestamp,
  "type" payment_types NOT NULL,
  "amount" numeric(12,2) NOT NULL,
  "status" payment_statuses NOT NULL,
  PRIMARY KEY ("rental_id", "created_at"),
  FOREIGN KEY ("rental_id") REFERENCES "rental_agreement" ("rental_id")
);

CREATE TABLE "person_phone_number" (
  "person_id" int,
  "phone_number" varchar,
  PRIMARY KEY ("person_id", "phone_number"),
  FOREIGN KEY ("person_id") REFERENCES "person" ("person_id")
);

CREATE TABLE "employee" (
  "person_id" int PRIMARY KEY,
  "manager_id" int,
  "workplace" varchar NOT NULL,
  "position" position_types NOT NULL,
  "salary" numeric(12,2) NOT NULL,
  FOREIGN KEY ("person_id") REFERENCES "person" ("person_id"),
  FOREIGN KEY ("manager_id") REFERENCES "employee" ("person_id")
);

CREATE TABLE "branch" (
  "country" varchar PRIMARY KEY,
  "manager_id" int NOT NULL,
  FOREIGN KEY ("manager_id") REFERENCES "employee" ("person_id")
);

ALTER TABLE "employee" ADD FOREIGN KEY ("workplace") REFERENCES "branch" ("country");

-- 1 down
DROP TABLE "employee" CASCADE;
DROP TABLE "branch" CASCADE;
DROP TABLE "person_phone_number" CASCADE;
DROP TABLE "person" CASCADE;
DROP TABLE "property" CASCADE;
DROP TABLE "property_available_date" CASCADE;
DROP TABLE "property_amenity" CASCADE;
DROP TABLE "property_accessibility" CASCADE;
DROP TABLE "property_bedroom" CASCADE;
DROP TABLE "property_host_language" CASCADE;
DROP TABLE "property_photo" CASCADE;
DROP TABLE "property_custom_house_rule" CASCADE;
DROP TABLE "message" CASCADE;
DROP TABLE "reviews" CASCADE;
DROP TABLE "rental_agreement" CASCADE;
DROP TABLE "payment" CASCADE;

DROP TYPE property_types;
DROP TYPE room_types;
DROP TYPE currency_types;
DROP TYPE amenity_types;
DROP TYPE facility_types;
DROP TYPE position_types;
DROP TYPE accessibility_types;
DROP TYPE bed_types;
DROP TYPE rental_agreement_payment_statuses;
DROP TYPE payment_types;
DROP TYPE payment_statuses;
DROP TYPE host_languages;