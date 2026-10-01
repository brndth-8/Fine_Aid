/// Static, locally-stored healthcare facility directory — no map
/// integration, no location permission, no live network lookup. Replace
/// or extend this list with real data as it becomes available; the shape
/// is deliberately simple so that's an easy drop-in.
class HealthcareFacility {
  final String name;
  final String category;
  final String contact;
  final String address;
  final bool is24Hours;

  const HealthcareFacility({
    required this.name,
    required this.category,
    required this.contact,
    required this.address,
    this.is24Hours = false,
  });

  /// The first thing in [contact] that looks like a dialable phone number
  /// (so a UI can offer "tap to call" only when that's actually possible —
  /// some entries are email addresses, "N/A", or a note like "walk-ins
  /// only"). Returns null when nothing dialable was found.
  String? get primaryPhoneNumber {
    final match = RegExp(r'[+\d][\d\s\-()]{6,}\d').firstMatch(contact);
    if (match == null) return null;
    return match.group(0)?.trim();
  }
}

/// Source: San Jose del Monte Healthcare Directory (supplied by the app
/// owner). Category strings match the directory's own section headings.
const List<HealthcareFacility> kHealthcareFacilities = [
  // PUBLIC HOSPITALS
  HealthcareFacility(
    name: 'City Health Office - City of San Jose del Monte',
    category: 'Public Hospitals',
    contact: '(044) 691 2584',
    address:
        'Municipal Hall, M. Villarica Rd, SJDM, 3023 Bulacan, '
        'Philippines, San Jose del Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'DJNRMHS - BUCAS (Public Ambulatory Clinic)',
    category: 'Public Hospitals',
    contact: '(02) 8929-42571',
    address: 'Towerville Rd, Brgy. Minuyan Proper',
  ),
  HealthcareFacility(
    name:
        'Dr. Jose N. Rodriguez Memorial Hospital and Sanitarium - '
        'Ambulatory Surgical Clinic',
    category: 'Public Hospitals',
    contact: '8294-2571',
    address: 'Minuyan Proper, San Jose del Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'Ospital ng Lungsod ng San Jose del Monte',
    category: 'Public Hospitals',
    contact: 'Official Facebook Page or via City Hall',
    address: '119 Maginhawa, Brgy. Bagong Buhay 1',
  ),

  // MUNICIPAL HEALTH OFFICES
  HealthcareFacility(
    name: 'City Health Center I',
    category: 'Municipal Health Offices',
    contact: '044 3062240',
    address: 'San Pedro St., Brgy. Poblacion I, San Jose del Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'City Health Center II',
    category: 'Municipal Health Offices',
    contact: '044 3078003 / 0956 986 9417',
    address:
        'Pecsonville, Brgy. Tungkong Mangga, San Jose del Monte, '
        'Bulacan',
  ),
  HealthcareFacility(
    name: 'City Health Center IV',
    category: 'Municipal Health Offices',
    contact: 'chc4bb1@gmail.com',
    address:
        'Blk 18 Lot 16 Sta. Catalina Street, Fatima V Area, San Jose '
        'del Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'City Health Center VII',
    category: 'Municipal Health Offices',
    contact: '0995 0350 632',
    address:
        'Blk 33 Open Area, Australia, Brgy. Muzon South, San Jose del '
        'Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'City Health Center IX',
    category: 'Municipal Health Offices',
    contact: '0917 1126067',
    address: 'Igay Road, Brgy. Paradise 3, San Jose del Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'City Health Center X',
    category: 'Municipal Health Offices',
    contact: '0917 6282560',
    address:
        'Phase 1A Towerville, Brgy. Minuyan Proper, San Jose del '
        'Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'City Health Center XI',
    category: 'Municipal Health Offices',
    contact: '0991 5659370',
    address:
        'Blk 5 Lot 1&2 Phase E, Brgy. Francisco Homes, San Jose del '
        'Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'City Health Center XIII',
    category: 'Municipal Health Offices',
    contact: '0930-790-7710',
    address:
        'Blk 8 Mapagbigay St., Graceville 3, San Jose del Monte, '
        'Bulacan',
  ),
  HealthcareFacility(
    name: 'San Jose del Monte City Health Office',
    category: 'Municipal Health Offices',
    contact: '0956 9869 417',
    address:
        'JP Rizal St., Barangay Poblacion 1, San Jose del Monte, '
        'Bulacan',
  ),

  // GENERAL PRACTICE
  HealthcareFacility(
    name: 'Kaypian Health Station',
    category: 'General Practice',
    contact: '0966 4531 212',
    address: 'Phase 2, Barangay Kaypian, San Jose del Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'St. Bernadette Multispecialty and Primary Care Facility',
    category: 'General Practice',
    contact: '044 320 3536',
    address:
        'Phase II, San Jose del Monte Heights, Muzon East, San Jose '
        'del Monte, Bulacan',
  ),

  // PRIVATE HOSPITALS
  HealthcareFacility(
    name: 'Brigino General Hospital',
    category: 'Private Hospitals',
    contact: '(044) 815-4456',
    address: '20 Quirino Highway, Pecsonville',
  ),
  HealthcareFacility(
    name: 'Dr. Eduardo V. Roquero Memorial Hospital',
    category: 'Private Hospitals',
    contact: 'Direct walk-ins (No active landline)',
    address: 'Area F, Brgy. San Pedro, SJDM',
  ),
  HealthcareFacility(
    name: 'Grace Medical Center',
    category: 'Private Hospitals',
    contact: '(044) 769-1355 / (02) 8925-1131 / +63 998 973 2523',
    address:
        'Lot 2, Blk 1 Quirino Highway Ext., Brgy. Mulawin, Francisco '
        'Homes',
  ),
  HealthcareFacility(
    name: 'Healthway QualiMed Hospital San Jose del Monte',
    category: 'Private Hospitals',
    contact: '(044) 307-0000 / +63 917 178 2298',
    address: 'Altaraza Town Center, Brgy. Tungkong Mangga',
  ),
  HealthcareFacility(
    name: 'Holistic Care General Hospital',
    category: 'Private Hospitals',
    contact: '(044) 913-5418',
    address: 'B-25 L-9, Area-C',
  ),
  HealthcareFacility(
    name: 'Kairos Medical Center',
    category: 'Private Hospitals',
    contact: '(044) 815-4653 / +63 954 296 3659',
    address: 'M. Villarica Road, Brgy. San Jose, Muzon Proper',
  ),
  HealthcareFacility(
    name: 'San Jose del Monte - Muzon Medical Center (ACE Group)',
    category: 'Private Hospitals',
    contact: '+63 917 112 8396 / +63 917 139 0479',
    address: '122 Carriedo St., Brgy. Muzon',
  ),
  HealthcareFacility(
    name: 'SJP Infirmary, Diagnostic and Pharmacy',
    category: 'Private Hospitals',
    contact: '+63 945 843 3224',
    address: 'Daang Barrio Road, Brgy. Sapang Palay Proper, SJDM',
  ),
  HealthcareFacility(
    name: 'Skyline Hospital and Medical Center',
    category: 'Private Hospitals',
    contact: '(044) 815-7770 / +63 977 830 3348',
    address: 'Skyline Drive cor. Quirino Highway, Brgy. Tungkong Mangga',
  ),

  // ANIMAL BITE CLINICS
  HealthcareFacility(
    name: '3MAC Animal Bite Clinic',
    category: 'Animal Bite Clinics',
    contact: '+63 991 531 8787',
    address: 'Lot 1256-A-5-I-19, Sitio Central, Sapang Palay',
  ),
  HealthcareFacility(
    name: 'Animal Bite Center',
    category: 'Animal Bite Clinics',
    contact: '0948 116 7750',
    address:
        'R26W+7W2, San Ignacio St, Poblacion 1, SJDM, 3023 Bulacan, '
        'Philippines, San Jose del Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'City Health Office IX - Animal Bite Center',
    category: 'Animal Bite Clinics',
    contact: '+63 956 986 9417',
    address: 'Zone 1, Brgy. San Roque, SJDM',
  ),
  HealthcareFacility(
    name: 'DR Animal Bite Clinic',
    category: 'Animal Bite Clinics',
    contact: '0936 933 9509',
    address:
        'BLK 22 LOT 15, Brgy. Graceville 1, Muzon Proper, SJDM, 3023 '
        'Bulacan, Philippines, San Jose del Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'Dr. Bite Animal Bite Clinic - Towerville',
    category: 'Animal Bite Clinics',
    contact: '+63 960 560 6006',
    address: 'Brgy. Minuyan Towerville, 32 Quirino Highway',
  ),
  HealthcareFacility(
    name: 'DR. CARE Animal Bite Center Dulong Bayan',
    category: 'Animal Bite Clinics',
    contact: '+63 997 510 1112',
    address: 'L747-1-4, Sitio Ibabaw, Provincial Road, Dulong Bayan',
  ),
  HealthcareFacility(
    name: 'DR CARE Medical Clinic and Animal Bite Center SJDM',
    category: 'Animal Bite Clinics',
    contact: '0927 326 6918',
    address:
        'Unit 16, KM35 Quirino Hwy, Santo Cristo, SJDM, 3023 Bulacan, '
        'Philippines, San Jose del Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'DR. CARE Santo Cristo SJDM Animal Bite Center',
    category: 'Animal Bite Clinics',
    contact: '+63 927 326 6918',
    address: 'Unit #16, KM35 Quirino Highway, Santo Cristo',
  ),
  HealthcareFacility(
    name: 'Dr. Pau ABC Animal Bite Center',
    category: 'Animal Bite Clinics',
    contact: '+63 915 044 0951',
    address: 'Dr. Eduardo Roquero Avenue, Sapang Palay',
  ),
  HealthcareFacility(
    name: 'Francisco Harmony Animal Bite Clinic',
    category: 'Animal Bite Clinics',
    contact: '+63 947 827 3200',
    address: 'Quirino Highway, San Jose del Monte',
    is24Hours: true,
  ),
  HealthcareFacility(
    name: 'JMN Towerville Animal Bite Clinic',
    category: 'Animal Bite Clinics',
    contact: '+63 995 792 5622',
    address: 'Towerville, SJDM, Bulacan',
    is24Hours: true,
  ),
  HealthcareFacility(
    name: 'Pabahay 2000 Animal Bite Clinic',
    category: 'Animal Bite Clinics',
    contact: '+63 961 958 6562',
    address: 'B7 L17 S16 P2, South Avenue, Pabahay Muzon',
    is24Hours: true,
  ),
  HealthcareFacility(
    name: 'Rab-Out Animal Bite Clinic',
    category: 'Animal Bite Clinics',
    contact: '+63 967 456 4859',
    address: 'Brgy. Gaya-Gaya Barangay Hall, 0188 National Road',
  ),
  HealthcareFacility(
    name: 'Rabies Guard Animal Bite Center',
    category: 'Animal Bite Clinics',
    contact: '+63 947 468 0594',
    address: '2nd Floor, GLES Building, Quirino Highway',
  ),
  HealthcareFacility(
    name: 'RabZero Clinic Animal Bite Center',
    category: 'Animal Bite Clinics',
    contact: '+63 995 654 9756',
    address: 'Near Starmall, Asuncion Diaz Abella Rd',
    is24Hours: true,
  ),
  HealthcareFacility(
    name: 'RAC Animal Bite Clinic',
    category: 'Animal Bite Clinics',
    contact: '+63 963 472 8000',
    address: '285 Carriedo St., Muzon',
  ),
  HealthcareFacility(
    name: 'Saint-Pio Animal Bite Center',
    category: 'Animal Bite Clinics',
    contact: '+63 948 787 0218',
    address:
        'Blk 1 Lot 1, VO. Bello Building, Welcome Francisco Homes, '
        'Brgy. Mulawin',
    is24Hours: true,
  ),
  HealthcareFacility(
    name: 'Towerville Animal Bite Clinic',
    category: 'Animal Bite Clinics',
    contact: '+63 962 149 8732',
    address: 'Aurora St., Towerville, SJDM',
  ),
  HealthcareFacility(
    name: 'Vaxicare Animal Bite Clinic',
    category: 'Animal Bite Clinics',
    contact: 'Check local clinic announcements for available slots',
    address:
        '1st Floor, Unit 1, 9046 National Rd., Gov. Fortunato Halili '
        'Rd.',
  ),

  // GENERAL CLINICS & DIAGNOSTIC HUBS
  HealthcareFacility(
    name: 'Archangels',
    category: 'General Clinics & Diagnostic Hubs',
    contact: '0932 200 0443',
    address:
        'Pecson Ville Subdivision, Tandoc Avenue, SJDM, 3023 '
        'Bulacan, Philippines, San Jose del Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'Biolab Diagnostic Center',
    category: 'General Clinics & Diagnostic Hubs',
    contact: '0926 298 7342',
    address:
        'Block 16, Lot 46 Road 1, Minuyan II, SJDM, 3023 Bulacan, '
        'Philippines, San Jose del Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'Calibre Medical and Diagnostic Center',
    category: 'General Clinics & Diagnostic Hubs',
    contact: '0961 451 2000',
    address:
        '540 National Road, SJDM, 3023 Bulacan, Philippines, San '
        'Jose del Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'City Health Office (Primary Care Command Center)',
    category: 'General Clinics & Diagnostic Hubs',
    contact: '+63 956 986 9417 / (044) 919-7370',
    address:
        '2nd Floor, Right Wing, New Government Center, Brgy. Dulong '
        'Bayan',
  ),
  HealthcareFacility(
    name: 'CODEVAR Medical Arts Polyclinic & Diagnostic Center Clinic',
    category: 'General Clinics & Diagnostic Hubs',
    contact: '0935 405 1190',
    address:
        'R25X+G7X, SJDM, Bulacan, Philippines, San Jose del Monte, '
        'Bulacan',
  ),
  HealthcareFacility(
    name: 'Fast Health Medical and Diagnostic Clinic Dulong Bayan',
    category: 'General Clinics & Diagnostic Hubs',
    contact: 'N/A',
    address:
        'Lot 750 B-1, Barangay, SJDM, 3023 Bulacan, Philippines, San '
        'Jose del Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'Hi-Precision Diagnostics - San Jose del Monte',
    category: 'General Clinics & Diagnostic Hubs',
    contact: '(044) 492-3904 / +63 917 847 1522',
    address: 'Quirino Highway, Brgy. Tungkong Mangga',
  ),
  HealthcareFacility(
    name: 'JCMC',
    category: 'General Clinics & Diagnostic Hubs',
    contact: '0922 939 3553',
    address:
        '225 Zone 2 Carriedo, Muzon, SJDM, 3023 Bulacan, Philippines, '
        'San Jose del Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'JP Diagnostic Laboratory',
    category: 'General Clinics & Diagnostic Hubs',
    contact: '(044) 815 6934',
    address:
        'R25W+QWQ, M. Villarica Rd, SJDM, 3023 Bulacan, Philippines, '
        'San Jose del Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'Labpro Diagnostic Center',
    category: 'General Clinics & Diagnostic Hubs',
    contact: '(044) 913 1152',
    address:
        'Q3PF+PMV, Pecson Ville Subdivision, SJDM, Bulacan, '
        'Philippines, San Jose del Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'LN Laboratory Clinic (Dr. Litava Co)',
    category: 'General Clinics & Diagnostic Hubs',
    contact: '0932 652 9967',
    address:
        'Barangay, Matiyaga Street, Area B, SJDM, 3024 Bulacan, '
        'Philippines, San Jose del Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'Maxicare Primary Care Clinic - Skyline SJDM',
    category: 'General Clinics & Diagnostic Hubs',
    contact: '(02) 7798-7777 / +63 917 843 1481',
    address:
        'Skyline Drive Plaza, Quirino Highway, Brgy. Tungkong '
        'Mangga, SJDM',
  ),
  HealthcareFacility(
    name: 'Misiona Drug Testing Center',
    category: 'General Clinics & Diagnostic Hubs',
    contact: '0923 458 1127',
    address:
        'R22M+FQ2, Carriedo St, Muzon, SJDM, Bulacan, Philippines, '
        'San Jose del Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'R. Gangan Medical Clinic',
    category: 'General Clinics & Diagnostic Hubs',
    contact: '0928 195 2836',
    address:
        '1726 Linawan, SJDM, Bulacan, Philippines, San Jose del '
        'Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'RABVIE Medical and Diagnostic Clinic (formerly Rabv Clinic)',
    category: 'General Clinics & Diagnostic Hubs',
    contact: '0917 802 9926',
    address:
        'Lot 10 Ipo Road, Minuyan Proper, SJDM, 3023 Bulacan, '
        'Philippines, San Jose del Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'RRT Medical and Diagnostic Center',
    category: 'General Clinics & Diagnostic Hubs',
    contact: '0916 593 2758',
    address:
        'Matiyaga Street, SJDM, 3023 Bulacan, Philippines, San Jose '
        'del Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'RRT Medical and Diagnostic Clinic - Rd 1',
    category: 'General Clinics & Diagnostic Hubs',
    contact: '0956 900 2826',
    address:
        'R3RH+WF3, Del Monte - Norzagaray Rd, SJDM, Bulacan, '
        'Philippines, San Jose del Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'Sapang Palay Diagnostic Clinic',
    category: 'General Clinics & Diagnostic Hubs',
    contact: 'N/A',
    address: 'V344+V9V, Dr. Eduardo V. Roquero Sr. Avenue, SJDM, Bulakan',
  ),
  HealthcareFacility(
    name: 'SJP Infirmary Diagnostic and Pharmacy',
    category: 'General Clinics & Diagnostic Hubs',
    contact: '0920 480 3529',
    address:
        'R25W+CW9, Daang Barrio Road, SJDM, Bulacan, Philippines, '
        'San Jose del Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'Tech Med',
    category: 'General Clinics & Diagnostic Hubs',
    contact: '0933 575 1346',
    address:
        'R25W+RVX, M. Villarica Rd, Poblacion 1, SJDM, 3023 Bulacan, '
        'Philippines, San Jose del Monte, Bulacan',
  ),
  HealthcareFacility(
    name: 'The Medical City (TMC) Clinic - SM City San Jose del Monte',
    category: 'General Clinics & Diagnostic Hubs',
    contact:
        '(02) 8396-9899 local 4006 / (044) 8492-8795 / +63 968 772 '
        '6625',
    address:
        '2/F, SM City San Jose del Monte, Quirino Highway, Brgy. '
        'Tungkong Mangga',
  ),
  HealthcareFacility(
    name: 'WI Care Medical and Diagnostic Clinic',
    category: 'General Clinics & Diagnostic Hubs',
    contact: '0905 245 2318',
    address:
        'Quirino St, SJDM, 3023 Bulacan, Philippines, San Jose del '
        'Monte, Bulacan',
  ),
];
