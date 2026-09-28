import 'dart:convert';

class Goal {
  String id;
  String title;
  String icon;
  double target;  // Хранится в базовой валюте (RUB)
  double current; // Хранится в базовой валюте (RUB)
  String originalCurrency;
  String? deadline; // YYYY-MM-DD
  int createdAt;
  int? completedAt;
  bool completionShown;

  Goal({
    required this.id,
    required this.title,
    required this.icon,
    required this.target,
    required this.current,
    required this.originalCurrency,
    this.deadline,
    required this.createdAt,
    this.completedAt,
    this.completionShown = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'icon': icon,
    'target': target,
    'current': current,
    'originalCurrency': originalCurrency,
    'deadline': deadline,
    'createdAt': createdAt,
    'completedAt': completedAt,
    'completionShown': completionShown,
  };

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
    id: j['id'].toString(),
    title: j['title'] ?? '',
    icon: j['icon'] ?? 'target',
    target: (j['target'] as num).toDouble(),
    current: (j['current'] as num).toDouble(),
    originalCurrency: j['originalCurrency'] ?? 'RUB',
    deadline: j['deadline'],
    createdAt: j['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
    completedAt: j['completedAt'],
    completionShown: j['completionShown'] ?? false,
  );
}

class TransactionRecord {
  String id;
  int date;
  String type; // 'income' или 'expense'
  double amount;
  String cur;
  double rub;
  String note;
  bool isAuto;
  String? goalId;
  String? goalTitle;
  bool affectsGoal;

  TransactionRecord({
    required this.id,
    required this.date,
    required this.type,
    required this.amount,
    required this.cur,
    required this.rub,
    this.note = '',
    this.isAuto = false,
    this.goalId,
    this.goalTitle,
    this.affectsGoal = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'type': type,
    'amount': amount,
    'cur': cur,
    'rub': rub,
    'note': note,
    'isAuto': isAuto,
    'goalId': goalId,
    'goalTitle': goalTitle,
    'affectsGoal': affectsGoal,
  };

  factory TransactionRecord.fromJson(Map<String, dynamic> j) => TransactionRecord(
    id: j['id'].toString(),
    date: j['date'] ?? DateTime.now().millisecondsSinceEpoch,
    type: j['type'] ?? 'income',
    amount: (j['amount'] as num).toDouble(),
    cur: j['cur'] ?? 'RUB',
    rub: (j['rub'] as num).toDouble(),
    note: j['note'] ?? '',
    isAuto: j['isAuto'] ?? false,
    goalId: j['goalId'],
    goalTitle: j['goalTitle'],
    affectsGoal: j['affectsGoal'] ?? false,
  );
}
