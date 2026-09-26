class Goal {
  String id; String title; String icon; double target; double current;
  String currency; String? deadline; int createdAt; bool completionShown; int? completedAt;
  Goal({required this.id, required this.title, this.icon='target', required this.target,
        this.current=0, this.currency='RUB', this.deadline, required this.createdAt,
        this.completionShown=false, this.completedAt});
  double get pct => target>0 ? (current/target).clamp(0,1)*100 : 0;
  bool get isDone => current >= target;
  Map<String,dynamic> toJson()=>({
    'id':id,'title':title,'icon':icon,'target':target,'current':current,
    'currency':currency,'deadline':deadline,'createdAt':createdAt,
    'completionShown':completionShown,'completedAt':completedAt});
  factory Goal.fromJson(Map<String,dynamic> j)=>Goal(
    id:j['id'],title:j['title'],icon:j['icon']??'target',
    target:(j['target'] as num).toDouble(),current:(j['current'] as num?)?.toDouble()??0,
    currency:j['currency']??'RUB',deadline:j['deadline'],createdAt:j['createdAt'] as int? ?? 0,
    completionShown:j['completionShown']??false,completedAt:j['completedAt']);
}

class TxRecord {
  String id; int date; String type; double rub; String cur; double amount;
  String? note; bool isAuto; String? goalId; String? goalTitle; bool affectsGoal;
  TxRecord({required this.id,required this.date,required this.type,required this.rub,
    required this.cur,required this.amount,this.note,this.isAuto=false,
    this.goalId,this.goalTitle,this.affectsGoal=false});
  Map<String,dynamic> toJson()=>({
    'id':id,'date':date,'type':type,'rub':rub,'cur':cur,'amount':amount,
    'note':note,'isAuto':isAuto,'goalId':goalId,'goalTitle':goalTitle,'affectsGoal':affectsGoal});
  factory TxRecord.fromJson(Map<String,dynamic> j)=>TxRecord(
    id:j['id'],date:j['date'],type:j['type'],rub:(j['rub'] as num).toDouble(),
    cur:j['cur'],amount:(j['amount'] as num).toDouble(),note:j['note'],
    isAuto:j['isAuto']??false,goalId:j['goalId'],goalTitle:j['goalTitle'],
    affectsGoal:j['affectsGoal']??false);
}
