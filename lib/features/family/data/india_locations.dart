// Indian states/UTs with major cities for family location pickers.
// Mirrors web `src/data/indiaLocations.js`.

const Map<String, List<String>> indiaStateCities = {
  'Andaman and Nicobar Islands': ['Port Blair'],
  'Andhra Pradesh': [
    'Visakhapatnam',
    'Vijayawada',
    'Guntur',
    'Nellore',
    'Tirupati',
    'Kurnool',
    'Rajahmundry',
    'Kadapa',
  ],
  'Arunachal Pradesh': [
    'Itanagar',
    'Naharlagun',
    'Tawang',
    'Pasighat',
    'Ziro',
  ],
  'Assam': [
    'Guwahati',
    'Silchar',
    'Dibrugarh',
    'Jorhat',
    'Tezpur',
    'Nagaon',
  ],
  'Bihar': [
    'Patna',
    'Gaya',
    'Bhagalpur',
    'Muzaffarpur',
    'Purnia',
    'Darbhanga',
  ],
  'Chandigarh': ['Chandigarh'],
  'Chhattisgarh': [
    'Raipur',
    'Bhilai',
    'Bilaspur',
    'Korba',
    'Durg',
    'Rajnandgaon',
  ],
  'Dadra and Nagar Haveli and Daman and Diu': ['Daman', 'Diu', 'Silvassa'],
  'Delhi': [
    'New Delhi',
    'Central Delhi',
    'South Delhi',
    'North Delhi',
    'East Delhi',
    'West Delhi',
  ],
  'Goa': ['Panaji', 'Margao', 'Vasco da Gama', 'Mapusa', 'Ponda'],
  'Gujarat': [
    'Ahmedabad',
    'Surat',
    'Vadodara',
    'Rajkot',
    'Bhavnagar',
    'Jamnagar',
    'Gandhinagar',
  ],
  'Haryana': [
    'Gurugram',
    'Faridabad',
    'Panipat',
    'Ambala',
    'Karnal',
    'Hisar',
    'Rohtak',
  ],
  'Himachal Pradesh': [
    'Shimla',
    'Manali',
    'Dharamshala',
    'Solan',
    'Mandi',
    'Kullu',
    'Hamirpur',
  ],
  'Jammu and Kashmir': [
    'Srinagar',
    'Jammu',
    'Anantnag',
    'Baramulla',
    'Udhampur',
  ],
  'Jharkhand': [
    'Ranchi',
    'Jamshedpur',
    'Dhanbad',
    'Bokaro',
    'Deoghar',
    'Hazaribagh',
  ],
  'Karnataka': [
    'Bengaluru',
    'Mysuru',
    'Mangaluru',
    'Hubballi',
    'Belagavi',
    'Kalaburagi',
    'Udupi',
  ],
  'Kerala': [
    'Thiruvananthapuram',
    'Kochi',
    'Kozhikode',
    'Thrissur',
    'Kannur',
    'Kollam',
    'Alappuzha',
  ],
  'Ladakh': ['Leh', 'Kargil'],
  'Lakshadweep': ['Kavaratti'],
  'Madhya Pradesh': [
    'Bhopal',
    'Indore',
    'Gwalior',
    'Jabalpur',
    'Ujjain',
    'Sagar',
    'Rewa',
  ],
  'Maharashtra': [
    'Mumbai',
    'Pune',
    'Nagpur',
    'Nashik',
    'Thane',
    'Aurangabad',
    'Kolhapur',
    'Solapur',
  ],
  'Manipur': ['Imphal', 'Thoubal', 'Bishnupur', 'Churachandpur'],
  'Meghalaya': ['Shillong', 'Tura', 'Jowai', 'Nongpoh'],
  'Mizoram': ['Aizawl', 'Lunglei', 'Champhai', 'Serchhip'],
  'Nagaland': ['Kohima', 'Dimapur', 'Mokokchung', 'Tuensang'],
  'Odisha': [
    'Bhubaneswar',
    'Cuttack',
    'Rourkela',
    'Puri',
    'Sambalpur',
    'Berhampur',
  ],
  'Puducherry': ['Puducherry', 'Karaikal', 'Mahe', 'Yanam'],
  'Punjab': [
    'Ludhiana',
    'Amritsar',
    'Jalandhar',
    'Patiala',
    'Mohali',
    'Bathinda',
  ],
  'Rajasthan': [
    'Jaipur',
    'Jodhpur',
    'Udaipur',
    'Kota',
    'Ajmer',
    'Bikaner',
    'Alwar',
  ],
  'Sikkim': ['Gangtok', 'Namchi', 'Gyalshing', 'Mangan'],
  'Tamil Nadu': [
    'Chennai',
    'Coimbatore',
    'Madurai',
    'Tiruchirappalli',
    'Salem',
    'Tirunelveli',
    'Erode',
  ],
  'Telangana': [
    'Hyderabad',
    'Warangal',
    'Nizamabad',
    'Karimnagar',
    'Khammam',
  ],
  'Tripura': ['Agartala', 'Udaipur', 'Dharmanagar', 'Kailashahar'],
  'Uttar Pradesh': [
    'Lucknow',
    'Kanpur',
    'Varanasi',
    'Agra',
    'Noida',
    'Ghaziabad',
    'Prayagraj',
    'Meerut',
    'Bareilly',
    'Aligarh',
  ],
  'Uttarakhand': [
    'Dehradun',
    'Haridwar',
    'Rishikesh',
    'Nainital',
    'Haldwani',
    'Roorkee',
    'Chamoli',
    'Pauri',
    'Tehri',
    'Almora',
    'Pithoragarh',
    'Rudraprayag',
    'Uttarkashi',
    'Mussoorie',
  ],
  'West Bengal': [
    'Kolkata',
    'Howrah',
    'Durgapur',
    'Asansol',
    'Siliguri',
    'Darjeeling',
  ],
};

List<String> get indiaStates => indiaStateCities.keys.toList()..sort();

List<String> citiesForState(String? state) {
  if (state == null || state.isEmpty) return const [];
  return indiaStateCities[state] ?? const [];
}

/// Build `"City, State"` for storage / map geocoding.
String formatLocation(String? city, String? state) {
  final c = (city ?? '').trim();
  final s = (state ?? '').trim();
  if (c.isNotEmpty && s.isNotEmpty) return '$c, $s';
  if (s.isNotEmpty) return s;
  if (c.isNotEmpty) return c;
  return '';
}

class ParsedLocation {
  const ParsedLocation({this.state = '', this.city = ''});
  final String state;
  final String city;
}

/// Parse stored location strings into state/city.
ParsedLocation parseLocation(String? locationText) {
  final raw = (locationText ?? '').trim();
  if (raw.isEmpty) return const ParsedLocation();

  final parts = raw
      .split(RegExp(r'\s*[,/|\-–—]\s*'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  String lower(String s) => s.toLowerCase();
  final states = indiaStates;

  for (final s in states) {
    if (lower(raw) == lower(s)) return ParsedLocation(state: s);
  }

  String? matchState(String value) {
    for (final s in states) {
      if (lower(s) == lower(value)) return s;
    }
    return null;
  }

  String? matchCity(String state, String value) {
    for (final c in citiesForState(state)) {
      if (lower(c) == lower(value)) return c;
    }
    return null;
  }

  if (parts.length >= 2) {
    final a = parts.first;
    final b = parts.last;
    final stateAsB = matchState(b);
    final stateAsA = matchState(a);

    if (stateAsB != null) {
      return ParsedLocation(
        state: stateAsB,
        city: matchCity(stateAsB, a) ?? a,
      );
    }
    if (stateAsA != null) {
      return ParsedLocation(
        state: stateAsA,
        city: matchCity(stateAsA, b) ?? b,
      );
    }
  }

  for (final s in states) {
    for (final c in citiesForState(s)) {
      if (lower(raw).contains(lower(c))) {
        return ParsedLocation(state: s, city: c);
      }
    }
    if (lower(raw).contains(lower(s))) {
      return ParsedLocation(state: s);
    }
  }

  return ParsedLocation(city: raw);
}
