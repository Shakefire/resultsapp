// lib/features/result_submission/models/result_figures.dart

/// Official polling unit election figures model with mathematical validation.
class ResultFigures {
  const ResultFigures({
    this.registeredVoters = 0,
    this.accreditedVoters = 0,
    this.partyVotes = const {},
    this.rejectedVotes = 0,
  });

  final int registeredVoters;
  final int accreditedVoters;
  final Map<String, int> partyVotes;
  final int rejectedVotes;

  /// Sum of all votes recorded across all contesting political parties.
  int get totalValidVotes {
    return partyVotes.values.fold(0, (sum, count) => sum + count);
  }

  /// Total ballots cast = valid votes + rejected ballots.
  int get totalVotesCast => totalValidVotes + rejectedVotes;

  /// Validation: Accredited voters cannot exceed registered voters.
  bool get isAccreditedValid =>
      accreditedVoters >= 0 && accreditedVoters <= registeredVoters;

  /// Validation: Total votes cast cannot exceed accredited voters.
  bool get isVotesCastValid =>
      totalVotesCast >= 0 && totalVotesCast <= accreditedVoters;

  /// Full validation check.
  bool get isValid {
    return registeredVoters > 0 &&
        isAccreditedValid &&
        isVotesCastValid &&
        partyVotes.isNotEmpty;
  }

  ResultFigures copyWith({
    int? registeredVoters,
    int? accreditedVoters,
    Map<String, int>? partyVotes,
    int? rejectedVotes,
  }) {
    return ResultFigures(
      registeredVoters: registeredVoters ?? this.registeredVoters,
      accreditedVoters: accreditedVoters ?? this.accreditedVoters,
      partyVotes: partyVotes ?? Map.from(this.partyVotes),
      rejectedVotes: rejectedVotes ?? this.rejectedVotes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'registeredVoters': registeredVoters,
      'accreditedVoters': accreditedVoters,
      'partyVotes': partyVotes,
      'rejectedVotes': rejectedVotes,
      'totalValidVotes': totalValidVotes,
      'totalVotesCast': totalVotesCast,
    };
  }

  factory ResultFigures.fromJson(Map<String, dynamic> json) {
    return ResultFigures(
      registeredVoters: json['registeredVoters'] as int? ?? 0,
      accreditedVoters: json['accreditedVoters'] as int? ?? 0,
      partyVotes: Map<String, int>.from(json['partyVotes'] as Map? ?? {}),
      rejectedVotes: json['rejectedVotes'] as int? ?? 0,
    );
  }
}
