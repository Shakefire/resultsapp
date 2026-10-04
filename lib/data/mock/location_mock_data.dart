// lib/data/mock/location_mock_data.dart

// Structured mock Nigerian administrative location data.
// Replace [LocationRepository] implementation to connect to real API later.


class LocationState {
  const LocationState({required this.id, required this.name, required this.lgas});
  final String id;
  final String name;
  final List<LocationLga> lgas;
}

class LocationLga {
  const LocationLga({required this.id, required this.name, required this.wards});
  final String id;
  final String name;
  final List<LocationWard> wards;
}

class LocationWard {
  const LocationWard({required this.id, required this.name, required this.pollingUnits});
  final String id;
  final String name;
  final List<LocationPollingUnit> pollingUnits;
}

class LocationPollingUnit {
  const LocationPollingUnit({required this.id, required this.name});
  final String id;
  final String name;
}

/// Repository abstraction for location data.
/// Swap the implementation to replace mock with API data.
abstract class LocationRepository {
  List<LocationState> getStates();
  List<LocationLga> getLgas(String stateId);
  List<LocationWard> getWards(String lgaId);
  List<LocationPollingUnit> getPollingUnits(String wardId);
}

/// Mock implementation — simulates real Nigerian administrative hierarchy.
class MockLocationRepository implements LocationRepository {
  static final MockLocationRepository _instance = MockLocationRepository._();
  factory MockLocationRepository() => _instance;
  MockLocationRepository._();

  static const List<LocationState> _states = [
    LocationState(
      id: 'FCT',
      name: 'Federal Capital Territory',
      lgas: [
        LocationLga(
          id: 'FCT-AMAC',
          name: 'Abuja Municipal Area Council',
          wards: [
            LocationWard(
              id: 'FCT-AMAC-W01',
              name: 'Central Business District',
              pollingUnits: [
                LocationPollingUnit(id: 'FCT-AMAC-W01-PU001', name: 'PU 001 — CBQ Secretariat'),
                LocationPollingUnit(id: 'FCT-AMAC-W01-PU002', name: 'PU 002 — Area 1 Court'),
                LocationPollingUnit(id: 'FCT-AMAC-W01-PU003', name: 'PU 003 — NTA Junction'),
              ],
            ),
            LocationWard(
              id: 'FCT-AMAC-W02',
              name: 'Garki 1',
              pollingUnits: [
                LocationPollingUnit(id: 'FCT-AMAC-W02-PU001', name: 'PU 001 — Garki Primary School'),
                LocationPollingUnit(id: 'FCT-AMAC-W02-PU002', name: 'PU 002 — Area 3 Clinic'),
                LocationPollingUnit(id: 'FCT-AMAC-W02-PU003', name: 'PU 003 — Phase 2 Junction'),
              ],
            ),
            LocationWard(
              id: 'FCT-AMAC-W03',
              name: 'Garki 2',
              pollingUnits: [
                LocationPollingUnit(id: 'FCT-AMAC-W03-PU001', name: 'PU 001 — Area 7 Hospital Gate'),
                LocationPollingUnit(id: 'FCT-AMAC-W03-PU002', name: 'PU 002 — Bank Road'),
              ],
            ),
            LocationWard(
              id: 'FCT-AMAC-W04',
              name: 'Wuse',
              pollingUnits: [
                LocationPollingUnit(id: 'FCT-AMAC-W04-PU001', name: 'PU 001 — Zone 3 Market'),
                LocationPollingUnit(id: 'FCT-AMAC-W04-PU002', name: 'PU 002 — Zone 4 School'),
                LocationPollingUnit(id: 'FCT-AMAC-W04-PU003', name: 'PU 003 — Zone 5 Police Station'),
              ],
            ),
          ],
        ),
        LocationLga(
          id: 'FCT-BWARI',
          name: 'Bwari',
          wards: [
            LocationWard(
              id: 'FCT-BWARI-W01',
              name: 'Bwari Ward',
              pollingUnits: [
                LocationPollingUnit(id: 'FCT-BWARI-W01-PU001', name: 'PU 001 — Bwari Township School'),
                LocationPollingUnit(id: 'FCT-BWARI-W01-PU002', name: 'PU 002 — Bwari Market'),
              ],
            ),
            LocationWard(
              id: 'FCT-BWARI-W02',
              name: 'Ushafa',
              pollingUnits: [
                LocationPollingUnit(id: 'FCT-BWARI-W02-PU001', name: 'PU 001 — Ushafa Village Hall'),
                LocationPollingUnit(id: 'FCT-BWARI-W02-PU002', name: 'PU 002 — Ushafa Primary School'),
              ],
            ),
          ],
        ),
        LocationLga(
          id: 'FCT-GWAGWALADA',
          name: 'Gwagwalada',
          wards: [
            LocationWard(
              id: 'FCT-GWAG-W01',
              name: 'Gwagwalada Central',
              pollingUnits: [
                LocationPollingUnit(id: 'FCT-GWAG-W01-PU001', name: 'PU 001 — Town Hall'),
                LocationPollingUnit(id: 'FCT-GWAG-W01-PU002', name: 'PU 002 — Market Square'),
              ],
            ),
            LocationWard(
              id: 'FCT-GWAG-W02',
              name: 'Gwagwalada North',
              pollingUnits: [
                LocationPollingUnit(id: 'FCT-GWAG-W02-PU001', name: 'PU 001 — Community Centre'),
              ],
            ),
          ],
        ),
        LocationLga(
          id: 'FCT-KUJE',
          name: 'Kuje',
          wards: [
            LocationWard(
              id: 'FCT-KUJE-W01',
              name: 'Kuje Ward',
              pollingUnits: [
                LocationPollingUnit(id: 'FCT-KUJE-W01-PU001', name: 'PU 001 — Kuje Secondary School'),
                LocationPollingUnit(id: 'FCT-KUJE-W01-PU002', name: 'PU 002 — Kuje Central Mosque'),
              ],
            ),
          ],
        ),
        LocationLga(
          id: 'FCT-KWALI',
          name: 'Kwali',
          wards: [
            LocationWard(
              id: 'FCT-KWALI-W01',
              name: 'Kwali Ward',
              pollingUnits: [
                LocationPollingUnit(id: 'FCT-KWALI-W01-PU001', name: 'PU 001 — Kwali Town Hall'),
                LocationPollingUnit(id: 'FCT-KWALI-W01-PU002', name: 'PU 002 — Kwali Primary School'),
              ],
            ),
          ],
        ),
        LocationLga(
          id: 'FCT-ABAJI',
          name: 'Abaji',
          wards: [
            LocationWard(
              id: 'FCT-ABAJI-W01',
              name: 'Abaji Ward',
              pollingUnits: [
                LocationPollingUnit(id: 'FCT-ABAJI-W01-PU001', name: 'PU 001 — Abaji Town Hall'),
              ],
            ),
          ],
        ),
      ],
    ),
    LocationState(
      id: 'LAGOS',
      name: 'Lagos',
      lgas: [
        LocationLga(
          id: 'LAGOS-IKEJA',
          name: 'Ikeja',
          wards: [
            LocationWard(
              id: 'LAGOS-IKEJA-W01',
              name: 'Ikeja Ward A',
              pollingUnits: [
                LocationPollingUnit(id: 'LAGOS-IKEJA-W01-PU001', name: 'PU 001 — Ikeja Primary School'),
                LocationPollingUnit(id: 'LAGOS-IKEJA-W01-PU002', name: 'PU 002 — Alausa Secretariat'),
              ],
            ),
            LocationWard(
              id: 'LAGOS-IKEJA-W02',
              name: 'Ikeja Ward B',
              pollingUnits: [
                LocationPollingUnit(id: 'LAGOS-IKEJA-W02-PU001', name: 'PU 001 — GRA Phase 1'),
                LocationPollingUnit(id: 'LAGOS-IKEJA-W02-PU002', name: 'PU 002 — Allen Avenue'),
              ],
            ),
          ],
        ),
        LocationLga(
          id: 'LAGOS-OSHODI',
          name: 'Oshodi/Isolo',
          wards: [
            LocationWard(
              id: 'LAGOS-OSHODI-W01',
              name: 'Oshodi Ward 1',
              pollingUnits: [
                LocationPollingUnit(id: 'LAGOS-OSHODI-W01-PU001', name: 'PU 001 — Oshodi Market Gate'),
                LocationPollingUnit(id: 'LAGOS-OSHODI-W01-PU002', name: 'PU 002 — Isolo Estate'),
              ],
            ),
          ],
        ),
        LocationLga(
          id: 'LAGOS-SURULERE',
          name: 'Surulere',
          wards: [
            LocationWard(
              id: 'LAGOS-SUR-W01',
              name: 'Surulere Ward 1',
              pollingUnits: [
                LocationPollingUnit(id: 'LAGOS-SUR-W01-PU001', name: 'PU 001 — National Stadium Gate'),
                LocationPollingUnit(id: 'LAGOS-SUR-W01-PU002', name: 'PU 002 — Adeniran Ogunsanya'),
              ],
            ),
          ],
        ),
      ],
    ),
    LocationState(
      id: 'RIVERS',
      name: 'Rivers',
      lgas: [
        LocationLga(
          id: 'RIVERS-OBIO',
          name: 'Obio/Akpor',
          wards: [
            LocationWard(
              id: 'RIVERS-OBIO-W01',
              name: 'Rumuola Ward',
              pollingUnits: [
                LocationPollingUnit(id: 'RIVERS-OBIO-W01-PU001', name: 'PU 001 — Rumuola Junction'),
                LocationPollingUnit(id: 'RIVERS-OBIO-W01-PU002', name: 'PU 002 — Oil Mill'),
              ],
            ),
            LocationWard(
              id: 'RIVERS-OBIO-W02',
              name: 'Rumuosi Ward',
              pollingUnits: [
                LocationPollingUnit(id: 'RIVERS-OBIO-W02-PU001', name: 'PU 001 — Rumuosi School'),
              ],
            ),
          ],
        ),
        LocationLga(
          id: 'RIVERS-PHCITY',
          name: 'Port Harcourt City',
          wards: [
            LocationWard(
              id: 'RIVERS-PHC-W01',
              name: 'D/Line Ward',
              pollingUnits: [
                LocationPollingUnit(id: 'RIVERS-PHC-W01-PU001', name: 'PU 001 — D/Line Market'),
                LocationPollingUnit(id: 'RIVERS-PHC-W01-PU002', name: 'PU 002 — Garrison Junction'),
              ],
            ),
          ],
        ),
      ],
    ),
    LocationState(
      id: 'KANO',
      name: 'Kano',
      lgas: [
        LocationLga(
          id: 'KANO-NASSARAWA',
          name: 'Nassarawa',
          wards: [
            LocationWard(
              id: 'KANO-NAS-W01',
              name: 'Nassarawa Ward 1',
              pollingUnits: [
                LocationPollingUnit(id: 'KANO-NAS-W01-PU001', name: 'PU 001 — Central School'),
                LocationPollingUnit(id: 'KANO-NAS-W01-PU002', name: 'PU 002 — Post Office'),
              ],
            ),
          ],
        ),
        LocationLga(
          id: 'KANO-KANO',
          name: 'Kano Municipal',
          wards: [
            LocationWard(
              id: 'KANO-KM-W01',
              name: 'Fagge Ward',
              pollingUnits: [
                LocationPollingUnit(id: 'KANO-KM-W01-PU001', name: 'PU 001 — Fagge Primary School'),
                LocationPollingUnit(id: 'KANO-KM-W01-PU002', name: 'PU 002 — Central Mosque Gate'),
              ],
            ),
          ],
        ),
      ],
    ),
    LocationState(
      id: 'OYO',
      name: 'Oyo',
      lgas: [
        LocationLga(
          id: 'OYO-IBADAN-NE',
          name: 'Ibadan North-East',
          wards: [
            LocationWard(
              id: 'OYO-IBNE-W01',
              name: 'Iwo Road Ward',
              pollingUnits: [
                LocationPollingUnit(id: 'OYO-IBNE-W01-PU001', name: 'PU 001 — Iwo Road Junction'),
                LocationPollingUnit(id: 'OYO-IBNE-W01-PU002', name: 'PU 002 — Challenge Area'),
              ],
            ),
          ],
        ),
        LocationLga(
          id: 'OYO-IBADAN-N',
          name: 'Ibadan North',
          wards: [
            LocationWard(
              id: 'OYO-IBN-W01',
              name: 'Agodi Ward',
              pollingUnits: [
                LocationPollingUnit(id: 'OYO-IBN-W01-PU001', name: 'PU 001 — Agodi Gate School'),
              ],
            ),
          ],
        ),
      ],
    ),
  ];

  @override
  List<LocationState> getStates() => _states;

  @override
  List<LocationLga> getLgas(String stateId) {
    try {
      return _states.firstWhere((s) => s.id == stateId).lgas;
    } catch (_) {
      return [];
    }
  }

  @override
  List<LocationWard> getWards(String lgaId) {
    for (final state in _states) {
      try {
        return state.lgas.firstWhere((l) => l.id == lgaId).wards;
      } catch (_) {
        continue;
      }
    }
    return [];
  }

  @override
  List<LocationPollingUnit> getPollingUnits(String wardId) {
    for (final state in _states) {
      for (final lga in state.lgas) {
        try {
          return lga.wards.firstWhere((w) => w.id == wardId).pollingUnits;
        } catch (_) {
          continue;
        }
      }
    }
    return [];
  }
}
