class PaymentRecord {
  String id;
  double amount;
  DateTime date;
  String comment;

  PaymentRecord({required this.id, required this.amount, required this.date, this.comment = ''});

  Map<String, dynamic> toJson() => {'id': id, 'amount': amount, 'date': date.toIso8601String(), 'comment': comment};
  factory PaymentRecord.fromJson(Map<String, dynamic> j) => PaymentRecord(
    id: j['id'],
    amount: (j['amount'] as num).toDouble(),
    date: DateTime.parse(j['date']),
    comment: j['comment'] ?? '',
  );
}

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
  String? photoPath; // Прикрепленное фото чека / расписки
  List<PaymentRecord> payments;

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
    this.photoPath,
    List<PaymentRecord>? payments,
  }) : payments = payments ?? [];

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
    'photoPath': photoPath,
    'payments': payments.map((p) => p.toJson()).toList(),
  };

  factory Debt.fromJson(Map<String, dynamic> j) => Debt(
    id: j['id'],
    personName: j['personName'] ?? '',
    phone: j['phone'] ?? '',
    amount: (j['amount'] as num).toDouble(),
    initialAmount: ((j['initialAmount'] ?? j['amount']) as num).toDouble(),
    type: j['type'] ?? 'they_owe',
    createdAt: DateTime.parse(j['createdAt']),
    dueDate: j['dueDate'] != null ? DateTime.parse(j['dueDate']) : null,
    isPaid: j['isPaid'] ?? false,
    note: j['note'] ?? '',
    photoPath: j['photoPath'],
    payments: j['payments'] != null ? (j['payments'] as List).map((p) => PaymentRecord.fromJson(p)).toList() : [],
  );
}

// Группировка всех долгов одного человека в единую карточку
class PersonGroup {
  final String personName;
  final String phone;
  final List<Debt> debts;

  PersonGroup({required this.personName, required this.phone, required this.debts});

  double get totalTheyOwe => debts.where((d) => d.type == 'they_owe' && !d.isPaid).fold(0.0, (s, d) => s + d.amount);
  double get totalIOwe => debts.where((d) => d.type == 'i_owe' && !d.isPaid).fold(0.0, (s, d) => s + d.amount);
  double get netBalance => totalTheyOwe - totalIOwe;
  bool get hasActiveDebts => debts.any((d) => !d.isPaid);
}

class ChecklistItem {
  String text;
  bool done;
  ChecklistItem({required this.text, this.done = false});
  Map<String, dynamic> toJson() => {'text': text, 'done': done};
  factory ChecklistItem.fromJson(Map<String, dynamic> j) => ChecklistItem(text: j['text'] ?? '', done: j['done'] ?? false);
}

class NoteItem {
  String id;
  String title;
  String content;
  DateTime updatedAt;
  bool isPinned;
  int colorIndex;
  String? photoPath;
  List<ChecklistItem> checklist;

  NoteItem({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
    this.isPinned = false,
    this.colorIndex = 0,
    this.photoPath,
    List<ChecklistItem>? checklist,
  }) : checklist = checklist ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'updatedAt': updatedAt.toIso8601String(),
    'isPinned': isPinned,
    'colorIndex': colorIndex,
    'photoPath': photoPath,
    'checklist': checklist.map((c) => c.toJson()).toList(),
  };

  factory NoteItem.fromJson(Map<String, dynamic> j) => NoteItem(
    id: j['id'],
    title: j['title'] ?? '',
    content: j['content'] ?? '',
    updatedAt: DateTime.parse(j['updatedAt']),
    isPinned: j['isPinned'] ?? false,
    colorIndex: j['colorIndex'] ?? 0,
    photoPath: j['photoPath'],
    checklist: j['checklist'] != null ? (j['checklist'] as List).map((c) => ChecklistItem.fromJson(c)).toList() : [],
  );
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  final bool isOffline;
  ChatMessage({required this.text, required this.isUser, required this.time, this.isOffline = false});
}
