class ChallengePreset {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final double targetAmount;
  final int durationDays;
  final String trackingType;
  final String? trackedCategory;

  const ChallengePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.targetAmount,
    required this.durationDays,
    this.trackingType = 'savings',
    this.trackedCategory,
  });
}

const List<ChallengePreset> challengePresets = [
  ChallengePreset(
    id: '52week',
    name: '52-Week Savings',
    emoji: '📅',
    description: 'Save a little more each week — week 1 is 100, week 52 is 5,200. Total: 137,800.',
    targetAmount: 137800,
    durationDays: 365,
  ),
  ChallengePreset(
    id: 'emergency',
    name: 'Emergency Fund',
    emoji: '🛡️',
    description: 'Build 3 months of expenses as a safety net.',
    targetAmount: 0, // computed from spending at start time
    durationDays: 180,
  ),
  ChallengePreset(
    id: 'nofood',
    name: 'No Dining Out',
    emoji: '🥗',
    description: 'Spend nothing on dining out this month.',
    targetAmount: 0,
    durationDays: 30,
    trackingType: 'no_spend_category',
    trackedCategory: 'Food',
  ),
  ChallengePreset(
    id: 'save10k',
    name: '10K Challenge',
    emoji: '💰',
    description: 'Save 10,000 in 30 days by cutting discretionary spending.',
    targetAmount: 10000,
    durationDays: 30,
  ),
  ChallengePreset(
    id: 'vacation',
    name: 'Vacation Fund',
    emoji: '✈️',
    description: 'Save your target amount by your chosen deadline.',
    targetAmount: 0, // user sets custom target
    durationDays: 0, // user sets custom end date
  ),
  ChallengePreset(
    id: 'noimpulse',
    name: 'No Impulse Buys',
    emoji: '🛑',
    description: 'Spend nothing on Shopping this month.',
    targetAmount: 0,
    durationDays: 30,
    trackingType: 'no_spend_category',
    trackedCategory: 'Shopping',
  ),
];
