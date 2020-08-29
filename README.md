# Description
A fake mini AirBnB clone built as a student project using Mojolicious and Postgres.

Highlights:
- the login system supports
    - salted passwords
    - transparently upgrading hashing algorithms and replacing old server secrets
    - preventing timing attacks to determine if an user (email) exists on the system
- mock data can be generated
- the availability algorithm checks the following:
  - start and stop dates for the availability request
  - the property's configured minimum days of notice before booking
  - the property's current rentals
  - the property's limit for future rentals
  - if applicable, the property's explicitly specified availability blocks
  - (anything causing unavailiability is reported to the user)
- the guest view supports finding any property availabile over any timeframe in a given city
- guests can request a rental on available properties
- hosts can accept rental requests
- hosts and guests get a message confirming the rental
- admins can view overall occupancy of properties
