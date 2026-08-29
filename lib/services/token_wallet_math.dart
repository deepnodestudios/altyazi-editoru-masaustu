/// Client-side token estimate. Must match `estimateTokens` in functions/src/billing/tokenWallet.ts.
const double kTokenCharMultiplier = 1.30;

/// P&L ledger (Gemini 3.1 Flash-Lite list). Model is still 2.5.
const double kLedgerInputUsdPerMillion = 0.25;
const double kLedgerOutputUsdPerMillion = 1.50;

/// Actual Google invoice for gemini-2.5-flash-lite.
const double kProviderInputUsdPerMillion = 0.10;
const double kProviderOutputUsdPerMillion = 0.40;

int estimateTokensFromCharCount(int charCount) {
  if (charCount <= 0) return 0;
  return (charCount * kTokenCharMultiplier).ceil();
}

/// Typical feature-film SRT text (~100 min).
const int kAvgMovieSubtitleChars = 50000;

/// Typical TV-episode SRT text (~45 min).
const int kAvgSeriesEpisodeSubtitleChars = 30000;

class TokenMediaCoverage {
  const TokenMediaCoverage({required this.movies, required this.episodes});

  final int movies;
  final int episodes;
}

/// How many average movies / TV episodes [tokens] can cover (sold amount, no bonus).
TokenMediaCoverage estimateTokenMediaCoverage(int tokens) {
  if (tokens <= 0) {
    return const TokenMediaCoverage(movies: 0, episodes: 0);
  }
  final movieCost = estimateTokensFromCharCount(kAvgMovieSubtitleChars);
  final episodeCost =
      estimateTokensFromCharCount(kAvgSeriesEpisodeSubtitleChars);
  return TokenMediaCoverage(
    movies: movieCost > 0 ? tokens ~/ movieCost : 0,
    episodes: episodeCost > 0 ? tokens ~/ episodeCost : 0,
  );
}

String formatUsd6(double value) => value.toStringAsFixed(6);

double ledgerCostUsd({required int inputTokens, required int outputTokens}) {
  return (inputTokens / 1000000) * kLedgerInputUsdPerMillion +
      (outputTokens / 1000000) * kLedgerOutputUsdPerMillion;
}

double providerCostUsd({required int inputTokens, required int outputTokens}) {
  return (inputTokens / 1000000) * kProviderInputUsdPerMillion +
      (outputTokens / 1000000) * kProviderOutputUsdPerMillion;
}

String formatTokenCount(int value, {String grouping = ','}) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    if (i > 0 && remaining % 3 == 0) {
      buffer.write(grouping);
    }
    buffer.write(digits[i]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}
