import 'package:flutter/widgets.dart';
import 'app_language.dart';

/// Text that used to be written straight into screens in English only
/// (buttons, messages, field labels), so it did not change with Settings >
/// Language. Titles are not here on purpose: they stay in English. English is
/// the original wording, unchanged. Review the Tagalog before release.
class ScreenText {
  // ---- shared ----
  final String cancel;
  final String retry;
  final String save;
  final String delete;
  final String submit;
  final String ok;
  final String register;
  final String logIn;
  final String createAccount;
  final String continueAsGuest;
  final String notNow;
  final String signUp;
  final String somethingWentWrong;
  final String notSignedIn;

  // ---- welcome screen and dashboard banner ----
  final String tagline;
  final String or;
  final String offlineBannerTitle;
  final String offlineBannerBody;
  final String guestBannerTitle;
  final String guestBannerBody;
  final String guestBannerLink;
  final String welcomeTitle;
  final String welcomeBody;
  final String offlineCameraBody;
  final String firstAidKit;
  final String goBack;

  // ---- sign in, sign up, forgot password, verification ----
  final String username;
  final String password;
  final String keepSignedIn;
  final String verifyVia;
  final String sendCodeVia;
  final String sendResetCode;
  final String verificationCode;
  final String newPassword;
  final String confirmNewPassword;
  final String resetPassword;
  final String startOver;
  final String backToLogin;
  final String saveAndResend;
  final String wrongNumberEdit;
  final String updatingPhone;

  // ---- camera and assessment ----
  final String flashlightUnavailable;
  final String couldNotCapture;
  final String offlineAiBody;
  final String offlineFirstAidKit;
  final String blurryBody;
  final String imageUnclearTitle;
  final String imageUnclearBody;
  final String imageCheckFailedTitle;
  final String imageCheckFailedBody;
  final String retakePhoto;
  final String noWoundMarkBody;
  final String noWoundBody;
  final String lowConfidenceBody;
  final String offlineKit;
  final String retake;
  final String assessmentSaved;
  final String journalEntryUpdated;
  final String couldNotSaveJournal;
  final String couldNotOpenDialer911;
  final String callEmergency;
  final String analyzingWound;
  final String useOfflineKit;
  final String findNearbyHealthcare;

  // ---- notifications, journal ----
  final String needMoreHelp;
  final String openJournalEntry;
  final String deleteEntryBody;
  final String couldNotDeleteEntry;
  final String addEntry;
  final String classification;
  final String exportLog;
  final String signUpShort;
  final String sessionSaved;

  // ---- profile and feedback ----
  final String passwordVerified;
  final String incorrectCurrentPassword;
  final String couldNotVerifyPassword;
  final String usernameTaken;
  final String profileUpdated;
  final String emailTaken;
  final String phoneTaken;
  final String email;
  final String writeFeedbackFirst;
  final String couldNotSubmitFeedback;
  final String yourFeedback;
  final String submitFeedback;
  final String thankYou;
  final String done;

  // ---- guest dialogs ----
  final String guestSaveBody;
  final String guestLimitBody;

  // ---- nearby healthcare ----
  final String category;
  final String allCategories;
  final String searchHint;
  final String noFacilitiesInCategory;
  final String noFacilitiesMatch; // uses {query}
  final String directoryNote;
  final String couldNotOpenDialer; // uses {number}

  // ---- Health Journal banner, AI result, multiple injuries ----
  final String journalBannerTitle;
  final String journalBannerSubtitle;
  final String firstAidStepsTitle;
  final String uncertainDetails;
  final String disclaimerTitle;
  final String disclaimerBody;
  final String disclaimerShort;
  final String categoryLabel;
  final String seekEmergency;
  final String seekUrgent;
  final String professionalEval;
  final String followUpLabel;
  final String describeHint;
  final String saveToJournal;
  final String updateJournal;
  final String saving;
  final String savedToJournal;
  final String analysisTip;
  final String noWoundTitle;
  final String multipleInjuries;
  final String multiTip;
  final String noneOfThese;
  final String noneChosenNote;
  // "Done" on the AI scan result.
  final String doneConfirmTitle;
  final String doneConfirmBody;
  final String doneSaveToJournal;
  final String doneDontSave;
  final String journalEmpty;
  final String woundN;
  final String selectedWound;
  final String selectWound;
  final String assessSelected;
  final String couldNotTranslate;

  // The AI Vision Camera's medical disclaimer.
  final String cameraDisclaimerTitle;
  final String cameraDisclaimerBody;

  // The landing page's offline prompt.
  final String offlineTitle;
  final String offlineEntryBody;
  final String proceedOffline;
  final String tryAgain;
  final String stillOffline;

  const ScreenText({
    required this.cancel,
    required this.retry,
    required this.save,
    required this.delete,
    required this.submit,
    required this.ok,
    required this.register,
    required this.logIn,
    required this.createAccount,
    required this.continueAsGuest,
    required this.notNow,
    required this.signUp,
    required this.somethingWentWrong,
    required this.notSignedIn,
    required this.tagline,
    required this.or,
    required this.offlineBannerTitle,
    required this.offlineBannerBody,
    required this.guestBannerTitle,
    required this.guestBannerBody,
    required this.guestBannerLink,
    required this.welcomeTitle,
    required this.welcomeBody,
    required this.offlineCameraBody,
    required this.firstAidKit,
    required this.goBack,
    required this.username,
    required this.password,
    required this.keepSignedIn,
    required this.verifyVia,
    required this.sendCodeVia,
    required this.sendResetCode,
    required this.verificationCode,
    required this.newPassword,
    required this.confirmNewPassword,
    required this.resetPassword,
    required this.startOver,
    required this.backToLogin,
    required this.saveAndResend,
    required this.wrongNumberEdit,
    required this.updatingPhone,
    required this.flashlightUnavailable,
    required this.couldNotCapture,
    required this.offlineAiBody,
    required this.offlineFirstAidKit,
    required this.blurryBody,
    required this.imageUnclearTitle,
    required this.imageUnclearBody,
    required this.imageCheckFailedTitle,
    required this.imageCheckFailedBody,
    required this.retakePhoto,
    required this.noWoundMarkBody,
    required this.noWoundBody,
    required this.lowConfidenceBody,
    required this.offlineKit,
    required this.retake,
    required this.assessmentSaved,
    required this.journalEntryUpdated,
    required this.couldNotSaveJournal,
    required this.couldNotOpenDialer911,
    required this.callEmergency,
    required this.analyzingWound,
    required this.useOfflineKit,
    required this.findNearbyHealthcare,
    required this.needMoreHelp,
    required this.openJournalEntry,
    required this.deleteEntryBody,
    required this.couldNotDeleteEntry,
    required this.addEntry,
    required this.classification,
    required this.exportLog,
    required this.signUpShort,
    required this.sessionSaved,
    required this.passwordVerified,
    required this.incorrectCurrentPassword,
    required this.couldNotVerifyPassword,
    required this.usernameTaken,
    required this.profileUpdated,
    required this.emailTaken,
    required this.phoneTaken,
    required this.email,
    required this.writeFeedbackFirst,
    required this.couldNotSubmitFeedback,
    required this.yourFeedback,
    required this.submitFeedback,
    required this.thankYou,
    required this.done,
    required this.guestSaveBody,
    required this.guestLimitBody,
    required this.category,
    required this.allCategories,
    required this.searchHint,
    required this.noFacilitiesInCategory,
    required this.noFacilitiesMatch,
    required this.directoryNote,
    required this.couldNotOpenDialer,
    required this.journalBannerTitle,
    required this.journalBannerSubtitle,
    required this.firstAidStepsTitle,
    required this.uncertainDetails,
    required this.disclaimerTitle,
    required this.disclaimerBody,
    required this.disclaimerShort,
    required this.categoryLabel,
    required this.seekEmergency,
    required this.seekUrgent,
    required this.professionalEval,
    required this.followUpLabel,
    required this.describeHint,
    required this.saveToJournal,
    required this.updateJournal,
    required this.saving,
    required this.savedToJournal,
    required this.analysisTip,
    required this.noWoundTitle,
    required this.multipleInjuries,
    required this.multiTip,
    required this.noneOfThese,
    required this.noneChosenNote,
    required this.doneConfirmTitle,
    required this.doneConfirmBody,
    required this.doneSaveToJournal,
    required this.doneDontSave,
    required this.journalEmpty,
    required this.woundN,
    required this.selectedWound,
    required this.selectWound,
    required this.assessSelected,
    required this.couldNotTranslate,
    required this.cameraDisclaimerTitle,
    required this.cameraDisclaimerBody,
    required this.offlineTitle,
    required this.offlineEntryBody,
    required this.proceedOffline,
    required this.tryAgain,
    required this.stillOffline,
  });

  /// The wound type as shown to the person: the Tagalog name when the app
  /// is in Tagalog (the English name is what is saved and matched on).
  String categoryName(String category) =>
      identical(this, tl) ? (_tlCategories[category] ?? category) : category;

  static const Map<String, String> _tlCategories = {
    'Laceration': 'Malalim na Hiwa',
    'Minor Cut': 'Maliit na Hiwa',
    'Scratch': 'Kalmot',
    'Abrasion': 'Gasgas',
    'Puncture Wound': 'Tusok na Sugat',
    'Burn': 'Paso',
    'Bruise': 'Pasa',
    'Swelling': 'Pamamaga',
    'Rash': 'Pantal',
    'Other Skin Issue': 'Ibang Problema sa Balat',
    'Unable to Classify': 'Hindi Matukoy ang Uri',
  };

  static ScreenText of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  static ScreenText forLanguage(AppLanguage language) =>
      language == AppLanguage.tl ? tl : en;

  static const en = ScreenText(
    cancel: 'Cancel',
    retry: 'Retry',
    save: 'Save',
    delete: 'Delete',
    submit: 'Submit',
    ok: 'OK',
    register: 'Register',
    logIn: 'Log In',
    createAccount: 'Create Account',
    continueAsGuest: 'Continue as Guest',
    notNow: 'Not now',
    signUp: 'Sign Up',
    somethingWentWrong: 'Something went wrong. Please try again.',
    notSignedIn: 'Not signed in',
    tagline: 'Your Smart First-Aid Assistance',
    or: 'or',
    offlineBannerTitle: 'You\'re currently offline',
    offlineBannerBody: 'Continue tracking and viewing guides without internet.',
    guestBannerTitle: 'Welcome to Guest Mode',
    guestBannerBody: 'Register for full access to features with no limitation.',
    guestBannerLink: 'Sign in and login your account. Register here',
    welcomeTitle: 'Welcome!',
    welcomeBody:
        'Stay safe and ready with Fine Aid. Your guide for reliable first '
        'aid and tracking your recovery.',
    offlineCameraBody:
        'AI Camera requires an internet connection. Check your connection '
        'and try again, or use the offline First Aid Health Kit instead.',
    firstAidKit: 'First Aid Kit',
    goBack: 'Go Back',
    username: 'Username',
    password: 'Password',
    keepSignedIn: 'Keep me signed in',
    verifyVia: 'Verify my account via',
    sendCodeVia: 'Send code via',
    sendResetCode: 'Send Reset Code',
    verificationCode: 'Verification Code',
    newPassword: 'New Password',
    confirmNewPassword: 'Confirm New Password',
    resetPassword: 'Reset Password',
    startOver: 'Start over',
    backToLogin: 'Back to Login',
    saveAndResend: 'Save & Resend',
    wrongNumberEdit: 'Wrong number? Edit',
    updatingPhone: 'Updating phone number...',
    flashlightUnavailable: 'Flashlight is not available on this camera.',
    couldNotCapture: 'Could not capture image. Please try again.',
    offlineAiBody:
        'AI wound analysis requires an internet connection. Please check '
        'your connection and try again, or use the offline First Aid Health '
        'Kit instead.',
    offlineFirstAidKit: 'Offline First Aid Kit',
    blurryBody:
        'This photo is too blurry to assess safely. Please ensure the area '
        'is well-lit and your camera is in focus, hold steady, and try '
        'again.',
    imageUnclearTitle: 'Image Is Unclear',
    imageUnclearBody:
        'Image is unclear. Please retake the photo in good lighting.',
    imageCheckFailedTitle: 'Could Not Check the Image',
    imageCheckFailedBody:
        'The photo could not be checked just now, so it was not analyzed. '
        'Please check your connection and try again.',
    retakePhoto: 'Retake Photo',
    noWoundMarkBody:
        'Fine Aid could not confirm a real wound or skin condition in this '
        'image — the mark shown may not be an actual injury (eg, a drawing, '
        'marking, or something else on the skin). Please retake a photo of a '
        'real wound or skin issue if you have one.',
    noWoundBody:
        'Fine Aid could not detect a wound or skin condition in this image. '
        'Please retake a clearer photo of the affected area.',
    lowConfidenceBody:
        'This image is too unclear or ambiguous for Fine Aid to confidently '
        'identify a wound. To avoid misleading guidance, we won\'t proceed '
        'with this photo. Please retake a clearer photo, or use the offline '
        'First Aid Health Kit.',
    offlineKit: 'Offline Kit',
    retake: 'Retake',
    assessmentSaved: 'Assessment saved to Health Journal.',
    journalEntryUpdated: 'Journal entry updated.',
    couldNotSaveJournal: 'Could not save to journal. Please try again.',
    couldNotOpenDialer911:
        'Could not open the dialer. Please call 911 directly.',
    callEmergency: 'Call Emergency Services (911)',
    analyzingWound: 'Analyzing your wound...',
    useOfflineKit: 'Use Offline First Aid Health Kit',
    findNearbyHealthcare: 'Find Nearby Healthcare',
    needMoreHelp: 'Need More Help',
    openJournalEntry: 'Open journal entry',
    deleteEntryBody: 'Are you sure you want to delete this entry?',
    couldNotDeleteEntry: 'Could not delete entry. Please try again.',
    addEntry: 'Add Entry',
    classification: 'Classification: ',
    exportLog: 'Export Log',
    signUpShort: 'Sign up',
    sessionSaved: 'Session saved to Health Journal.',
    passwordVerified: 'Password verified. You can now set a new password.',
    incorrectCurrentPassword: 'Current password is incorrect',
    couldNotVerifyPassword: 'Could not verify your password. Please try again.',
    usernameTaken: 'That username is already taken.',
    profileUpdated: 'Profile updated successfully.',
    emailTaken: 'This email is already registered.',
    phoneTaken: 'This phone number is already registered.',
    email: 'Email',
    writeFeedbackFirst: 'Please write some feedback before submitting.',
    couldNotSubmitFeedback: 'Could not submit feedback. Please try again.',
    yourFeedback: 'Your feedback',
    submitFeedback: 'Submit Feedback',
    thankYou: 'Thank you!',
    done: 'Done',
    guestSaveBody: 'You need to register or log in to save this entry.',
    guestLimitBody:
        'You\'ve reached today\'s limit for guests. Register or log in for '
        'unlimited use, or try again tomorrow.',
    category: 'Category',
    allCategories: 'All Categories',
    searchHint: 'Search by name or area...',
    noFacilitiesInCategory: 'No facilities in this category.',
    noFacilitiesMatch: 'No facilities match "{query}".',
    directoryNote:
        'Directory data may change — call ahead to confirm before traveling, '
        'and use emergency services directly for urgent situations.',
    couldNotOpenDialer: 'Could not open the dialer for {number}.',
    journalBannerTitle: 'Health Journal',
    journalBannerSubtitle:
        'A Self-Monitoring Guide with an Auto-Referral System for Healing Duration Reminders',
    firstAidStepsTitle: 'First Aid Steps',
    uncertainDetails: 'Some details were unclear from this photo: {details}.',
    disclaimerTitle: 'Disclaimer',
    disclaimerBody:
        'This is an AI-generated preliminary assessment, not a medical diagnosis. Always use your own judgment and seek professional care when in doubt.',
    disclaimerShort:
        'For initial assessment only. Not a diagnostic tool. Seek professional help.',
    categoryLabel: 'Category: {category}',
    seekEmergency: 'Seek Emergency Care Immediately',
    seekUrgent: 'Seek Urgent Medical Care',
    professionalEval: 'Professional Evaluation Recommended',
    followUpLabel: 'Ask a follow-up question',
    describeHint: 'Describe your concern...',
    saveToJournal: 'Save to Health Journal',
    updateJournal: 'Update Journal Entry',
    saving: 'Saving...',
    savedToJournal: 'Saved to Health Journal',
    analysisTip:
        'Tip: Ensure the wound is well-lit and clearly visible for the most accurate assessment.',
    noWoundTitle: 'No Wound Detected',
    multipleInjuries: 'Multiple injuries detected',
    multiTip: 'Tap the wound you want to focus on for assessment.',
    noneOfThese: 'None',
    noneChosenNote: 'Nothing was assessed. You can scan again any time.',
    doneConfirmTitle: 'Are you done with this assessment?',
    doneConfirmBody:
        'You can save it to your Health Journal to keep track of your '
        'recovery.',
    doneSaveToJournal: 'Save to Health Journal',
    doneDontSave: 'Don\'t save',
    journalEmpty:
        'No journal entries yet. Tap "Add Entry" to start tracking your '
        'recovery.',
    woundN: 'Wound {n}',
    selectedWound: 'Selected: {label}',
    selectWound: 'Select a wound to continue',
    assessSelected: 'Assess Selected Wound',
    couldNotTranslate: 'Couldn\'t translate right now — showing English.',
    cameraDisclaimerTitle: 'Medical Disclaimer',
    cameraDisclaimerBody:
        'This is only for initial assessment and not for diagnosis. '
        'Seek professional help.',
    offlineTitle: 'No Internet Connection',
    offlineEntryBody:
        'You’re currently offline. You can still use limited features in '
        'Offline Mode.',
    proceedOffline: 'Proceed to Offline Mode',
    tryAgain: 'Try Again',
    stillOffline: 'Still no internet connection.',
  );

  static const tl = ScreenText(
    cancel: 'Kanselahin',
    retry: 'Subukang Muli',
    save: 'I-save',
    delete: 'Burahin',
    submit: 'Isumite',
    ok: 'OK',
    register: 'Mag-register',
    logIn: 'Mag-log In',
    createAccount: 'Gumawa ng Account',
    continueAsGuest: 'Magpatuloy bilang Bisita',
    notNow: 'Hindi muna',
    signUp: 'Mag-sign Up',
    somethingWentWrong: 'May nangyaring mali. Pakisubukang muli.',
    notSignedIn: 'Hindi naka-sign in',
    tagline: 'Ang Iyong Matalinong Katulong sa First Aid',
    or: 'o',
    offlineBannerTitle: 'Offline ka ngayon',
    offlineBannerBody:
        'Maaari mong ipagpatuloy ang pagsubaybay at pagtingin ng mga gabay '
        'kahit walang internet.',
    guestBannerTitle: 'Maligayang pagdating sa Guest Mode',
    guestBannerBody:
        'Mag-register para magamit ang lahat ng feature nang walang '
        'limitasyon.',
    guestBannerLink:
        'Mag-sign in at mag-log in sa iyong account. '
        'Mag-register dito',
    welcomeTitle: 'Maligayang pagdating!',
    welcomeBody:
        'Manatiling ligtas at handa sa Fine Aid. Ang iyong gabay sa '
        'maaasahang first aid at sa pagsubaybay ng iyong paggaling.',
    offlineCameraBody:
        'Kailangan ng AI Camera ang koneksyon sa internet. Tingnan ang '
        'iyong koneksyon at subukang muli, o gamitin ang offline First Aid '
        'Health Kit.',
    firstAidKit: 'First Aid Kit',
    goBack: 'Bumalik',
    username: 'Username',
    password: 'Password',
    keepSignedIn: 'Panatilihin akong naka-sign in',
    verifyVia: 'I-verify ang aking account sa pamamagitan ng',
    sendCodeVia: 'Ipadala ang code sa pamamagitan ng',
    sendResetCode: 'Ipadala ang Reset Code',
    verificationCode: 'Verification Code',
    newPassword: 'Bagong Password',
    confirmNewPassword: 'Kumpirmahin ang Bagong Password',
    resetPassword: 'I-reset ang Password',
    startOver: 'Magsimulang muli',
    backToLogin: 'Bumalik sa Login',
    saveAndResend: 'I-save at Ipadalang Muli',
    wrongNumberEdit: 'Maling numero? I-edit',
    updatingPhone: 'Ina-update ang numero ng telepono...',
    flashlightUnavailable: 'Walang flashlight ang camera na ito.',
    couldNotCapture: 'Hindi nakuha ang larawan. Pakisubukang muli.',
    offlineAiBody:
        'Kailangan ng AI wound analysis ang koneksyon sa internet. Tingnan '
        'ang iyong koneksyon at subukang muli, o gamitin ang offline First '
        'Aid Health Kit.',
    offlineFirstAidKit: 'Offline First Aid Kit',
    blurryBody:
        'Masyadong malabo ang larawang ito para masuri nang ligtas. '
        'Siguraduhing maliwanag ang lugar at nakatutok ang camera, '
        'panatilihing steady ang kamay, at subukang muli.',
    imageUnclearTitle: 'Hindi Malinaw ang Larawan',
    imageUnclearBody:
        'Hindi malinaw ang larawan. Pakikuha ulit ang larawan sa magandang '
        'liwanag.',
    imageCheckFailedTitle: 'Hindi Masuri ang Larawan',
    imageCheckFailedBody:
        'Hindi nasuri ang larawan ngayon, kaya hindi ito na-analyze. '
        'Tingnan ang iyong koneksyon at subukang muli.',
    retakePhoto: 'Kumuha Ulit ng Larawan',
    noWoundMarkBody:
        'Hindi makumpirma ng Fine Aid ang tunay na sugat o kondisyon ng '
        'balat sa larawang ito — maaaring hindi totoong pinsala ang '
        'markang nakikita (hal., drawing, marka, o iba pang nasa balat). '
        'Kumuha ulit ng larawan ng tunay na sugat o problema sa balat kung '
        'mayroon ka.',
    noWoundBody:
        'Walang nakitang sugat o kondisyon ng balat ang Fine Aid sa '
        'larawang ito. Kumuha ulit ng mas malinaw na larawan ng apektadong '
        'bahagi.',
    lowConfidenceBody:
        'Masyadong malabo o malabo ang kahulugan ng larawang ito para '
        'makilala nang may kumpiyansa ng Fine Aid ang sugat. Para hindi '
        'makapagbigay ng nakalilitong gabay, hindi kami magpapatuloy sa '
        'larawang ito. Kumuha ulit ng mas malinaw na larawan, o gamitin ang '
        'offline First Aid Health Kit.',
    offlineKit: 'Offline Kit',
    retake: 'Kumuha Ulit',
    assessmentSaved: 'Na-save ang pagsusuri sa Health Journal.',
    journalEntryUpdated: 'Na-update ang journal entry.',
    couldNotSaveJournal: 'Hindi na-save sa journal. Pakisubukang muli.',
    couldNotOpenDialer911:
        'Hindi mabuksan ang dialer. Direktang tumawag sa 911.',
    callEmergency: 'Tumawag sa Emergency Services (911)',
    analyzingWound: 'Sinusuri ang iyong sugat...',
    useOfflineKit: 'Gamitin ang Offline First Aid Health Kit',
    findNearbyHealthcare: 'Maghanap ng Malapit na Pasilidad',
    needMoreHelp: 'Kailangan ng Dagdag na Tulong',
    openJournalEntry: 'Buksan ang journal entry',
    deleteEntryBody: 'Sigurado ka bang gusto mong burahin ang entry na ito?',
    couldNotDeleteEntry: 'Hindi nabura ang entry. Pakisubukang muli.',
    addEntry: 'Magdagdag ng Entry',
    classification: 'Klasipikasyon: ',
    exportLog: 'I-export ang Log',
    signUpShort: 'Mag-sign up',
    sessionSaved: 'Na-save ang session sa Health Journal.',
    incorrectCurrentPassword: 'Maling kasalukuyang password',
    passwordVerified:
        'Na-verify ang password. Maaari ka nang magtakda ng bagong '
        'password.',
    couldNotVerifyPassword:
        'Hindi ma-verify ang iyong password. Pakisubukang muli.',
    usernameTaken: 'May gumagamit na ng username na iyon.',
    profileUpdated: 'Matagumpay na na-update ang profile.',
    emailTaken: 'Naka-register na ang email na ito.',
    phoneTaken: 'Naka-register na ang numero ng telepono na ito.',
    email: 'Email',
    writeFeedbackFirst: 'Magsulat muna ng feedback bago isumite.',
    couldNotSubmitFeedback: 'Hindi naisumite ang feedback. Pakisubukang muli.',
    yourFeedback: 'Ang iyong feedback',
    submitFeedback: 'Isumite ang Feedback',
    thankYou: 'Salamat!',
    done: 'Tapos na',
    guestSaveBody:
        'Kailangan mong mag-register o mag-log in para ma-save ang entry '
        'na ito.',
    guestLimitBody:
        'Naabot mo na ang limitasyon ngayong araw para sa mga bisita. '
        'Mag-register o mag-log in para sa walang limitasyong paggamit, o '
        'subukang muli bukas.',
    category: 'Kategorya',
    allCategories: 'Lahat ng Kategorya',
    searchHint: 'Maghanap ayon sa pangalan o lugar...',
    noFacilitiesInCategory: 'Walang pasilidad sa kategoryang ito.',
    noFacilitiesMatch: 'Walang pasilidad na tumutugma sa "{query}".',
    directoryNote:
        'Maaaring magbago ang datos sa direktoryo — tumawag muna para '
        'makumpirma bago bumiyahe, at direktang gamitin ang emergency '
        'services sa mga kagyat na sitwasyon.',
    couldNotOpenDialer: 'Hindi mabuksan ang dialer para sa {number}.',
    journalBannerTitle: 'Health Journal',
    journalBannerSubtitle:
        'Gabay sa Sariling Pagsubaybay na may Auto-Referral System para sa mga Paalala sa Tagal ng Paggaling',
    firstAidStepsTitle: 'Mga Hakbang sa First Aid',
    uncertainDetails:
        'May mga detalyeng hindi malinaw sa larawang ito: {details}.',
    disclaimerTitle: 'Paunawa',
    disclaimerBody:
        'Ito ay paunang pagsusuri na gawa ng AI, hindi medikal na diagnosis. Gamitin palagi ang sarili mong pagpapasya at humingi ng propesyonal na pangangalaga kung nagdududa.',
    disclaimerShort:
        'Para lamang sa paunang pagsusuri. Hindi ito panukat ng diagnosis. Humingi ng propesyonal na tulong.',
    categoryLabel: 'Kategorya: {category}',
    seekEmergency: 'Humingi ng Emergency na Tulong Ngayon Din',
    seekUrgent: 'Humingi ng Agarang Medikal na Tulong',
    professionalEval: 'Inirerekomenda ang Pagsusuri ng Propesyonal',
    followUpLabel: 'Magtanong pa',
    describeHint: 'Ilarawan ang iyong alalahanin...',
    saveToJournal: 'I-save sa Health Journal',
    updateJournal: 'I-update ang Journal Entry',
    saving: 'Sine-save...',
    savedToJournal: 'Na-save sa Health Journal',
    analysisTip:
        'Tip: Siguraduhing maliwanag at malinaw na nakikita ang sugat para sa pinakatumpak na pagsusuri.',
    noWoundTitle: 'Walang Nakitang Sugat',
    multipleInjuries: 'Maraming pinsala ang natukoy',
    multiTip: 'I-tap ang sugat na gusto mong suriin.',
    noneOfThese: 'Wala',
    noneChosenNote: 'Walang nasuri. Maaari kang mag-scan muli anumang oras.',
    doneConfirmTitle: 'Tapos ka na ba sa pagsusuring ito?',
    doneConfirmBody:
        'Maaari mo itong i-save sa iyong Health Journal para masubaybayan '
        'ang iyong paggaling.',
    doneSaveToJournal: 'I-save sa Health Journal',
    doneDontSave: 'Huwag i-save',
    journalEmpty:
        'Wala pang journal entry. I-tap ang "Magdagdag ng Entry" para '
        'simulang subaybayan ang iyong paggaling.',
    woundN: 'Sugat {n}',
    selectedWound: 'Napili: {label}',
    selectWound: 'Pumili ng sugat para magpatuloy',
    assessSelected: 'Suriin ang Napiling Sugat',
    couldNotTranslate:
        'Hindi ma-translate ngayon — English muna ang ipinapakita.',
    cameraDisclaimerTitle: 'Medikal na Paunawa',
    cameraDisclaimerBody:
        'Para lamang ito sa paunang pagsusuri at hindi para sa diagnosis. '
        'Humingi ng propesyonal na tulong.',
    offlineTitle: 'Walang Koneksyon sa Internet',
    offlineEntryBody:
        'Offline ka ngayon. Maaari mo pa ring gamitin ang ilang feature sa '
        'Offline Mode.',
    proceedOffline: 'Magpatuloy sa Offline Mode',
    tryAgain: 'Subukang Muli',
    stillOffline: 'Wala pa ring koneksyon sa internet.',
  );
}
