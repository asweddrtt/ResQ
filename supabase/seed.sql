-- Demo content so the home, shelters, clinics, adoption and lost & found screens
-- aren't empty. Loaded by `supabase start` (first run) and `supabase db reset`.
-- These rows aren't owned by any account; create your own posts in the app too.

insert into public.shelters (id, name, phone, address, city, description, working_hours, status) values
  ('11111111-1111-1111-1111-111111111111', 'Paws of Hope Shelter', '+20 100 123 4567', '12 El Nasr St, Maadi', 'Cairo',
   'Rescuing and rehoming street dogs and cats since 2015. Over 300 animals adopted.', 'Daily 9:00 - 18:00', 'approved'),
  ('22222222-2222-2222-2222-222222222222', 'Alexandria Animal Haven', '+20 122 987 6543', '45 Corniche Rd, Sidi Gaber', 'Alexandria',
   'A safe haven for injured and abandoned animals on the north coast.', 'Sat - Thu 10:00 - 17:00', 'approved'),
  ('33333333-3333-3333-3333-333333333333', 'Giza Rescue Farm', '+20 111 222 3344', 'Saqqara Rd, Abu Rawash', 'Giza',
   'Open-space farm sheltering donkeys, horses, dogs and cats.', 'Daily 8:00 - 16:00', 'approved');

insert into public.clinics (id, name, phone, address, city, description, working_hours, status) values
  ('44444444-4444-4444-4444-444444444444', 'Nile Vet Clinic', '+20 102 555 0101', '8 Road 9, Maadi', 'Cairo',
   '24/7 emergency care, surgery and vaccinations. Discounted care for rescues.', 'Open 24/7', 'approved'),
  ('55555555-5555-5555-5555-555555555555', 'Happy Tails Veterinary Center', '+20 128 444 0202', '22 Fouad St', 'Alexandria',
   'Internal medicine, dental care and free check-ups for adopted pets.', 'Daily 10:00 - 22:00', 'approved');

insert into public.cases (animal_type, severity, description, location_text, location_lat, location_lng, status, created_at) values
  ('Dog', 'emergency', 'Injured dog with a hurt back leg near the metro station. Not able to walk.',
   'Maadi Metro Station, Cairo', 29.9602, 31.2577, 'new', now() - interval '25 minutes'),
  ('Cat', 'high', 'Mother cat with 4 kittens stuck in a construction site, needs safe relocation.',
   'Sheikh Zayed, Giza', 30.0444, 30.9760, 'new', now() - interval '2 hours'),
  ('Bird', 'normal', 'Pigeon with a wing injury found on a balcony.',
   'Zamalek, Cairo', 30.0626, 31.2197, 'new', now() - interval '5 hours'),
  ('Dog', 'moderate', 'Malnourished puppy wandering near the beach.',
   'Stanley Bridge, Alexandria', 31.2353, 29.9480, 'new', now() - interval '1 day');

insert into public.animals (shelter_id, name, species, breed, age, gender, size, color, vaccinated, is_neutered,
                            health_condition, special_needs, friendly_people, friendly_kids, friendly_animals,
                            house_trained, energy_level, living_preference, adoption_fee, city, area, status) values
  ('11111111-1111-1111-1111-111111111111', 'Luna', 'dog', 'Baladi', '2 years', 'female', 'medium', 'Golden',
   true, true, 'Healthy', 'None', true, true, true, true, 'medium', 'both', 0, 'Cairo', 'Maadi', 'available'),
  ('11111111-1111-1111-1111-111111111111', 'Simba', 'cat', 'Egyptian Mau', '1 year', 'male', 'small', 'Spotted silver',
   true, false, 'Healthy', 'None', true, true, false, true, 'high', 'indoor', 0, 'Cairo', 'Maadi', 'available'),
  ('22222222-2222-2222-2222-222222222222', 'Max', 'dog', 'German Shepherd mix', '4 years', 'male', 'large', 'Black and tan',
   true, true, 'Recovered from a leg injury', 'Needs a home with a garden', true, false, true, true, 'high', 'outdoor', 500, 'Alexandria', 'Sidi Gaber', 'available'),
  ('33333333-3333-3333-3333-333333333333', 'Mishmish', 'cat', 'Baladi', '6 months', 'female', 'small', 'Orange',
   true, false, 'Healthy', 'None', true, true, true, false, 'high', 'indoor', 0, 'Giza', 'Abu Rawash', 'available');

insert into public.lost_found_reports (type, animal_type, description, location_text, location_lat, location_lng, status, created_at) values
  ('lost', 'dog', 'Lost white husky named Snow, blue collar, very friendly. Reward offered.',
   'New Cairo, 5th Settlement', 30.0074, 31.4913, 'open', now() - interval '3 hours'),
  ('found', 'cat', 'Found a grey Persian cat near the club gate, looks well cared for.',
   'Heliopolis, Cairo', 30.0911, 31.3225, 'open', now() - interval '1 day');
