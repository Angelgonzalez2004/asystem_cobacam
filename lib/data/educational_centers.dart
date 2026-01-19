// lib/data/educational_centers.dart

/// A list of educational centers with their details.
/// Each map contains 'name', 'municipio' (municipality), and 'clave' (school ID).
const List<Map<String, String>> educationalCenters = [
  {
    'name': 'Plantel 01 Hecelchakán',
    'municipio': 'Hecelchakán',
    'clave': '04ECB0001M',
  },
  {
    'name': 'Plantel 02 Candelaria',
    'municipio': 'Candelaria',
    'clave': '04ECB0002L',
  },
  {
    'name': 'Plantel 03 Escárcega',
    'municipio': 'Escárcega',
    'clave': '04ECB0003K',
  },
  {
    'name': 'Plantel 04 Seybaplaya',
    'municipio': 'Champotón',
    'clave': '04ECB0004J',
  },
  {
    'name': 'Plantel 05 Atasta',
    'municipio': 'Carmen',
    'clave': '04ECB0005I',
  },
  {
    'name': 'Plantel 06 Mamantel',
    'municipio': 'Carmen',
    'clave': '04ECB0006H',
  },
  {
    'name': 'Plantel 07 Tenabo',
    'municipio': 'Tenabo',
    'clave': '04ECB0007G',
  },
  {
    'name': 'Plantel 08 Nunkiní',
    'municipio': 'Calkiní',
    'clave': '04ECB0008F',
  },
  {
    'name': 'Plantel 09 Champotón',
    'municipio': 'Champotón',
    'clave': '04ECB0009E',
  },
  {
    'name': 'Plantel 10 Chicbul',
    'municipio': 'Carmen',
    'clave': '04ECB0010U',
  },
  {
    'name': 'Plantel 11 Bécal',
    'municipio': 'Calkiní',
    'clave': '04ECB0011T',
  },
  {
    'name': 'Plantel 13 Calkiní',
    'municipio': 'Calkiní',
    'clave': '04ECB0013R',
  },
  {
    'name': 'Plantel 14 Xpujil',
    'municipio': 'Calakmul',
    'clave': '04ECB0014Q',
  },
  {
    'name': 'Plantel 15 Ley Federal de Reforma Agraria',
    'municipio': 'Champotón',
    'clave': '04ECB0015P',
  },
  {
    'name': 'Plantel 16 Adolfo López Mateos',
    'municipio': 'Escárcega',
    'clave': '04ECB0016O',
  },
  {
    'name': 'Plantel 17 Nuevo Progreso',
    'municipio': 'Carmen',
    'clave': '04ECB0017N',
  },
  {
    'name': 'Plantel 18 Xbacab',
    'municipio': 'Champotón',
    'clave': '04ECB0018M',
  },
  {
    'name': 'Plantel 19 Lerma',
    'municipio': 'Campeche',
    'clave': '04ECB0019L',
  },
  {
    'name': 'Plantel 20 Don Samuel',
    'municipio': 'Escárcega',
    'clave': '04ECB0020A',
  },
  {
    'name': 'Plantel 21 La Libertad',
    'municipio': 'Escárcega',
    'clave': '04ECB0021Z',
  },
  {
    'name': 'Emsad 01 Ukúm',
    'municipio': 'Hopelchén',
    'clave': '04EMS0001T',
  },
  {
    'name': 'Emsad 03 Isla Aguada',
    'municipio': 'Carmen',
    'clave': '04EMS0003R',
  },
  {
    'name': 'Emsad 04 La Esmeralda',
    'municipio': 'Candelaria',
    'clave': '04EMS0004Q',
  },
  {
    'name': 'Emsad 05 Bolonchén de Rejón',
    'municipio': 'Hopelchén',
    'clave': '04EMS0005P',
  },
  {
    'name': 'Emsad 06 Sihochac',
    'municipio': 'Champotón',
    'clave': '04EMS0006O',
  },
  {
    'name': 'Emsad 07 El Desengaño',
    'municipio': 'Candelaria',
    'clave': '04EMS0007N',
  },
  {
    'name': 'Emsad 08 El Civalito',
    'municipio': 'Calakmul',
    'clave': '04EMS0008M',
  },
  {
    'name': 'Emsad 09 El Aguacatal',
    'municipio': 'Carmen',
    'clave': '04EMS0009L',
  },
  {
    'name': 'Emsad 11 Dzibalchén',
    'municipio': 'Hopelchén',
    'clave': '04EMS0011Z',
  },
  {
    'name': 'Emsad 12 El Juncal',
    'municipio': 'Palizada',
    'clave': '04EMS0012Z',
  },
  {
    'name': 'Emsad 13 El Carmen II',
    'municipio': 'Calakmul',
    'clave': '04EMS0013Y',
  },
  {
    'name': 'Emsad 14 El Tesoro',
    'municipio': 'Calakmul',
    'clave': '04EMS0014X',
  },
  {
    'name': 'Emsad 18 Chiná',
    'municipio': 'Campeche',
    'clave': '04EMS0018T',
  },
  {
    'name': 'Emsad 19 Conquista Campesina',
    'municipio': 'Candelaria',
    'clave': '04EMS0019S',
  },
  {
    'name': 'Emsad 20 Pich',
    'municipio': 'Campeche',
    'clave': '04EMS0020H',
  },
  {
    'name': 'Emsad 21 El Naranjo',
    'municipio': 'Candelaria',
    'clave': '04EMS0021G',
  },
  {
    'name': 'Emsad 22 Constitución',
    'municipio': 'Calakmul',
    'clave': '04EMS0022F',
  },
];

/// Retrieves the details of an educational center by its full name.
/// Returns a map containing 'name', 'municipio', and 'clave' if found,
/// otherwise returns a map with default 'N/A' values.
Map<String, String> getEducationalCenterInfo(String campusName) {
  try {
    return educationalCenters.firstWhere(
      (center) => center['name'] == campusName,
      orElse: () => {
        'name': 'N/A',
        'municipio': 'N/A',
        'clave': 'N/A',
      },
    );
  } catch (e) {
    // This catch block is for completeness, firstWhere with orElse handles not found.
    return {
      'name': 'N/A',
      'municipio': 'N/A',
      'clave': 'N/A',
    };
  }
}

/// Retrieves the details of an educational center by a partial match in its name.
/// Returns a map containing 'name', 'municipio', and 'clave' if found,
/// otherwise returns a map with default 'N/A' values.
Map<String, String> getEducationalCenterInfoByPartialName(String partialName) {
  try {
    return educationalCenters.firstWhere(
      (center) => center['name']!.toLowerCase().contains(partialName.toLowerCase()),
      orElse: () => {
        'name': 'N/A',
        'municipio': 'N/A',
        'clave': 'N/A',
      },
    );
  } catch (e) {
    return {
      'name': 'N/A',
      'municipio': 'N/A',
      'clave': 'N/A',
    };
  }
}
