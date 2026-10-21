/// Help & Support section text, Tagalog. A plain-language translation of
/// help_content_en.dart (same structure, block for block). This is medical,
/// privacy and clinical-governance text: have a native speaker and a
/// healthcare professional review it before release.
library;

import 'help_document.dart';

const helpGettingStartedTl = HelpSection(
  title: 'Pagsisimula',
  blocks: [
    HelpHeading('PAGSISIMULA SA FINE AID'),
    HelpParagraph(
      'Ang Iyong AI-Powered na Gabay sa First Aid at Kasama sa Pagsubaybay '
      'ng Paggaling',
    ),
    HelpHeading('MALIGAYANG PAGDATING!'),
    HelpParagraph(
      'Ang Fine Aid ay isang AI-driven na mobile application na idinisenyo '
      'para magbigay ng maaasahan at paunang gabay sa first aid at hakbang-'
      'hakbang na suporta sa pag-aalaga ng sugat.',
    ),
    HelpParagraph(
      'Kung kailangan mo ng agarang tagubilin para sa maliit na pinsala, '
      'gusto mong i-scan ang sugat para sa awtomatikong pagsusuri, o kailangan '
      'mong subaybayan ang iyong paggaling sa paglipas ng panahon, nag-aalok '
      'ang Fine Aid ng toolkit na nakabatay sa ebidensya at inihambing sa mga '
      'mapagkakatiwalaang sanggunian sa medisina (kabilang ang WHO, Red '
      'Cross, MIMS Philippines, at mga lokal na pamantayang pangkalusugan).',
    ),
    HelpCallout(
      'MAHALAGANG PAUNAWANG MEDIKAL: Ang Fine Aid ay isang kasangkapan sa '
      'paunang gabay at pagsubaybay ng progreso na binuo para sa '
      'impormasyon at suportang pang-edukasyon. HINDI ito kapalit ng '
      'propesyonal na payong medikal, klinikal na pagsusuri, o mga serbisyong '
      'pang-emerhensiya. Sa mga emerhensiyang nanganganib ang buhay, tumawag '
      'sa iyong lokal na emergency hotline (hal., 911) o pumunta agad sa '
      'pinakamalapit na ospital.',
    ),
    HelpHeading('MGA MODE NG PAGGAMIT'),
    HelpParagraph(
      'Idinisenyo ang Fine Aid para gumana sa anumang sitwasyon, may mabilis '
      'ka mang internet, limitado ang oras, o walang koneksyon.',
    ),
    HelpList([
      HelpItem(
        'Buong access sa app: AI Camera scanning, Health Journal na naka-sync '
        'sa cloud, Auto-Referral Alerts, Nearby Healthcare Finder, OTC '
        'Suggestions, Chatbot, at Log Export.',
        label: 'Online Mode (Nakarehistro at Naka-sign In)',
        stacked: true,
      ),
      HelpItem(
        'Mabilis na pagpasok: Trial na AI Camera scans, access sa pangkalahatang '
        'first-aid textbook, pansamantalang draft ng journal, at pangunahing '
        'suporta. (May pang-araw-araw na limitasyon sa upload hanggang sa '
        'magparehistro).',
        label: 'Guest Mode (Walang Kailangang Account)',
        stacked: true,
      ),
      HelpItem(
        'Pangkaligtasang sandigan sa emerhensiya: Naka-load nang First Aid '
        'Textbook at Health Kit library na magagamit offline, at text-only na '
        'pagtatala sa Health Journal.',
        label: 'Offline Mode (Walang Koneksyon)',
        stacked: true,
      ),
    ]),
    HelpHeading('UNANG PAGSASAAYOS AT ONBOARDING'),
    HelpHeading('Hakbang 1: Pag-download at Kinakailangan ng Device'),
    HelpList([
      HelpItem(
        'Ang Fine Aid ay ginawa para lamang sa mga Android mobile device na '
        'may makabagong bersyon ng Android OS. (Hindi suportado ang iOS sa '
        'kasalukuyang release).',
        label: 'Suportadong Platform',
      ),
    ]),
    HelpHeading('Hakbang 2: Pagpaparehistro ng Account'),
    HelpList([
      HelpItem(
        'Magrehistro gamit ang iyong email address at isang ligtas na '
        'password. Makakatanggap ka ng One-Time Password (OTP) para sa '
        'beripikasyon. Ang pagpaparehistro ay nagbibigay-daan sa cloud sync '
        'sa iba’t ibang device at nag-a-unlock ng walang limitasyong pag-save '
        'ng journal.',
        label: 'Gumawa ng Account',
      ),
    ]),
    HelpHeading(
      'Hakbang 3: Tanggapin ang Mga Tuntunin, Ibigay ang Mga Pahintulot at '
      'Checklist',
    ),
    HelpParagraph('Para matiyak ang kaligtasan, paggana, at privacy ng datos:'),
    HelpList(numbered: true, [
      HelpItem(
        'Basahin at tanggapin ang aming mga tuntunin sa paghawak ng datos, '
        'ligtas na pag-iimbak (gamit ang Google Firebase), at mga patakaran '
        'sa kaligtasan ng user.',
        label: 'Mga Tuntunin at Patakaran sa Privacy',
      ),
      HelpItem(
        'Ibigay ang pahintulot sa camera kapag hiningi. Kailangan lamang ang '
        'access sa camera para sa pag-scan ng sugat upang makabuo ng AI na '
        'gabay sa first aid.',
        label: 'Pahintulot sa Access ng Camera',
      ),
      HelpItem(
        'Kumpletuhin ang maikling paunang checklist ng katayuan ng '
        'kalusugan. Ang panloob na datos ng profile na ito ay tumutulong na '
        'i-personalize ang mga tugon sa first aid para mas tumugma sa iyong '
        'partikular na pangangailangang pangkalusugan.',
        label: 'Checklist ng Katayuan ng Kalusugan',
      ),
    ]),
    HelpHeading('Hakbang 4: Onboarding Walkthrough'),
    HelpParagraph(
      'Sa unang pagbukas mo ng app, gagabayan ka sa isang interaktibo at '
      'may-highlight na preview.',
    ),
    HelpHeading('PAGKILALA SA MGA PANGUNAHING TAMPOK AT DASHBOARD'),
    HelpHeading('AI Vision Camera at Pagsusuri'),
    HelpList([
      HelpItem(
        'Itutok ang camera sa sugat o kondisyon ng balat. Susuriin ng AI ang '
        'larawan at bubuo ng hakbang-hakbang na pangangalagang first aid.',
        label: 'Pag-scan ng Sugat, Maliit na Pinsala, Problema sa Balat',
      ),
      HelpItem(
        'Kung makakita ang camera ng maraming magkakaibang pinsala (hal., '
        'galos sa tabi ng naghihilom na peklat), hihilingin ng sistema na '
        'piliin mo kung alin ang gusto mong tugunan.',
        label: 'Pagtukoy ng Maraming Pinsala',
      ),
      HelpItem(
        'Kung nakaaapekto sa kalidad ng scan ang labo o kulang na liwanag, '
        'hihilingin ng sistema na kumuha ka ulit ng larawan.',
        label: 'Pag-uulit at Babala sa Liwanag',
      ),
    ]),
    HelpHeading('Health Journal at Clinical Auto-Referral System'),
    HelpList([
      HelpItem(
        'Itala ang mga paglalarawan, antas ng sakit (gamit ang interaktibong '
        'Pain Rating Scale), at opsyonal na mga larawan ng paggaling para '
        'masubaybayan ang progreso sa paglipas ng panahon.',
        label: 'Mga Tala ng Progreso ng Paggaling',
      ),
      HelpItem(
        'Isumite ang kabuuang entry para makatanggap ng awtomatikong '
        'feedback na pagsusuri.',
        label: 'Pagsusuri ng Sakit at Kondisyon',
      ),
      HelpItem(
        'Sinusubaybayan ng journal ang iyong paggaling batay sa itinatag na '
        'klinikal na timeline ng paghilom. Kapag hindi bumubuti ang iyong '
        'kondisyon o may hindi inaasahang paglala, awtomatikong magpapadala '
        'ang sistema ng Auto-Referral Alert na hinihikayat kang kumonsulta '
        'sa lisensyadong propesyonal sa medisina.',
        label: 'Mga Clinical Auto-Referral Notification',
      ),
      HelpItem(
        'Madaling i-export ang kumpletong kasaysayan ng iyong health journal '
        'para maibahagi sa iyong doktor sa pormal na konsultasyong medikal.',
        label: 'I-export ang Log para sa mga Doktor',
      ),
    ]),
    HelpHeading(
      'Mga Mungkahing Over the Counter (OTC) na Pangangalaga at Chatbot',
    ),
    HelpList([
      HelpItem(
        'Makakuha ng mga ligtas at hindi-reseta na mungkahi at pag-iingat sa '
        'first-aid care. (HINDI nagrereseta ang Fine Aid ng antibiotics o '
        'controlled na gamot).',
      ),
      HelpItem(
        'Makipag-ugnayan sa in-app na AI Chatbot para sa tiyak na tanong sa '
        'first aid at mga sanggunian sa gabay medikal.',
      ),
    ]),
    HelpHeading('Maghanap ng Malalapit na Pasilidad Pangkalusugan'),
    HelpList([
      HelpItem(
        'Tingnan ang direktoryo ng malalapit na ospital, klinika, at '
        'akreditadong animal bite center, kumpleto sa address at mga numero '
        'para sa emerhensiya.',
      ),
    ]),
    HelpHeading('MGA LIMITASYON NG APP AT PATAKARAN SA KALIGTASAN'),
    HelpParagraph(
      'Para sa iyong proteksyon, isaisip ang mga sumusunod na hangganan ng '
      'paggamit:',
    ),
    HelpList([
      HelpItem(
        'Hindi nagsusuri ang Fine Aid ng mga panloob na kondisyong medikal, '
        'talamak na sakit sa buong katawan, o malubha/nakamamatay na pinsala '
        '(tulad ng malalim na panloob na pagdurugo o pagkabigo ng organ).',
        label: 'Walang Saklaw sa Talamak na Sakit o Emerhensiya',
      ),
      HelpItem(
        'Pangkalahatang tips sa over-the-counter na pangangalaga, pangunahing '
        'paraan ng paglilinis, at tagubilin sa first aid lamang ang ibinibigay '
        'ng app.',
        label: 'Hindi Nagrereseta',
      ),
      HelpItem(
        'Laging unahin ang direktang klinikal na pangangalaga kaysa sa mga '
        'rekomendasyon ng app kapag may malulubhang sintomas, senyales ng '
        'impeksyon, o patuloy na matinding sakit.',
        label: 'Unahin ang Propesyonal na Pangangalaga',
      ),
    ]),
  ],
);

const helpPrivacyTl = HelpSection(
  title: 'Mga Isyu sa Privacy',
  blocks: [
    HelpHeading('PATAKARAN SA PRIVACY AT PROTEKSYON NG DATOS'),
    HelpParagraph(
      'Nakatuon ang Fine Aid Development Team sa pagpapanatili ng pinakamataas '
      'na pamantayan ng privacy, pagiging kumpidensyal, at seguridad ng datos. '
      'Dahil pinoproseso ng Fine Aid ang impormasyong pangkalusugan na '
      'nililikha ng user, mahigpit na sumusunod ang aming pamamahala ng datos '
      'sa mga umiiral na regulasyon, kabilang ang Data Privacy Act of 2012 '
      '(Republic Act No. 10173) sa Pilipinas at mga pandaigdigang pamantayan '
      'sa privacy ng datos.',
    ),
    HelpParagraph(
      'Pormal na inilalahad ng Patakaran sa Privacy na ito kung paano '
      'kinokolekta, pinoproseso, pinoprotektahan, at iniingatan ang personal '
      'na datos at sensitibong talaan ng kalusugan sa loob ng app.',
    ),
    HelpHeading(
      'Mga Kategorya ng Kinokolektang Datos at Layunin ng Pagproseso',
    ),
    HelpParagraph(
      'Para matiyak ang paggana ng application at personalisadong gabay, '
      'kumokolekta ang Fine Aid ng tiyak na mga kategorya ng impormasyon ng '
      'user sa ilalim ng malinaw na legal na batayan:',
    ),
    HelpHeading('Datos sa Account at Pamamahala ng Pagkakakilanlan'),
    HelpList([
      HelpItem(
        'Personal na impormasyon, email address, username, at mga tala ng '
        'authentication (kabilang ang One-Time Password / OTP).',
        label: 'Mga Uri ng Kinokolektang Datos',
      ),
      HelpItem(
        'Paggawa ng account, multi-factor na beripikasyon ng pagkakakilanlan, '
        'kontrol sa pag-access sa platform, at pagbawi ng account.',
        label: 'Layunin',
      ),
    ]),
    HelpHeading('AI Camera at Biswal na Datos'),
    HelpList([
      HelpItem(
        'Mga na-scan na sugat, maliliit na pinsala, at problema sa balat na '
        'nakuhanan gamit ang camera ng device.',
        label: 'Mga Uri ng Kinokolektang Datos',
      ),
      HelpItem(
        'Awtomatikong pagsusuri ng tampok upang makabuo ng hakbang-hakbang na '
        'rekomendasyon sa first aid.',
        label: 'Layunin',
      ),
      HelpItem(
        'Ang mga nakuhang larawan ay pinoproseso lamang upang magbigay ng '
        'agarang obserbasyonal na feedback. Hinahawakan ang mga larawan sa '
        'ligtas na kapaligiran at hindi kailanman inilalantad sa publiko o '
        'ginagamit muli para sa komersyal na layunin.',
        label: 'Protocol sa Pagproseso',
      ),
    ]),
    HelpHeading('Health Journal at Mga Tala ng Paggaling'),
    HelpList([
      HelpItem(
        'Mga tala ng sintomas na ikaw mismo ang nag-ulat, antas ng sakit, mga '
        'petsa, at pagpayag na subaybayan ang progreso ng paggaling.',
        label: 'Mga Uri ng Kinokolektang Datos',
      ),
      HelpItem(
        'Magbigay sa mga user ng personal na paraan ng pagsubaybay upang '
        'masundan ang paggaling sa paglipas ng panahon.',
        label: 'Layunin',
      ),
    ]),
    HelpHeading('Mahigpit na Kontrol sa Pag-access at Seguridad ng Database'),
    HelpList([
      HelpItem(
        'Nagpapatupad ang mga security rule ng mahigpit na pagsusuri ng '
        'awtorisasyon sa antas ng user. Walang user na maaaring mag-access, '
        'mag-query, o magbago ng personal na profile, entry sa journal, o '
        'media file ng ibang user.',
      ),
      HelpItem(
        'Sa default, hinaharangan ng mga database node at cloud storage '
        'bucket ang lahat ng operasyon sa datos na walang authentication o '
        'sa pagitan ng magkaibang account.',
        label: 'Mga Pahintulot Batay sa Tungkulin',
      ),
    ]),
    HelpHeading('Patakaran sa Pagbabahagi at Paglalantad ng Datos'),
    HelpParagraph(
      'Mahigpit ang patakaran ng Fine Aid na huwag ilantad ang impormasyon '
      'ng user:',
    ),
    HelpList([
      HelpItem(
        'Ang personal na datos, talaan ng kalusugan, at mga tala ng larawan '
        'ay hindi kailanman ibinebenta, ipinauupa, o ipinaaarkila sa mga '
        'third-party na advertiser, data broker, o komersyal na entidad.',
        label: 'Walang Komersyalisasyon',
      ),
      HelpItem(
        'Limitado ang pagproseso ng datos sa mga ligtas na cloud service '
        'provider (Firebase) na may mahigpit na kasunduan sa pagiging '
        'kumpidensyal at seguridad.',
        label: 'Mga Third-Party na Tagapagproseso ng Imprastraktura',
      ),
      HelpItem(
        'Maaari lamang ilantad ang personal na impormasyon kung tahasang '
        'iniuutos ng umiiral na batas, utos ng korte, o lehitimong direktiba '
        'ng pamahalaan.',
        label: 'Pagsunod sa Batas',
      ),
    ]),
    HelpHeading('Mga Karapatan ng Indibidwal at Kontrol ng User'),
    HelpParagraph(
      'Alinsunod sa mga prinsipyo ng batas sa privacy ng datos, kinikilala at '
      'ginagarantiya ng Fine Aid ang mga sumusunod na karapatan para sa lahat '
      'ng nakarehistrong user:',
    ),
    HelpList(numbered: true, [
      HelpItem(
        'May ganap na kakayahan ang mga user na makita ang kanilang personal '
        'na talaan ng kalusugan at mga detalye ng profile na nakaimbak sa '
        'application.',
        label: 'Karapatang Ma-access ang Datos',
      ),
      HelpItem(
        'Maaaring magsimula ang mga user ng awtomatikong kahilingan sa '
        'pagbura ng account anumang oras. Awtomatikong buburahin ng mga '
        'system trigger ang kaugnay na profile ng user, mga dokumento ng '
        'journal sa Firestore, at nakaimbak na media file mula sa mga cloud '
        'server.',
        label: 'Karapatang Mabura (Pagbura ng Account at Datos)',
      ),
    ]),
    HelpHeading(
      'Mga Pagbabago sa Patakaran at Impormasyon sa Pakikipag-ugnayan',
    ),
    HelpParagraph(
      'Inilalaan namin ang karapatang baguhin ang Patakaran sa Privacy na ito '
      'upang umayon sa mga teknikal na pagbabago, pagbabago sa batas, o '
      'pangangailangan sa operasyon. Ipapaalam ang mahahalagang pagbabago sa '
      'pamamagitan ng in-app na alerto o sa rehistradong email.',
    ),
  ],
);

const helpJournalTl = HelpSection(
  title: 'Paano gamitin ang Journal?',
  blocks: [
    HelpHeading('PAANO GAMITIN ANG HEALTH JOURNAL AT PROGRESS TRACKER'),
    HelpParagraph(
      'Ang Health Journal ang iyong personalisadong kasama sa paggaling. '
      'Pinapayagan ka nitong itala ang paghilom ng sugat, sabihin ang antas '
      'ng sakit, makatanggap ng awtomatikong pagsusuri ng progreso, at '
      'gumawa ng mga log na maibabahagi sa mga konsultasyong medikal.',
    ),
    HelpHeading('HAKBANG 1: PAGGAWA NG BAGONG ENTRY SA JOURNAL'),
    HelpList([
      HelpItem(
        'Buksan ang icon ng Health Journal mula sa pangunahing menu ng '
        'nabigasyon o dashboard.',
      ),
      HelpItem(
        'I-tap ang "Add Entry +" (Bagong Log) na button para gumawa ng '
        'entry.',
      ),
      HelpItem(
        'Punan ang mga detalye ng pangyayari:',
        children: [
          HelpItem(
            'Sumulat ng maikling tala na naglalarawan sa pinsala, sanhi, o '
            'kasalukuyang kondisyon (hal., "Maliit na galos sa kaliwang tuhod '
            'dahil sa pagkahulog sa bisikleta").',
            label: 'Pamagat at Paglalarawan ng Pangyayari',
          ),
          HelpItem(
            'Awtomatikong itinatakda sa kasalukuyang petsa at oras.',
            label: 'Petsa at Timestamp',
          ),
          HelpItem(
            'Piliin ang angkop na uri mula sa mga ibinigay na opsyon.',
            label: 'Kategorya ng Pinsala',
          ),
        ],
      ),
    ]),
    HelpHeading('HAKBANG 2: PAGSUKAT NG SAKIT AT PAGTATALA NG MGA DETALYE'),
    HelpList(numbered: true, [
      HelpItem(
        'Gamitin ang built-in na Pain Rating Scale (0 hanggang 10) para '
        'ipakita ang kasalukuyang antas ng iyong hirap:',
        label: 'Interaktibong Pain Rating Scale',
        children: [
          HelpItem(
            'Lubos na komportable, walang natitirang pananakit.',
            label: '0 – Walang Sakit',
          ),
          HelpItem(
            'Bahagyang hirap, madaling hindi pansinin.',
            label: '1–4 – Banayad na Sakit',
          ),
          HelpItem(
            'Kapansin-pansing sakit na bahagyang nakaaabala sa pang-araw-araw '
            'na gawain.',
            label: '5–7 – Katamtamang Sakit',
          ),
          HelpItem(
            'Matindi o pumipintig na sakit na nangangailangan ng agarang '
            'pahinga o propesyonal na atensyong medikal.',
            label: '8–10 – Matinding Sakit',
          ),
        ],
      ),
      HelpItem(
        'I-tap ang "Add Images" para kumuha ng kasalukuyang larawan ng iyong '
        'sugat. Ang pagdaragdag ng mga larawan ng progreso sa loob ng '
        'maraming araw ay lumilikha ng biswal na timeline na tumutulong sa '
        'iyo at sa mga propesyonal sa kalusugan na suriin ang bilis ng '
        'paghilom at matukoy nang maaga ang posibleng komplikasyon.',
        label: 'Pagdaragdag ng Larawan ng Progreso (Online at Guest Mode)',
      ),
      HelpItem(
        'I-tap ang "Remind Me" na toggle para makatanggap ng notification '
        'kapag umabot na ang iyong progreso ng paggaling sa inaasahang oras '
        'ng paghilom, batay sa Time to Heal (TTH) sa pag-aalaga ng sugat.',
      ),
    ]),
    HelpParagraph(
      'Kailangan ng Guest Mode na magrehistro ka ng account para ma-save ang '
      'mga entry sa journal. Sinusuportahan lamang ng Offline Mode ang mga '
      'entry na teksto at pain scale.',
      label: 'Paalala',
    ),
    HelpHeading('HAKBANG 3: PAGSUMITE PARA SA AWTOMATIKONG PAGSUSURI'),
    HelpParagraph(
      'Kapag naisumite mo na ang iyong entry sa journal, ipoproseso ng Fine '
      'Aid ang iyong mga input batay sa itinatag na klinikal na timeline ng '
      'paggaling:',
    ),
    HelpList([
      HelpItem(
        'Susuriin ng app ang iyong mga tala, antas ng sakit, at lumipas na '
        'oras para magbigay ng pangkalahatang pagsusuri ng progreso (hal., '
        '"On Track," "Delayed Healing," o "Further Care Advised").',
        label: 'Buod ng Pagsusuri',
      ),
      HelpItem(
        'Awtomatikong ipapaskil sa iyong Calendar Dashboard ang mga '
        'naisumiteng entry, kaya madaling balikan ang kasaysayan ng iyong '
        'paggaling ayon sa petsa.',
        label: 'Integrasyon sa Kalendaryo',
      ),
    ]),
    HelpHeading('PAG-UNAWA SA MGA AUTO-REFERRAL ALERT'),
    HelpParagraph('', label: 'Paano Gumagana ang Auto-Referral:'),
    HelpList([
      HelpItem(
        'Nag-a-activate ang Auto-Referral Alert kapag:',
        children: [
          HelpItem(
            'Mataas ang itinala mong antas ng sakit.',
            label: 'Lumalalang Sakit',
          ),
          HelpItem(
            'Ipinapakita ng iyong mga input ang mga sintomas tulad ng '
            'kumakalat na pamumula, patuloy na pamamaga, o abnormal na '
            'lumalabas na likido.',
            label: 'Senyales ng Komplikasyon',
          ),
          HelpItem(
            'Walang masusukat na senyales ng paghilom ang sugat lampas sa '
            'inaasahang klinikal na panahon.',
            label: 'Naantalang Paggaling',
          ),
        ],
      ),
      HelpItem(
        'Makakatanggap ka ng notification na nagpapayo na humingi ng pormal '
        'na konsultasyon sa lisensyadong propesyonal sa kalusugan.',
        label: 'Aksyon ng Sistema',
      ),
    ]),
    HelpCallout(
      'Tip: Idinisenyo ang mga auto-referral notification para maagang '
      'matukoy ang mga komplikasyon. Kung makatanggap ka ng alerto, huwag '
      'ipagpaliban ang paghingi ng medikal na pangangalaga.',
    ),
    HelpHeading('PAG-EXPORT NG MGA LOG PARA SA MGA KONSULTASYONG MEDIKAL'),
    HelpParagraph(
      'Kapag bibisita sa doktor o klinika, maaari mong direktang ibahagi ang '
      'kumpletong kasaysayan ng iyong journal:',
    ),
    HelpList(numbered: true, [
      HelpItem('I-tap ang "Export Log".'),
      HelpItem(
        'Mag-export ng naka-format na PDF / Digital Summary na naglalaman ng '
        'iyong mga tala ng pangyayari, antas ng sakit, at mga timestamp para '
        'ipakita sa iyong healthcare provider.',
      ),
    ]),
    HelpHeading('MABILIS NA TIPS PARA SA PINAKAMAGANDANG RESULTA'),
    HelpList([
      HelpItem(
        'Itala ang mga update sa parehong oras araw-araw (hal., tuwing '
        'pagpapalit ng benda) para sa tumpak na pagsubaybay ng progreso.',
        label: 'Magtala nang Tumpak at Tuloy-tuloy',
      ),
      HelpItem(
        'Nakatutulong ang tumpak na antas ng sakit para maagang matukoy ng '
        'auto-referral system ang hindi inaasahang pamamaga o impeksyon.',
        label: 'Maging Tapat sa Antas ng Sakit',
      ),
      HelpItem(
        'Tiyaking naka-sign in ka para ma-back up ang datos ng iyong journal '
        'sa ligtas na cloud storage (sa pamamagitan ng Google Firebase) at '
        'magamit kung magpalit ka ng device.',
        label: 'Pag-sync ng Account',
      ),
    ]),
  ],
);

const helpReferencesTl = HelpSection(
  title: 'Mga Sanggunian',
  blocks: [
    HelpHeading('MGA SANGGUNIAN AT BERIPIKASYONG MEDIKAL'),
    HelpParagraph(
      '',
      label: 'Ang Aming Pangako sa Bisa at Kaligtasang Medikal:',
    ),
    HelpParagraph(
      'Para matiyak na nagbibigay ang Fine Aid ng tumpak, ligtas, at '
      'nakabatay-sa-ebidensyang gabay, ang bawat tagubilin sa first aid, '
      'daloy ng pag-aalaga ng sugat, at rekomendasyong pangkalusugan sa aming '
      'sistema ay inihahambing sa mga awtoridad sa medisina na kinikilala sa '
      'buong mundo at sa bansa. Pinagsasama ng aming pangunahing repositoryo '
      'ang mga karaniwang protocol na itinatag ng World Health Organization '
      '(WHO), ng International Federation of Red Cross and Red Crescent '
      'Societies (IFRC / Philippine Red Cross), ng MIMS Philippines, at ng '
      'mga lokal na ahensiyang tagapamahala kabilang ang Department of Health '
      '(DOH - Pilipinas).',
    ),
    HelpParagraph(
      'Higit pa sa digital na pinagkukunan, ang bawat klinikal na gabay, '
      'lohika ng algorithm, at rekomendasyon sa pangangalaga sa bahay ay '
      'dumadaan sa manu-manong pagsusuri ng isang advisory panel ng mga '
      'lisensyadong propesyonal sa medisina at board-certified na mga '
      'espesyalista. Tinitiyak ng dalawang-patong na beripikasyong ito na '
      'ligtas at napapanahon ang matatanggap ng mga user, habang aktibong '
      'pinoprotektahan sila laban sa mapanganib na medikal na maling akala '
      'online at mga hindi napatunayang gamot-bahay.',
    ),
    HelpHeading('MGA SERTIPIKASYON AT PAGPAPAUNLAD'),
    HelpParagraph(
      'Patuloy na nagbabago ang kaalamang medikal at pinakamahusay na '
      'praktis sa klinika. Upang mapanatili ang pagsunod at klinikal na '
      'katumpakan, ang aming repositoryo ng nilalamang medikal at ang mga '
      'modelong gabay na pinagbabatayan nito ay dumadaan sa kada-kwartong '
      'pagsusuri. Tinitiyak nito ang mahigpit na pagsunod sa pinakabagong '
      'alituntunin ng mga pambansang awtoridad sa kalusugan at pandaigdigang '
      'institusyong medikal.',
    ),
    HelpHeading('MGA BERIPIKADONG SANGGUNIAN SA MEDISINA'),
    HelpGroup('World Health Organization (WHO)', [
      HelpHeading('Kasaysayan at Pagkakatatag'),
      HelpParagraph(
        'Itinatag noong Abril 7, 1948, ang World Health Organization (WHO) ay '
        'itinayo bilang espesyalisadong ahensiya ng United Nations na '
        'nakatuon sa pamamahala at pag-uugnay ng pandaigdigang pampublikong '
        'kalusugan. Binuo pagkatapos ng WWII upang pagkaisahin ang '
        'pandaigdigang tugon sa medisina, gumagana ang WHO sa 194 na Member '
        'State upang palawakin ang saklaw ng kalusugan, pangunahan ang tugon '
        'sa mga emerhensiyang pangkalusugan, at magtatag ng mga siyentipikong '
        'pamantayan sa kalusugan sa buong mundo.',
      ),
      HelpHeading('Pangunahing Layunin'),
      HelpParagraph(
        'Ipaglaban ang karapatan sa kalusugan ng bawat indibidwal, itaguyod '
        'ang malusog na pamumuhay, pigilan ang sakit, at pag-ugnayin ang '
        'pandaigdigang tugon medikal sa emerhensiya batay sa mahigpit na '
        'siyentipikong pananaliksik.',
      ),
      HelpHeading('Papel sa Fine Aid'),
      HelpParagraph(
        'Ang mga internasyonal na klinikal na alituntunin ng WHO ang batayang '
        'pundasyon ng pangunahing decision tree ng Fine Aid sa first aid, mga '
        'pamamaraan sa pag-iwas sa impeksyon, at pangunahing protocol sa '
        'kalinisan.',
      ),
    ]),
    HelpGroup('Philippine Red Cross (PRC)', [
      HelpHeading('Kasaysayan at Pagkakatatag'),
      HelpParagraph(
        'Nag-ugat sa kasaysayan mula sa kilusang Red Cross ng Republika ng '
        'Malolos noong 1899, pormal na itinatag ang opisyal na Philippine Red '
        'Cross sa bisa ng Republic Act No. 95 noong Abril 15, 1947. Lumitaw '
        'ito matapos ang kasarinlan ng Pilipinas upang maging pangunahing '
        'boluntaryong humanitarian na organisasyon ng bansa.',
      ),
      HelpHeading('Pangunahing Layunin'),
      HelpParagraph(
        'Kumilos bilang katuwang ng pamahalaan sa mga sakuna, krisis medikal, '
        'at emerhensiyang makatao. Nagbibigay ang PRC ng serbisyo ng dugo, '
        'pagsasanay sa kalusugan ng komunidad, pamamahala ng sakuna, at '
        'gabay sa first aid sa antas ng komunidad.',
      ),
      HelpHeading('Papel sa Fine Aid'),
      HelpParagraph(
        'Ang hakbang-hakbang na pisikal na gabay sa first aid ng Fine Aid, '
        'tulad ng paggamot sa hiwa, paso mula sa init, at tagubilin sa '
        'pagbebenda, ay nakabalangkas ayon sa itinatag na daloy ng tugon sa '
        'emerhensiya ng Red Cross.',
      ),
    ]),
    HelpGroup('Monthly Index of Medical Specialties (MIMS) Philippines', [
      HelpHeading('Kasaysayan at Pagkakatatag'),
      HelpParagraph(
        'Itinatag noong 1963, lumago ang MIMS sa loob ng mahigit anim na '
        'dekada mula sa nakalimbag na sanggunian sa parmasya tungo sa '
        'nangungunang digital na sentro ng impormasyon sa medisina at gamot '
        'na naglilingkod sa mga propesyonal sa kalusugan sa buong '
        'Asia-Pacific.',
      ),
      HelpHeading('Pangunahing Layunin'),
      HelpParagraph(
        'Magbigay ng beripikado at nakabatay-sa-ebidensyang datos sa parmasya, '
        'interaksyon ng gamot, gabay sa klinikal na paggamot, at impormasyon '
        'sa over the counter (OTC) na pangangalaga na pinagkakatiwalaan ng '
        'mga doktor, nars, at parmasyutiko.',
      ),
      HelpHeading('Papel sa Fine Aid'),
      HelpParagraph(
        'Ginagamit ng Fine Aid ang MIMS Philippines bilang pangunahing '
        'sanggunian sa pagberipika ng ligtas at hindi-reseta na Over the '
        'Counter (OTC) na mungkahi sa pangangalaga, mga pag-iingat, at '
        'hindi-nagrereseta na paraan ng paglilinis sa bahay.',
      ),
    ]),
    HelpGroup('Department of Health (DOH - Pilipinas)', [
      HelpHeading('Kasaysayan at Pagkakatatag'),
      HelpParagraph(
        'Nag-ugat sa pagbuo ng Department of Public Works, Education, and '
        'Hygiene noong Hunyo 1898 sa ilalim ni Pangulong Emilio Aguinaldo, '
        'naging Department of Health and Public Welfare ang ahensiya noong '
        '1941 at pormal na muling itinatag pagkatapos ng digmaan bilang '
        'Department of Health (DOH) noong 1947.',
      ),
      HelpHeading('Pangunahing Layunin'),
      HelpParagraph(
        'Bilang ehekutibong kagawaran ng pamahalaan ng Pilipinas na '
        'responsable sa pampublikong kalusugan, tinitiyak ng DOH ang access '
        'sa pangunahing serbisyong pangkalusugan, kinokontrol ang mga '
        'pasilidad pangkalusugan, at bumubuo ng pambansang patakaran sa '
        'pag-iwas sa sakit.',
      ),
      HelpHeading('Papel sa Fine Aid'),
      HelpParagraph(
        'Ang mga alituntunin ng DOH ang batayan ng mga lokal na landas '
        'medikal ng Fine Aid at mga lokal na abiso sa sintomas ng sakit.',
      ),
    ]),
    HelpGroup('Nilalamang Sinuri ng Doktor at Klinikal na Pamamahala', [
      HelpHeading(
        'Pangkalahatang-ideya ng Pangangasiwa at Klinikal na Pamamahala',
      ),
      HelpParagraph(
        'Upang mapanatili ang pinakamataas na pamantayan ng kaligtasan, '
        'katumpakan, at tiwala ng user, gumagana ang Fine Aid sa ilalim ng '
        'isang nakabalangkas na Clinical Governance Framework. Ang bawat '
        'gabay pangkalusugan, tagubilin sa first aid, at lohika ng '
        'AI-driven na pagsusuri sa loob ng application ay dumadaan sa '
        'tuluy-tuloy na medikal na pagsusuri. Tinitiyak ng human-in-the-loop '
        'na pangangasiwang ito na mahigpit na umaayon ang mga digital na '
        'rekomendasyong pangkalusugan sa totoong klinikal na pamantayan at '
        'ligtas na praktis medikal.',
      ),
      HelpHeading('Mga Pangunahing Haligi ng Pamamahala'),
      HelpHeading(
        '1. Expert Advisory Panel at Tuloy-tuloy na Medikal na Pagsusuri',
      ),
      HelpList([
        HelpItem(
          'Ang lahat ng pinagbabatayang klinikal na patakaran, pagkakasunod-'
          'sunod ng hakbang sa first aid, health checklist, at landas ng '
          'desisyon ng AI Camera ay sinusuri at pinagtitibay ng mga '
          'lisensyadong doktor at board-certified na medikal na espesyalista.',
          label: 'Multidisciplinary na Pagsusuri',
        ),
        HelpItem(
          'Bago ipatupad sa mobile application ang anumang algorithmic na '
          'patakaran o rekomendasyon sa first aid, kailangan itong makapasa '
          'sa pormal na safety audit ng aming medical advisory team.',
          label: 'Pag-audit Bago ang Deployment',
        ),
        HelpItem(
          'Sinusuri ng advisory panel ang mga pagsusuri sa sugat, maliliit na '
          'pinsala at problema sa balat upang pinuhin ang lohika ng sistema '
          'at maiwasan ang nakaliligaw o hindi tumpak na gabay.',
          label: 'Pag-iwas sa Pagkakamali at Pagpapahusay',
        ),
      ]),
      HelpHeading(
        '2. Ligtas na Hangganan ng Interbensyon at AI Risk Guardrails',
      ),
      HelpList([
        HelpItem(
          'Nagpapatupad ang medical team ng Fine Aid ng mga teknikal na '
          'guardrail sa lahat ng output ng AI vision. Tahasang ipinagbabawal '
          'sa application ang pag-diagnose ng talamak na kondisyon, pagreseta '
          'ng mga gamot na may reseta (tulad ng antibiotics o espesyal na '
          'pangkasalukuyan), o pagtulad sa klinikal na plano ng paggamot.',
          label: 'Mahigpit na Hangganan: Hindi Nagdi-diagnose',
        ),
        HelpItem(
          'Naka-program ang algorithm na may konserbatibong hangganan ng '
          'kaligtasan. Kung may senyales ng kalubhaan ang sinuring pinsala o '
          'naitalang sintomas (hal., pinaghihinalaang malalim na hiwa, '
          'pagdurugo ng arterya, third-degree na paso, o palatandaan ng '
          'impeksyon), agad na ititigil ng sistema ang karaniwang output ng '
          'first aid.',
          label: 'Maagang Pagtukoy ng Mataas na Panganib',
        ),
        HelpItem(
          'Kapag may nakitang indikasyon ng mataas na panganib o lumalalang '
          'sakit, awtomatikong magpapakita ang sistema ng mga babalang may '
          'prayoridad at ididirekta ang user na humingi ng agarang medikal '
          'na pangangalaga sa emerhensiya o pumunta sa pinakamalapit na '
          'pasilidad pangkalusugan.',
          label: 'Pag-redirect sa Agarang Pangangalaga',
        ),
      ]),
      HelpHeading(
        '3. Multi-Layer at Dalawang-Antas na Proseso ng Beripikasyon',
      ),
      HelpParagraph(
        'Gumagamit ang Fine Aid ng dalawang-antas na balangkas ng beripikasyon '
        'para sa lahat ng nilalamang pangkalusugan at lohika ng desisyon:',
      ),
      HelpList([
        HelpItem(
          'Ang bawat paunang protocol ay sinasaliksik at direktang inihahambing '
          'sa peer-reviewed na literaturang medikal at sa mga itinatag na '
          'pambansa/internasyonal na database (kabilang ang WHO, Philippine '
          'Red Cross, MIMS Philippines, at DOH).',
          label: 'Antas 1: Siyentipiko at Literaturang Beripikasyon',
        ),
        HelpItem(
          'Pagkatapos ng beripikasyon sa literatura, nagsasagawa ang mga '
          'propesyonal sa kalusugan ng manu-manong pagsusuri sa mga digital '
          'na daloy. Tinitiyak nito na ang mga akademikong alituntunin ay '
          'naisasalin sa malinaw, ligtas, at praktikal na mga hakbang na '
          'ligtas na magagawa ng user na walang pagsasanay sa panahon ng '
          'emerhensiya.',
          label: 'Antas 2: Manu-manong Pagsusuri ng Doktor',
        ),
      ]),
      HelpHeading('Tuloy-tuloy na Klinikal na Pag-audit at Quality Assurance'),
      HelpList([
        HelpItem(
          'Ang klinikal na pamamahala ay tuloy-tuloy na proseso. Pana-panahong '
          'sinusuri ng aming mga medical advisor ang mga parametro ng desisyon '
          'ng app upang matiyak ang pagsunod sa napapanahong pananaliksik '
          'medikal, binagong pambansang abiso sa kalusugan, at nagbabagong '
          'pamantayan sa emergency care.',
          label: 'Regular na Pagsusuri ng Balangkas',
        ),
        HelpItem(
          'Sa pagtatatag ng malinaw na linya ng klinikal na pagsusuri, '
          'nagbibigay ang Fine Aid sa mga user at akademikong panel ng ganap '
          'na transparency kung paano bineberipika, pinapanatili, at ligtas '
          'na inihahatid ang impormasyong pangkalusugan.',
          label: 'Transparency at Pananagutan',
        ),
      ]),
    ]),
  ],
);
