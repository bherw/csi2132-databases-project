package Csi2132::Project::Model::Property;
use Const::Fast;

use Mojo::Base -base, -signatures;

const our @COUNTRIES => qw(USA Canada Germany UK France Mexico Japan China);
const our @PROPERTY_TYPES => (
    # Apartment
    'Apartment', 'Condominium', 'Casa particular (Cuba)', 'Loft', 'Serviced apartment',

    # House
    'House', 'Bungalow', 'Cabin', 'Chalet', 'Cottage', 'Cycladic house (Greece)', 'Dammuso (Italy)', 'Dome house', 'Earth house', 'Farm stay', 'Houseboat', 'Hut', 'Lighthouse', 'Pension (South Korea)', 'Shepherds Hut (U.K., France)', 'Tiny house', 'Townhouse', 'Trullo (Italy)', 'Villa',

    # Secondary unit
    'Guesthouse', 'Guest suite',

    # Unique space
    'Barn', 'Boat', 'Bus', 'Camper/RV', 'Campsite', 'Castle', 'Cave', 'Igloo', 'Island', 'Plane', 'Tent', 'Teepee', 'Train', 'Treehouse', 'Windmill', 'Yurt',

    # Bed and breakfast
    'Minsu (Taiwan)', 'Nature lodge', 'Ryokan (Japan)',

    # Boutique hotel
    'Boutique hotel', 'Aparthotel', 'Heritage hotel (India)', 'Hostel', 'Hotel', 'Resort', 'Kezhan (China)'
);
const our @ROOM_TYPES => ('Entire place', 'Private room', 'Hotel room', 'Shared room');
const our @CURRENCY_TYPES => ('CAD', 'USD');
const our @AMENITY_TYPES => ('Essentials', 'Air conditioning', 'Heat', 'Hair dryer', 'Closet / drawers', 'Iron', 'TV', 'Fireplace', 'Private entrance', 'Shampoo', 'Wifi', 'Desk/workspace', 'Breakfast, coffee, tea', 'Fire extinguisher', 'Carbon monoxide detector', 'Smoke detector', 'First aid kit', 'Indoor fireplace', 'Hangers', 'Crib', 'High chair', 'Self check-in', 'Private bathroom', 'Beachfront', 'Waterfront', 'Ski-in/ski-out');

1;