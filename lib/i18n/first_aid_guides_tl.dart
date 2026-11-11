/// Tagalog version of lib/data/first_aid_guides.dart — the same steps in the
/// same order and phase, so index i here is the translation of index i
/// there (test/part5_content_test.dart checks this). The Tagalog wording
/// needs review by a Tagalog-speaking health professional before release.
library;

import '../data/first_aid_guides.dart';

const _handsGlovesTl = GuideStep(
  GuidePhase.before,
  'Maghugas ng kamay gamit ang sabon at tubig. Magsuot ng malinis na '
      'disposable na guwantes kung meron.',
  'Para hindi makapasok sa sugat ang mikrobyo mula sa iyong mga kamay.',
);

const _checkInfectionTl = GuideStep(
  GuidePhase.after,
  'Tingnan ang bahaging ito araw-araw kung may kumakalat na pamumula, '
      'init, pamamaga, nana, o lagnat. Magpatingin sa healthcare professional '
      'kung may lumitaw.',
  'Kapag maagang nagamot ang impeksyon, hindi ito lalala.',
);

const Map<String, List<GuideStep>> firstAidGuidesTl = {
  'laceration': [
    _handsGlovesTl,
    GuideStep(
      GuidePhase.before,
      'Ihanda ang malinis na tubig na umaagos, malinis na gasa (o '
          'malinis na tela kung walang gasa), at malinis na non-stick '
          'na dressing. Para sa maliit na hiwa, sapat na ang maliit na adhesive bandage.',
      'Kapag handa na ang mga gamit, mabilis mong matatakpan at '
          'mapapanatiling malinis ang sugat.',
    ),
    GuideStep(
      GuidePhase.during,
      'Dahan-dahan ngunit matatag na pisilin ang sugat gamit ang malinis '
          'na gasa o tela para pigilan ang pagdugo.',
      'Ang pagpisil ay tumutulong para mamuo ang dugo at bumagal ang '
          'pagdugo.',
    ),
    GuideStep(
      GuidePhase.during,
      'Kung meron ka, maaari kang magbuhos ng kaunting hydrogen '
          'peroxide sa sugat para sa unang paglilinis lamang, saka '
          'banlawan ng malinis na tubig. Huwag na itong gamitin ulit sa'
          ' parehong sugat.',
      'Nakakatulong itong maglinis ng sariwang sugat nang isang '
          'beses. Ang paulit-ulit na paggamit ay maaaring makairita sa '
          'balat at makapagpabagal ng paggaling.',
    ),
    GuideStep(
      GuidePhase.during,
      'Banlawan nang mabuti ang sugat ng malinis na tubig na '
          'umaagos kapag humupa na ang pagdugo. Banlawan din ang '
          'anumang hydrogen peroxide.',
      'Natatanggal ang dumi at mikrobyo na maaaring magdulot ng '
          'impeksyon.',
    ),
    GuideStep(
      GuidePhase.during,
      'Huwag maglagay ng alcohol o petroleum jelly nang direkta sa '
          'sariwa o dumudugong sugat.',
      'Ang alcohol ay maaaring makairita at makasira sa gumagaling '
          'na balat, at ang petroleum jelly ay maaaring makabitag ng '
          'halumigmig sa basang sugat.',
    ),
    GuideStep(
      GuidePhase.during,
      'Takpan ng malinis na bendahe o dressing.',
      'Pinoprotektahan ang sugat mula sa dumi at mikrobyo.',
    ),
    GuideStep(
      GuidePhase.after,
      'Palitan ang takip araw-araw, o mas maaga kung nabasa o nadumihan, '
          'at panatilihing malinis at tuyo ang bahaging ito.',
      'Ang basa o maruming takip ay nagpapadami ng mikrobyo.',
    ),
    _checkInfectionTl,
  ],
  'minor_cut': [
    _handsGlovesTl,
    GuideStep(
      GuidePhase.before,
      'Ihanda ang malinis na tubig na umaagos, malinis na tela o '
          'gasa, at maliit na adhesive bandage.',
      'Para malinis at matakpan agad ang hiwa.',
    ),
    GuideStep(
      GuidePhase.during,
      'Kung meron ka, maaari kang magbuhos ng kaunting hydrogen '
          'peroxide sa hiwa para sa unang paglilinis lamang, saka '
          'banlawan ng malinis na tubig. Huwag na itong gamitin ulit sa'
          ' parehong hiwa.',
      'Nakakatulong itong maglinis ng sariwang sugat nang isang '
          'beses. Ang paulit-ulit na paggamit ay maaaring makairita sa '
          'balat at makapagpabagal ng paggaling.',
    ),
    GuideStep(
      GuidePhase.during,
      'Banlawan ang hiwa sa malinis na tubig na umaagos.',
      'Natatanggal ang dumi at mikrobyo.',
    ),
    GuideStep(
      GuidePhase.during,
      'Dahan-dahang pisilin gamit ang malinis na tela kung dumudugo.',
      'Nakakatulong ang pagpisil para huminto ang pagdugo.',
    ),
    GuideStep(
      GuidePhase.during,
      'Maglagay ng antiseptic kung meron, ayon sa nakasulat sa '
          'label. Huwag magbuhos ng alcohol sa hiwa.',
      'Binabawasan ng antiseptic ang mikrobyo sa balat; ang alcohol'
          ' ay maaaring makasira sa gumagaling na balat.',
    ),
    GuideStep(
      GuidePhase.during,
      'Takpan ng maliit na adhesive bandage.',
      'Naiiwasang pumasok ang dumi habang gumagaling ang hiwa.',
    ),
    GuideStep(
      GuidePhase.after,
      'Panatilihing malinis ang bahagi at palitan ang bandage araw-araw, o '
          'mas maaga kung nabasa o nadumihan.',
      'Nakakatulong sa paggaling ang malinis at tuyong takip.',
    ),
    _checkInfectionTl,
  ],
  'scratch': [
    GuideStep(
      GuidePhase.before,
      'Maghugas ng kamay gamit ang sabon at tubig. Ihanda ang '
          'banayad na sabon, malinis na tubig, at malinis na bandage (o'
          ' adhesive bandage).',
      'Para hindi makapasok sa kalmot ang mikrobyo mula sa iyong '
          'mga kamay.',
    ),
    GuideStep(
      GuidePhase.during,
      'Kung meron ka, maaari kang magbuhos ng kaunting hydrogen '
          'peroxide sa kalmot para sa unang paglilinis lamang, saka '
          'banlawan ng malinis na tubig. Huwag na itong gamitin ulit sa'
          ' parehong kalmot.',
      'Nakakatulong itong maglinis ng sariwang sugat nang isang '
          'beses. Ang paulit-ulit na paggamit ay maaaring makairita sa '
          'balat at makapagpabagal ng paggaling.',
    ),
    GuideStep(
      GuidePhase.during,
      'Hugasan nang mabuti ang kalmot gamit ang sabon at malinis na tubig.',
      'Natatanggal ang dumi at mikrobyo sa balat.',
    ),
    GuideStep(
      GuidePhase.during,
      'Maglagay ng antiseptic kung meron, ayon sa nakasulat sa '
          'label. Huwag magbuhos ng alcohol sa kalmot.',
      'Binabawasan ng antiseptic ang mikrobyo; ang alcohol ay '
          'maaaring makairita sa balat.',
    ),
    GuideStep(
      GuidePhase.during,
      'Takpan ng malinis na bandage kung nasa bahaging madalas na '
          'nagkikiskisan.',
      'Para hindi kiskisin ng damit o galaw ang kalmot.',
    ),
    GuideStep(
      GuidePhase.after,
      'Bantayan ang bahaging ito araw-araw sa susunod na ilang araw.',
      'Para maagang mapansin kung may problema.',
    ),
    GuideStep(
      GuidePhase.after,
      'Panatilihing malinis ang bahagi at iwasang kamutin pa ito.',
      'Ang pagkamot ay maaaring muling makasugat sa balat at makapasok '
          'ang mikrobyo.',
    ),
    _checkInfectionTl,
  ],
  'abrasion': [
    _handsGlovesTl,
    GuideStep(
      GuidePhase.before,
      'Ihanda ang malinis na tubig na umaagos at malinis na non-'
          'stick na dressing. Kung wala, gumamit ng malinis na gasa o '
          'malinis na tela na may tape.',
      'Kakailanganin mo ang mga ito pagkatapos magbanlaw.',
    ),
    GuideStep(
      GuidePhase.during,
      'Kung meron ka, maaari kang magbuhos ng kaunting hydrogen '
          'peroxide sa galos para sa unang paglilinis lamang, saka '
          'banlawan ng malinis na tubig. Huwag na itong gamitin ulit sa'
          ' parehong galos.',
      'Nakakatulong itong maglinis ng sariwang sugat nang isang '
          'beses. Ang paulit-ulit na paggamit ay maaaring makairita sa '
          'balat at makapagpabagal ng paggaling.',
    ),
    GuideStep(
      GuidePhase.during,
      'Dahan-dahang banlawan ang galos sa malinis na tubig na umaagos.',
      'Natatanggal ang dumi at mikrobyo.',
    ),
    GuideStep(
      GuidePhase.during,
      'Maingat na alisin ang mga maluwag at nakikitang dumi.',
      'Ang dumi na naiwan sa sugat ay nagpapataas ng panganib ng '
          'impeksyon.',
    ),
    GuideStep(
      GuidePhase.during,
      'Huwag magbuhos ng alcohol sa galos, at huwag maglagay ng '
          'petroleum jelly habang basa o may lumalabas pang likido.',
      'Ang alcohol ay maaaring makairita o makasira sa gumagaling '
          'na balat, at ang mamantikang patong sa basang sugat ay '
          'maaaring makabitag ng halumigmig.',
    ),
    GuideStep(
      GuidePhase.during,
      'Maglagay ng antiseptic na ointment kung meron, ayon sa nakasulat sa '
          'label.',
      'Nakakatulong na bawasan ang mikrobyo sa nagasgas na balat.',
    ),
    GuideStep(
      GuidePhase.during,
      'Takpan ng malinis at non-stick na dressing.',
      'Pinoprotektahan ang sugat at hindi ito nahahatak pagtanggal.',
    ),
    GuideStep(
      GuidePhase.after,
      'Palitan ang takip araw-araw hanggang gumaling, o mas maaga kung '
          'nabasa o nadumihan.',
      'Ang basa o maruming takip ay nagpapadami ng mikrobyo.',
    ),
    GuideStep(
      GuidePhase.after,
      'Tingnan ang bahaging ito araw-araw kung may kumakalat na pamumula, '
          'init, pamamaga, nana, o lagnat. Magpatingin sa healthcare '
          'professional kung may lumitaw, o kung hindi matanggal ang dumi sa '
          'pagbanlaw.',
      'Ang naiwang dumi at ang impeksyon ay nangangailangan ng '
          'propesyonal na pangangalaga.',
    ),
  ],
  'puncture_wound': [
    _handsGlovesTl,
    GuideStep(
      GuidePhase.before,
      'Ihanda ang sabon, malinis na tubig, malinis na gasa (o '
          'malinis na tela), at malinis na bandage.',
      'Para mabilis na malinis at matakpan ang sugat.',
    ),
    GuideStep(
      GuidePhase.during,
      'Kung meron ka, maaari kang magbuhos ng kaunting hydrogen '
          'peroxide sa sugat para sa unang paglilinis lamang, saka '
          'banlawan ng malinis na tubig. Huwag na itong gamitin ulit sa'
          ' parehong sugat.',
      'Nakakatulong itong maglinis ng sariwang sugat nang isang '
          'beses. Ang paulit-ulit na paggamit ay maaaring makairita sa '
          'balat at makapagpabagal ng paggaling.',
    ),
    GuideStep(
      GuidePhase.during,
      'Dahan-dahang hugasan ang bahagi gamit ang sabon at tubig.',
      'Natatanggal ang dumi at mikrobyo sa paligid ng butas.',
    ),
    GuideStep(
      GuidePhase.during,
      'Huwag diinan ang sugat para lumabas ang dugo "bilang paglilinis."',
      'Ang pagdiin ay maaaring makasira sa laman at hindi nito nililinis '
          'ang sugat.',
    ),
    GuideStep(
      GuidePhase.during,
      'Dahan-dahang pisilin gamit ang malinis na gasa kung dumudugo.',
      'Nakakatulong ang pagpisil para huminto ang pagdugo.',
    ),
    GuideStep(
      GuidePhase.during,
      'Takpan ng malinis na bendahe.',
      'Naiiwasang pumasok ang dumi sa sugat.',
    ),
    GuideStep(
      GuidePhase.after,
      'Bantayang mabuti ang mga senyales ng impeksyon sa susunod na ilang '
          'araw.',
      'Mahirap linisin ang loob ng butas, kaya maaaring magkaroon ng '
          'impeksyon pagkalipas ng ilang araw.',
    ),
    GuideStep(
      GuidePhase.after,
      'Magpatingin sa healthcare professional kung marumi o kalawangin ang '
          'bagay na tumusok, malalim ang butas, o hindi ka sigurado sa iyong '
          'bakuna sa tetanus.',
      'Ang ganitong sugat ay maaaring mangailangan ng bakuna sa tetanus o '
          'propesyonal na paglilinis.',
    ),
  ],
  'burn': [
    GuideStep(
      GuidePhase.before,
      'Maghugas ng kamay gamit ang sabon at tubig.',
      'Para hindi madikit ang mikrobyo mula sa kamay sa napasong balat.',
    ),
    GuideStep(
      GuidePhase.before,
      'Tanggalin ang alahas o masisikip na bagay malapit sa '
          'napasong bahagi, at ihanda ang malamig na tubig na umaagos '
          'at malinis na non-stick na dressing (o malinis na tela kung '
          'wala).',
      'Maaaring mamaga ang bahagi, kaya mahirap nang tanggalin ang '
          'singsing at masisikip na bagay.',
    ),
    GuideStep(
      GuidePhase.during,
      'Palamigin ang paso sa malamig (hindi nagyeyelong) tubig na umaagos '
          'sa loob ng 10-20 minuto.',
      'Pinipigilan ng paglamig na lumalim ang paso at napapagaan nito ang '
          'sakit.',
    ),
    GuideStep(
      GuidePhase.during,
      'Huwag maglagay ng yelo nang direkta sa paso.',
      'Ang yelo ay maaaring lalong makasira sa balat.',
    ),
    GuideStep(
      GuidePhase.during,
      'Huwag maglagay ng mantikilya, mantika, toothpaste, o petroleum '
          'jelly sa sariwang paso.',
      'Maaari nitong makulong ang init at madagdagan ang panganib ng '
          'impeksyon.',
    ),
    GuideStep(
      GuidePhase.during,
      'Takpan nang maluwag ng malinis at non-stick na dressing.',
      'Pinoprotektahan ang paso at hindi dumidikit sa balat.',
    ),
    GuideStep(
      GuidePhase.during,
      'Huwag pumutok ng anumang paltos na mabubuo.',
      'Ang balat ng paltos ang nagpoprotekta laban sa impeksyon.',
    ),
    GuideStep(
      GuidePhase.after,
      'Palitan ang takip kapag nabasa o nadumihan, at panatilihing '
          'malinis ang bahagi.',
      'Ang basa o maruming takip ay nagpapadami ng mikrobyo.',
    ),
    _checkInfectionTl,
  ],
  'bruise': [
    GuideStep(
      GuidePhase.before,
      'Ihanda ang malinis na tela o tuwalya at cold pack o yelo. '
          'Kung walang cold pack, gumamit ng supot ng yelo o frozen na '
          'gulay na nakabalot sa tela.',
      'Dapat nakabalot ang malamig na bagay; huwag itong ilapat '
          'nang direkta sa balat.',
    ),
    GuideStep(
      GuidePhase.during,
      'Ipahinga ang pasa at iwasan ang karagdagang pagkabunggo.',
      'Naiiwasang mas masaktan pa ang bahaging ito.',
    ),
    GuideStep(
      GuidePhase.during,
      'Maglagay ng malamig na compress (nakabalot, hindi direkta sa balat) '
          'sa loob ng 15-20 minuto.',
      'Binabawasan ng lamig ang pamamaga at sakit, at ang yelong direktang '
          'nakadikit ay maaaring makasira sa balat.',
    ),
    GuideStep(
      GuidePhase.during,
      'Itaas ang bahaging ito nang mas mataas kaysa puso kung posible.',
      'Nakakatulong para umagos palayo ang likido sa bahaging ito.',
    ),
    GuideStep(
      GuidePhase.after,
      'Pagkalipas ng 48 oras, makakatulong ang maligamgam na compress sa '
          'paggaling.',
      'Pinapadami ng init ang daloy ng dugo, na tumutulong mawala ang '
          'pasa.',
    ),
    GuideStep(
      GuidePhase.after,
      'Itala ang laki at kulay ng pasa sa susunod na ilang araw.',
      'Para mapansin kung lumalala sa halip na gumagaling.',
    ),
    GuideStep(
      GuidePhase.after,
      'Magpatingin sa healthcare professional kung dumadami ang pamamaga o '
          'sakit, o kung namamanhid o hirap igalaw ang bahaging ito.',
      'Maaaring senyales ang mga ito ng mas malalim na pinsala.',
    ),
  ],
  'swelling': [
    GuideStep(
      GuidePhase.before,
      'Ihanda ang malinis na tela o tuwalya at cold pack o yelo. '
          'Kung walang cold pack, gumamit ng supot ng yelo o frozen na '
          'gulay na nakabalot sa tela.',
      'Dapat nakabalot ang malamig na bagay; huwag itong ilapat '
          'nang direkta sa balat.',
    ),
    GuideStep(
      GuidePhase.during,
      'Ipahinga ang namamagang bahagi.',
      'Ang paggalaw ay maaaring magpalala ng pamamaga.',
    ),
    GuideStep(
      GuidePhase.during,
      'Maglagay ng malamig na compress (nakabalot, hindi direkta sa balat) '
          'sa loob ng 15-20 minuto.',
      'Nakakatulong ang lamig na bawasan ang pamamaga at sakit, at ang '
          'yelong direktang nakadikit ay maaaring makasira sa balat.',
    ),
    GuideStep(
      GuidePhase.during,
      'Itaas ang bahaging ito nang mas mataas kaysa puso kung posible.',
      'Nakakatulong para umagos palayo ang likido sa bahaging ito.',
    ),
    GuideStep(
      GuidePhase.during,
      'Iwasan ang init o mabigat na gawain sa bahaging ito sa unang araw.',
      'Ang init at mabigat na gawain ay maaaring magpalala ng pamamaga.',
    ),
    GuideStep(
      GuidePhase.after,
      'Bantayan kung paano nagbabago ang pamamaga sa susunod na 24-48 oras.',
      'Ang pamamagang patuloy na lumalaki ay kailangang ipatingin sa '
          'propesyonal.',
    ),
    GuideStep(
      GuidePhase.after,
      'Humingi agad ng medikal na tulong kung kumakalat ang pamamaga sa '
          'mukha, labi, o lalamunan, o kung nahihirapan kang huminga o '
          'lumunok.',
      'Maaari itong malubhang allergic reaction.',
    ),
  ],
  'rash': [
    GuideStep(
      GuidePhase.before,
      'Maghugas ng kamay gamit ang sabon at tubig.',
      'Para hindi madikit ang mikrobyo mula sa kamay sa iritadong '
          'balat.',
    ),
    GuideStep(
      GuidePhase.before,
      'Maghanda ng malinis at maligamgam na tubig at malambot at '
          'malinis na tuwalya (o malinis at malambot na tela).',
      'Mas banayad sa iritadong balat ang maligamgam na tubig at '
          'malambot na tuwalya.',
    ),
    GuideStep(
      GuidePhase.during,
      'Iwasang kamutin ang apektadong bahagi.',
      'Ang pagkamot ay maaaring makasugat sa balat at humantong sa '
          'impeksyon.',
    ),
    GuideStep(
      GuidePhase.during,
      'Dahan-dahang hugasan ang apektadong bahagi gamit ang banayad'
          ' na sabon at maligamgam na tubig. Alisin ang anumang dumi sa'
          ' ibabaw.',
      'Natatanggal ang mga nakakairita at dumi nang hindi natutuyo '
          'ang balat.',
    ),
    GuideStep(
      GuidePhase.during,
      'Pagkatapos maghugas, hayaang matuyo sa hangin ang balat. '
          'Huwag itong kuskusin ng tuwalya, at huwag takpan ang bahagi.',
      'Ang pagkuskos ay maaaring magpalala ng pantal, at ang hindi '
          'natatakpang bahagi ay kusang natutuyo.',
    ),
    GuideStep(
      GuidePhase.during,
      'Maglagay ng banayad na moisturizer na walang pabango o '
          'nakakapagpaginhawang lotion kung meron.',
      'Pinapaginhawa ang tuyo at makating balat nang hindi '
          'nagdaragdag ng nakakairita.',
    ),
    GuideStep(
      GuidePhase.during,
      'Protektahan ang mukha mula sa direktang sikat ng araw, at '
          'takpan ng maluwag na damit ang iba pang apektadong balat.',
      'Ang araw ay maaaring makairita sa balat na sensitibo na.',
    ),
    GuideStep(
      GuidePhase.during,
      'Iwasan ang mga kilalang nakakairita o allergen kung may '
          'natukoy ka.',
      'Ang patuloy na pagkakalantad ay maaaring magpalala ng '
          'pantal.',
    ),
    GuideStep(
      GuidePhase.after,
      'Itala kung kailan nagsimula ang pantal at anumang bago na '
          'nadikit o nakain mo.',
      'Makakatulong ito sa iyo at sa health professional na malaman'
          ' ang sanhi.',
    ),
    GuideStep(
      GuidePhase.after,
      'Kumonsulta sa doktor para sa pormal na pagsusuri kung hindi '
          'gumaganda ang pantal sa loob ng ilang araw o paulit-ulit '
          'itong bumabalik.',
      'Makikita ng doktor ang sanhi at makapagbibigay ng tamang '
          'gamutan.',
    ),
    GuideStep(
      GuidePhase.after,
      'Humingi agad ng medikal na tulong kung mabilis kumakalat ang'
          ' pantal o may kasamang hirap sa paghinga o pamamaga ng '
          'mukha.',
      'Maaaring senyales ang mga ito ng malubhang allergic '
          'reaction.',
    ),
  ],
  'other_skin_issue': [
    GuideStep(
      GuidePhase.before,
      'Maghugas ng kamay gamit ang sabon at tubig. Magsuot ng malinis na '
          'disposable na guwantes kung may sugat o dumudugo ang balat.',
      'Para hindi madikit ang mikrobyo mula sa kamay sa apektadong balat.',
    ),
    GuideStep(
      GuidePhase.before,
      'Maghanda ng malinis at maligamgam na tubig at malambot at '
          'malinis na tuwalya (o malinis at malambot na tela).',
      'Mas banayad sa iritadong balat ang maligamgam na tubig at '
          'malambot na tuwalya.',
    ),
    GuideStep(
      GuidePhase.during,
      'Panatilihing malinis ang apektadong bahagi.',
      'Ang malinis na balat ay mas maliit ang tsansang magka-impeksyon.',
    ),
    GuideStep(
      GuidePhase.during,
      'Magbigay ng banayad na first aid na angkop sa nakikita mo '
          '(paglilinis, malamig na compress na nakabalot sa tela, o pahinga '
          'kung kailangan).',
      'Ang banayad na pag-aalaga ay hindi magpapalala sa hindi pa tiyak '
          'na problema.',
    ),
    GuideStep(
      GuidePhase.during,
      'Iwasang pwersahin ang nasugatang bahagi.',
      'Ang pwersa ay maaaring magpalala ng sakit at pinsala.',
    ),
    GuideStep(
      GuidePhase.after,
      'Bantayan ang bahagi para sa anumang pagbabago sa susunod na araw.',
      'Ipinapakita ng mga pagbabago kung gumagaling o lumalala ito.',
    ),
    GuideStep(
      GuidePhase.after,
      'Kung hindi ka sigurado kung ano ang kinakaharap mo, mag-'
          'ingat sa pag-aalaga at bantayang mabuti. Kumonsulta sa '
          'doktor para sa pormal na pagsusuri kung lumala ito o hindi '
          'bumuti.',
      'Pinakaligtas na ipasuri sa propesyonal ang hindi malinaw na '
          'problema.',
    ),
  ],
};
