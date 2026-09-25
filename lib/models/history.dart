class CalcHistoryItem {
  final String id;
  final String expression;
  final String result;
  final DateTime timestamp;

  CalcHistoryItem({
    required this.id,
    required this.expression,
    required this.result,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'expression': expression,
    'result': result,
    'timestamp': timestamp.toIso8601String(),
  };

  factory CalcHistoryItem.fromJson(Map<String, dynamic> j) => CalcHistoryItem(
    id: j['id'] ?? '',
    expression: j['expression'] ?? '',
    result: j['result'] ?? '',
    timestamp: DateTime.parse(j['timestamp']),
  );
}
