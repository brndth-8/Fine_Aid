/// Help & Support section text, English. Taken from the "All Information
/// Needed in the Application" document, in its order and headings.
/// Small wording fixes made while transcribing (typos, an unfinished
/// sentence, an editing note left in the document) are listed in the change
/// summary; no meaning, medical claim or legal wording was changed.
library;

import 'help_document.dart';

const helpGettingStartedEn = HelpSection(
  title: 'Getting Started',
  blocks: [
    HelpHeading('GETTING STARTED WITH FINE AID'),
    HelpParagraph(
      'Your AI-Powered First Aid Guidance & Healing Progress Companion',
    ),
    HelpHeading('WELCOME, DEAR USER!'),
    HelpParagraph(
      'Fine Aid is an AI-driven mobile application designed to provide '
      'reliable, preliminary first-aid guidance and step-by-step wound care '
      'support.',
    ),
    HelpParagraph(
      'Whether you need immediate instructions for a minor injury, want to '
      'scan a wound for automated analysis, or need to track your healing '
      'progress over time, Fine Aid offers an evidence-based toolkit '
      'cross-referenced against trusted medical sources (including WHO, Red '
      'Cross, MIMS Philippines, and local health standards).',
    ),
    HelpCallout(
      'IMPORTANT MEDICAL DISCLAIMER: Fine Aid is a preliminary guidance and '
      'progress-monitoring tool developed for informational and educational '
      'support. It is NOT a substitute for professional medical advice, '
      'clinical diagnosis, or emergency services. In life-threatening '
      'emergencies, call your local emergency hotline (e.g., 911) or visit '
      'the nearest hospital immediately.',
    ),
    HelpHeading('OPERATIONAL MODE'),
    HelpParagraph(
      'Fine Aid is designed to work under any circumstance, whether you have '
      'high-speed internet, limited time, or zero connectivity.',
    ),
    HelpList([
      HelpItem(
        'Full app access: AI Camera scanning, Cloud-synced Health Journal, '
        'Auto-Referral Alerts, Nearby Healthcare Finder, OTC Suggestions, '
        'Chatbot, and Log Export.',
        label: 'Online Mode (Registered & Signed In)',
        stacked: true,
      ),
      HelpItem(
        'Fast entry: Trial AI Camera scans, general first-aid textbook '
        'access, temporary journal drafts, and basic support. (Daily upload '
        'limits apply until registration).',
        label: 'Guest Mode (No Account Required)',
        stacked: true,
      ),
      HelpItem(
        'Emergency safety net: Pre-loaded offline First Aid Textbook & '
        'Health Kit library, and text-only Health Journal entry logging.',
        label: 'Offline Mode (No Connection)',
        stacked: true,
      ),
    ]),
    HelpHeading('INITIAL SETUP & ONBOARDING'),
    HelpHeading('Step 1: Download & Device Requirements'),
    HelpList([
      HelpItem(
        'Fine Aid is built exclusively for Android mobile devices running '
        'modern Android OS versions. (iOS compatibility is not supported in '
        'the current release).',
        label: 'Platform Support',
      ),
    ]),
    HelpHeading('Step 2: Account Registration'),
    HelpList([
      HelpItem(
        'Register with your email address and a secure password. You will '
        'receive a One-Time Password (OTP) for verification. Registering '
        'enables cloud sync across devices and unlocks unlimited journal '
        'savings.',
        label: 'Create an Account',
      ),
    ]),
    HelpHeading('Step 3: Accept Terms, Grant Permissions & Checklist'),
    HelpParagraph('To ensure safety, functionality, and data privacy:'),
    HelpList(numbered: true, [
      HelpItem(
        'Review and accept our terms regarding data handling, secure storage '
        '(powered by Google Firebase), and user safety protocols.',
        label: 'Terms & Privacy Policy',
      ),
      HelpItem(
        'Grant camera permissions when prompted. Camera access is required '
        'strictly for scanning wounds to generate AI first aid guidance.',
        label: 'Camera Access Permission',
      ),
      HelpItem(
        'Complete a brief initial health status checklist. This internal '
        'profile data helps personalize first-aid responses to better align '
        'with your specific health needs.',
        label: 'Health Status Checklist',
      ),
    ]),
    HelpHeading('Step 4: Onboarding Walkthrough'),
    HelpParagraph(
      'Upon opening the app for the first time, you will be guided through '
      'an interactive, highlighted preview.',
    ),
    HelpHeading('EXPLORING CORE FEATURES & DASHBOARD'),
    HelpHeading('AI Vision Camera & Assessment'),
    HelpList([
      HelpItem(
        'Point your camera at a wound or skin condition. The AI evaluates '
        'the image and generates step-by-step first-aid care steps.',
        label: 'Wound, Minor Injury, Skin Issues Scan',
      ),
      HelpItem(
        'If the camera detects multiple distinct injuries (e.g., a scrape '
        'next to a healing scar), the system will prompt you to select which '
        'injury you wish to address.',
        label: 'Multi-Injury Detection',
      ),
      HelpItem(
        'If camera blur or poor lighting affects scan quality, the system '
        'will prompt you to retake the photo.',
        label: 'Retries & Lighting Alerts',
      ),
    ]),
    HelpHeading('Health Journal & Clinical Auto-Referral System'),
    HelpList([
      HelpItem(
        'Log descriptions, pain levels (via an interactive Pain Rating '
        'Scale), and optional recovery photos to track healing progress over '
        'time.',
        label: 'Healing Progress Logs',
      ),
      HelpItem(
        'Submit overall entries to receive automated evaluation feedback.',
        label: 'Pain & Condition Evaluation',
      ),
      HelpItem(
        'The journal monitors your recovery against established clinical '
        'healing timelines. If your condition fails to improve or shows '
        'unexpected worsening, the system automatically triggers an '
        'Auto-Referral Alert, urging you to consult a licensed medical '
        'professional.',
        label: 'Clinical Auto-Referral Notifications',
      ),
      HelpItem(
        'Easily export your complete health journal history to share with '
        'your physician during formal medical consultations.',
        label: 'Export Log for Doctors',
      ),
    ]),
    HelpHeading('Suggested Over the Counter (OTC) Care & Chatbot'),
    HelpList([
      HelpItem(
        'Access non-prescription, safe first-aid care suggestions and '
        'precautions. (Fine Aid does NOT prescribe antibiotics or controlled '
        'medications).',
      ),
      HelpItem(
        'Interact with the in-app AI Chatbot for targeted first-aid '
        'inquiries and medical guide references.',
      ),
    ]),
    HelpHeading('Find Nearby Healthcare Facilities'),
    HelpList([
      HelpItem(
        'View a directory listing nearby hospitals, clinics, and accredited '
        'animal bite centers complete with address details and emergency '
        'contact numbers.',
      ),
    ]),
    HelpHeading('APP LIMITATIONS & SAFETY RULES'),
    HelpParagraph(
      'For your protection, please keep the following operational boundaries '
      'in mind:',
    ),
    HelpList([
      HelpItem(
        'Fine Aid does not diagnose internal medical conditions, chronic '
        'systemic diseases, or severe/life-threatening trauma (such as deep '
        'internal hemorrhaging or organ failure).',
        label: 'No Chronic or Emergency Coverage',
      ),
      HelpItem(
        'The app strictly provides general over-the-counter care tips, basic '
        'cleaning procedures, and first-aid instructions.',
        label: 'Non-Prescriptive Guidance',
      ),
      HelpItem(
        'Always prioritize direct clinical care over app recommendations '
        'whenever severe symptoms, infection signs, or sharp pain persist.',
        label: 'Pre-emptive Professional Care',
      ),
    ]),
  ],
);

const helpPrivacyEn = HelpSection(
  title: 'Privacy Issues',
  blocks: [
    HelpHeading('DATA PRIVACY & PROTECTION POLICY'),
    HelpParagraph(
      'The Fine Aid Development Team is committed to maintaining the highest '
      'standards of data privacy, confidentiality, and security. As Fine Aid '
      'processes user-generated health information, our data management '
      'practices strictly adhere to applicable regulations, including the '
      'Data Privacy Act of 2012 (Republic Act No. 10173) in the Philippines '
      'and global data privacy standards.',
    ),
    HelpParagraph(
      'This Privacy Policy formally details how personal data and sensitive '
      'health records are collected, processed, secured, and retained within '
      'the app.',
    ),
    HelpHeading('Categories of Data Collected & Purpose of Processing'),
    HelpParagraph(
      'To ensure application functionality and personalized guidance, Fine '
      'Aid collects specific categories of user information under defined '
      'lawful bases:',
    ),
    HelpHeading('Account & Identity Management Data'),
    HelpList([
      HelpItem(
        'Personal information, email address, username, and authentication '
        'logs (including One-Time Passwords / OTPs).',
        label: 'Data Types Collected',
      ),
      HelpItem(
        'Account creation, multi-factor identity verification, platform '
        'access control, and account recovery.',
        label: 'Purpose',
      ),
    ]),
    HelpHeading('AI Camera & Visual Data'),
    HelpList([
      HelpItem(
        'Scanned wounds, minor injuries, and skin issues captured using the '
        'device camera.',
        label: 'Data Types Collected',
      ),
      HelpItem(
        'Automated feature analysis to generate step-by-step first aid '
        'recommendations.',
        label: 'Purpose',
      ),
      HelpItem(
        'Captured visual media are processed strictly to furnish immediate '
        'observational feedback. Images are handled in secure environments '
        'and are never exposed publicly or repurposed for commercial '
        'exploitation.',
        label: 'Processing Protocol',
      ),
    ]),
    HelpHeading('Health Journal & Recovery Logs'),
    HelpList([
      HelpItem(
        'Self-reported symptom notes, pain rating, dates and agreement to '
        'track healing progress.',
        label: 'Data Types Collected',
      ),
      HelpItem(
        'To provide users with a personal tracking mechanism to monitor '
        'healing progression over time.',
        label: 'Purpose',
      ),
    ]),
    HelpHeading('Strict Access Control & Database Security'),
    HelpList([
      HelpItem(
        "Security rules enforce strict user-level authorization checks. No "
        "user can access, query, or modify another user's personal profile, "
        'journal entries, or media files.',
      ),
      HelpItem(
        'Database nodes and cloud storage buckets restrict all '
        'non-authenticated or cross-account data operations by default.',
        label: 'Role-Based Permissions',
      ),
    ]),
    HelpHeading('Policy on Data Sharing & Disclosure'),
    HelpParagraph(
      'Fine Aid maintains a strict non-disclosure policy regarding user '
      'information:',
    ),
    HelpList([
      HelpItem(
        'Personal data, health records, and image logs are never sold, '
        'leased, or rented to third-party advertisers, data brokers, or '
        'commercial entities.',
        label: 'Zero Commercialization',
      ),
      HelpItem(
        'Data processing is restricted to secure cloud service providers '
        '(Firebase) bound by strict confidentiality and security agreements.',
        label: 'Third-Party Infrastructure Processors',
      ),
      HelpItem(
        'Personal information may only be disclosed if explicitly mandated '
        'by applicable statutory laws, court orders, or lawful government '
        'directives.',
        label: 'Legal Compliance',
      ),
    ]),
    HelpHeading('Individual Rights & User Control'),
    HelpParagraph(
      'In compliance with statutory data privacy principles, Fine Aid '
      'recognizes and guarantees the following rights for all registered '
      'users:',
    ),
    HelpList(numbered: true, [
      HelpItem(
        'Users retain full visibility over their personal health logs and '
        'profile details stored within the application.',
        label: 'Right to Data Access',
      ),
      HelpItem(
        'Users may initiate an automated account deletion request at any '
        'time. System triggers automatically purge associated user '
        'profiles, Firestore journal documents, and stored media files from '
        'cloud servers.',
        label: 'Right to Erasure (Account & Data Deletion)',
      ),
    ]),
    HelpHeading('Policy Updates & Contact Information'),
    HelpParagraph(
      'We reserve the right to revise this Privacy Policy to align with '
      'technical modifications, legislative changes, or operational '
      'requirements. Notice of material updates will be delivered via in-app '
      'alerts or registered email communications.',
    ),
  ],
);

const helpJournalEn = HelpSection(
  title: 'How to Use Journal?',
  blocks: [
    HelpHeading('HOW TO USE THE HEALTH JOURNAL & PROGRESS TRACKER'),
    HelpParagraph(
      'The Health Journal is your personalized recovery companion. It allows '
      'you to document wound healing, state pain levels, receive automated '
      'progress evaluations, and generate shareable logs for medical '
      'consultations.',
    ),
    HelpHeading('STEP 1: CREATING A NEW JOURNAL ENTRY'),
    HelpList([
      HelpItem(
        'Open the Health Journal icon from the main navigation menu or dashboard.',
      ),
      HelpItem('Tap the "Add Entry +" (New Log) button to create an entry.'),
      HelpItem(
        'Fill in the incident details:',
        children: [
          HelpItem(
            'Write a brief note describing the injury, cause, or current '
            'condition (e.g., "Minor scrape on left knee from bike fall").',
            label: 'Incident Title and Description',
          ),
          HelpItem(
            'Automatically set to the current date and time.',
            label: 'Date & Timestamp',
          ),
          HelpItem(
            'Select the relevant type from the options provided.',
            label: 'Injury Category',
          ),
        ],
      ),
    ]),
    HelpHeading('STEP 2: RATING YOUR PAIN & LOGGING DETAILS'),
    HelpList(numbered: true, [
      HelpItem(
        'Use the built-in Pain Rating Scale (0 to 10) to indicate your '
        'current discomfort level:',
        label: 'Interactive Pain Rating Scale',
        children: [
          HelpItem(
            'Fully comfortable, no lingering soreness.',
            label: '0 – No Pain',
          ),
          HelpItem(
            'Minor discomfort, easily ignored.',
            label: '1–4 – Mild Pain',
          ),
          HelpItem(
            'Noticeable pain that interferes slightly with daily tasks.',
            label: '5–7 – Moderate Pain',
          ),
          HelpItem(
            'Intense or throbbing pain requiring immediate rest or '
            'professional medical attention.',
            label: '8–10 – Severe Pain',
          ),
        ],
      ),
      HelpItem(
        'Tap "Add Images" to capture a current picture of your wound. Adding '
        'progress photos over multiple days creates a visual timeline that '
        'helps you and healthcare professionals evaluate healing speed and '
        'identify potential complications early.',
        label: 'Attaching Progress Photos (Online & Guest Modes)',
      ),
      HelpItem(
        'Tap the "Remind Me" toggle to receive a notification when your '
        'healing progress reaches the expected healing time, based on Time '
        'to Heal (TTH) in wound care.',
      ),
    ]),
    HelpParagraph(
      'Guest Mode requires you to register an account to save journal '
      'entries. Offline Mode supports text and pain scale entries only.',
      label: 'Note',
    ),
    HelpHeading('STEP 3: SUBMITTING FOR AUTOMATED EVALUATION'),
    HelpParagraph(
      'Once you submit your journal entry, Fine Aid processes your inputs '
      'against established clinical recovery timelines:',
    ),
    HelpList([
      HelpItem(
        'The app analyzes your self-reported notes, pain rating, and time '
        'elapsed to provide a general progress evaluation (e.g., "On Track," '
        '"Delayed Healing," or "Further Care Advised").',
        label: 'Evaluation Summary',
      ),
      HelpItem(
        'Submitted entries automatically pin to your Calendar Dashboard, '
        'making it easy to review your healing history by date.',
        label: 'Calendar Integration',
      ),
    ]),
    HelpHeading('UNDERSTANDING AUTO-REFERRAL ALERTS'),
    HelpParagraph('', label: 'How Auto-Referral Works:'),
    HelpList([
      HelpItem(
        'An Auto-Referral Alert is triggered when:',
        children: [
          HelpItem(
            'Your logged pain rating is high.',
            label: 'Escalating Pain',
          ),
          HelpItem(
            'Your inputs indicate symptoms such as spreading redness, '
            'persistent swelling, or abnormal discharge.',
            label: 'Signs of Complication',
          ),
          HelpItem(
            'The wound shows no measurable signs of healing beyond expected '
            'clinical timeframes.',
            label: 'Delayed Recovery',
          ),
        ],
      ),
      HelpItem(
        'You will receive a notification advising you to seek a formal '
        'consultation with a licensed healthcare professional.',
        label: 'System Action',
      ),
    ]),
    HelpCallout(
      'Tip: Auto-referral notifications are designed to catch complications '
      'early. If you receive an alert, do not delay seeking medical care.',
    ),
    HelpHeading('EXPORTING LOGS FOR MEDICAL CONSULTATIONS'),
    HelpParagraph(
      'When visiting a doctor or clinic, you can share your complete journal '
      'history directly:',
    ),
    HelpList(numbered: true, [
      HelpItem('Tap "Export Log".'),
      HelpItem(
        'Export a formatted PDF / Digital Summary containing your incident '
        'notes, pain score, and timestamps to present to your healthcare '
        'provider.',
      ),
    ]),
    HelpHeading('QUICK TIPS FOR BEST RESULTS'),
    HelpList([
      HelpItem(
        'Record updates at the same time each day (e.g., during daily '
        'dressing changes) for accurate progress tracking.',
        label: 'Log Accurately and Consistently',
      ),
      HelpItem(
        'Accurate pain ratings help the auto-referral system detect '
        'unexpected inflammation or infection early.',
        label: 'Be Honest with Pain Scores',
      ),
      HelpItem(
        'Ensure you are signed in so your journal data is backed up to '
        'secure cloud storage (via Google Firebase) and available if you '
        'switch devices.',
        label: 'Account Syncing',
      ),
    ]),
  ],
);

const helpReferencesEn = HelpSection(
  title: 'References',
  blocks: [
    HelpHeading('REFERENCES & MEDICAL VALIDATION'),
    HelpParagraph('', label: 'Our Commitment to Medical Validity & Safety:'),
    HelpParagraph(
      'To ensure that Fine Aid delivers accurate, safe, and evidence-based '
      'guidance, every first-aid instruction, wound-care workflow, and '
      'health recommendation embedded in our system is cross-referenced '
      'against globally and nationally recognized medical authorities. Our '
      'core repository synthesizes standard protocols established by the '
      'World Health Organization (WHO), the International Federation of Red '
      'Cross and Red Crescent Societies (IFRC / Philippine Red Cross), MIMS '
      'Philippines, and local regulatory bodies including the Department of '
      'Health (DOH - Philippines).',
    ),
    HelpParagraph(
      'Beyond digital sourcing, every piece of clinical guidance, algorithm '
      'logic, and home-care recommendation undergoes manual review by an '
      'advisory panel of licensed medical professionals and board-certified '
      'specialists. This dual-layer validation process guarantees that users '
      'receive safe, up-to-date interventions while actively protecting them '
      'from hazardous online medical myths and unverified home remedies.',
    ),
    HelpHeading('CERTIFICATIONS AND UPDATES'),
    HelpParagraph(
      'Medical knowledge and clinical best practices continuously evolve. To '
      'maintain compliance and clinical accuracy, our medical content '
      'repository and underlying guidance models undergo quarterly reviews. '
      'This ensures strict conformity with the latest updated guidelines '
      'issued by national health authorities and global medical '
      'institutions.',
    ),
    HelpHeading('VERIFIED MEDICAL SOURCES'),
    HelpGroup('World Health Organization (WHO)', [
      HelpHeading('Background & Founding'),
      HelpParagraph(
        'Founded on April 7, 1948, the World Health Organization (WHO) was '
        'established as the specialized United Nations agency dedicated to '
        'directing and coordinating international public health. Formed '
        'following WWII to unify global medical responses, WHO operates '
        'across 194 Member States to expand health coverage, direct '
        'responses to health emergencies, and establish scientific health '
        'standards worldwide.',
      ),
      HelpHeading('Core Purpose'),
      HelpParagraph(
        'To champion the right to health for all individuals, promote '
        'healthy living, prevent disease, and coordinate global emergency '
        'medical responses based on rigorous scientific research.',
      ),
      HelpHeading('Role in Fine Aid'),
      HelpParagraph(
        "WHO's international clinical guidelines serve as the baseline "
        "foundation for Fine Aid's core first-aid decision trees, infection "
        'prevention procedures, and basic hygiene protocols.',
      ),
    ]),
    HelpGroup('Philippine Red Cross (PRC)', [
      HelpHeading('Background & Founding'),
      HelpParagraph(
        "Rooted in history starting with the Malolos Republic's Red Cross "
        'movement in 1899, the official Philippine Red Cross was formally '
        'established by Republic Act No. 95 on April 15, 1947. It emerged '
        "following Philippine independence to serve as the nation's premier "
        'voluntary humanitarian organization.',
      ),
      HelpHeading('Core Purpose'),
      HelpParagraph(
        'To act as an auxiliary to government authorities during disasters, '
        'medical crises, and humanitarian emergencies. PRC provides blood '
        'services, community health training, disaster management, and '
        'community-level first-aid guidance.',
      ),
      HelpHeading('Role in Fine Aid'),
      HelpParagraph(
        "Fine Aid's step-by-step physical first-aid guides, such as "
        'managing cuts, heat burns, and bandaging instructions, are '
        'structured around established Red Cross emergency response '
        'workflows.',
      ),
    ]),
    HelpGroup('Monthly Index of Medical Specialties (MIMS) Philippines', [
      HelpHeading('Background & Founding'),
      HelpParagraph(
        'Established in 1963, MIMS has grown over six decades from a '
        'printed pharmaceutical reference into the leading digital medical '
        'and drug information hub serving healthcare professionals across '
        'the Asia-Pacific region.',
      ),
      HelpHeading('Core Purpose'),
      HelpParagraph(
        'To provide verified, evidence-based pharmaceutical data, drug '
        'interactions, clinical treatment guides, and over the counter '
        '(OTC) care information trusted by doctors, nurses, and '
        'pharmacists.',
      ),
      HelpHeading('Role in Fine Aid'),
      HelpParagraph(
        'Fine Aid uses MIMS Philippines as its primary reference for '
        'validating safe, non-prescription Over the Counter (OTC) care '
        'suggestions, safety precautions, and non-prescriptive home '
        'cleaning procedures.',
      ),
    ]),
    HelpGroup('Department of Health (DOH - Philippines)', [
      HelpHeading('Background & Founding'),
      HelpParagraph(
        'Tracing its origins back to the creation of the Department of '
        'Public Works, Education, and Hygiene in June 1898 under President '
        'Emilio Aguinaldo, the agency evolved into the Department of '
        'Health and Public Welfare in 1941 and was formally reconstituted '
        'post-war as the Department of Health (DOH) in 1947.',
      ),
      HelpHeading('Core Purpose'),
      HelpParagraph(
        'As the executive department of the Philippine government '
        'responsible for public health, DOH ensures access to basic public '
        'health services, regulates health facilities, and formulates '
        'national disease prevention policies.',
      ),
      HelpHeading('Role in Fine Aid'),
      HelpParagraph(
        "DOH guidelines inform Fine Aid's localized medical paths, and "
        'localized disease symptom advisories.',
      ),
    ]),
    HelpGroup('Doctor-Reviewed Content & Clinical Governance', [
      HelpHeading('Oversight & Clinical Governance Overview'),
      HelpParagraph(
        'To maintain the highest standards of safety, accuracy, and user '
        'trust, Fine Aid operates under a structured Clinical Governance '
        'Framework. Every piece of health guidance, first-aid instruction, '
        'and AI-driven assessment logic embedded within the application '
        'undergoes continuous medical review. This human-in-the-loop '
        'oversight ensures that digital health recommendations strictly '
        'align with real-world clinical standards and safe medical '
        'practices.',
      ),
      HelpHeading('Key Governance Pillars'),
      HelpHeading('1. Expert Advisory Panel & Continuous Medical Review'),
      HelpList([
        HelpItem(
          'All underlying clinical rules, first-aid step sequences, health '
          'checklists, and AI Camera decision pathways are evaluated and '
          'vetted by licensed physicians and board-certified medical '
          'specialists.',
          label: 'Multidisciplinary Evaluation',
        ),
        HelpItem(
          'Before any algorithmic rule or first-aid recommendation is '
          'pushed live to the mobile application, it must pass a formal '
          'safety audit conducted by our medical advisory team.',
          label: 'Pre-Deployment Auditing',
        ),
        HelpItem(
          "The advisory panel reviews wound, minor injuries and skin issues "
          "assessments to refine the system's logic and prevent misleading "
          'or inaccurate guidance.',
          label: 'Error Prevention & Refinement',
        ),
      ]),
      HelpHeading('2. Safe Intervention Thresholds & AI Risk Guardrails'),
      HelpList([
        HelpItem(
          "Fine Aid's medical team enforces technical guardrails on all AI "
          'vision outputs. The application is explicitly restricted from '
          'diagnosing chronic conditions, prescribing prescription '
          'medications (such as antibiotics or specialized topicals), or '
          'simulating clinical treatment plans.',
          label: 'Strict Non-Diagnostic Boundaries',
        ),
        HelpItem(
          'The algorithm is programmed with conservative safety '
          'thresholds. If an analyzed injury or logged symptom exhibits '
          'signs of severity (e.g., suspected deep lacerations, arterial '
          'bleeding, third-degree burns, or infection markers), the system '
          'immediately halts routine first-aid output.',
          label: 'Early High-Risk Detection',
        ),
        HelpItem(
          'When high-risk indicators or escalating pain trends are '
          'detected, the system automatically displays priority warnings '
          'and directs the user to seek immediate emergency medical care '
          'or visit the nearest healthcare facility.',
          label: 'Urgent Care Redirection',
        ),
      ]),
      HelpHeading('3. Multi-Layer & Two-Tier Validation Process'),
      HelpParagraph(
        'Fine Aid employs a two-tiered validation framework for all health '
        'content and decision logic:',
      ),
      HelpList([
        HelpItem(
          'Every initial protocol is researched and cross-referenced '
          'directly against peer-reviewed medical literature and '
          'established national/international databases (including the '
          'WHO, Philippine Red Cross, MIMS Philippines, and DOH).',
          label: 'Tier 1: Scientific & Literature Verification',
        ),
        HelpItem(
          'Following literature verification, evaluating healthcare '
          'professionals conduct a manual review of the digital workflows. '
          'This ensures that the academic guidelines are translated into '
          'clear, safe, and practical steps that an untrained user can '
          'safely perform during an emergency.',
          label: 'Tier 2: Manual Physician Review',
        ),
      ]),
      HelpHeading('Ongoing Clinical Auditing & Quality Assurance'),
      HelpList([
        HelpItem(
          "Clinical governance is an ongoing process. Our medical advisors "
          "review the app's decision parameters periodically to ensure "
          'alignment with updated medical research, revised national '
          'health advisories, and evolving emergency care standards.',
          label: 'Regular Framework Reviews',
        ),
        HelpItem(
          'By establishing clear lines of clinical review, Fine Aid '
          'provides users and academic panels with full transparency '
          'regarding how health information is verified, maintained, and '
          'safely delivered.',
          label: 'Transparency & Accountability',
        ),
      ]),
    ]),
  ],
);
