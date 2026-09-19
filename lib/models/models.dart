class Debt {
  String id;
  String personName;
  String phone;
  double amount;
  double initialAmount;
  String type; // 'they_owe' (мне должны) или 'i_owe' (я должен)
  DateTime createdAt;
  DateTime? dueDate;
  bool isPaid;
  String note;

  Debt({
    required this.id,
    required this.personName,
    this.phone = '',
    required this.amount,
    required this.initialAmount,
    required this.type,
    required this.createdAt,
    this.dueDate,
    this.isPaid = false,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'personName': personName,
    'phone': phone,
    'amount': amount,
    'initialAmount': initialAmount,
    'type': type,
    'createdAt': createdAt.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
    'isPaid': isPaid,
    'note': note,
  };

  factory Debt.fromJson(Map<String, dynamic> json) => Debt(
    id: json['id'],
    personName: json['personName'] ?? '',
    phone: json['phone'] ?? '',
    amount: (json['amount'] as num).toDouble(),
    initialAmount: ((json['initialAmount'] ?? json['amount']) as num).toDouble(),
    type: json['type'] ?? 'they_owe',
    createdAt: DateTime.parse(json['createdAt']),
    dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
    isPaid: json['isPaid'] ?? false,
    note: json['note'] ?? '',
  );
}

class NoteItem {
  String id;
  String title;
  String content;
  DateTime createdAt;
  int colorIndex;

  NoteItem({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    this.colorIndex = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'colorIndex': colorIndex,
  };

  factory NoteItem.fromJson(Map<String, dynamic> json) => NoteItem(
    id: json['id'],
    title: json['title'] ?? '',
    content: json['content'] ?? '',
    createdAt: DateTime.parse(json['createdAt']),
    colorIndex: json['colorIndex'] ?? 0,
  );
}
