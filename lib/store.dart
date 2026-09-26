import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'models.dart';

const ALL_CUR = ['RUB','USD','EUR','TJS','CNY'];
const CUR_SYM = {'RUB':'₽','USD':'\$','EUR':'€','TJS':'SM','CNY':'¥'};
const CUR_NAME = {'RUB':'Российский рубль','USD':'Доллар США','EUR':'Евро','TJS':'Таджикский сомони','CNY':'Китайский юань'};
const CUR_FLAG = {'RUB':'🇷🇺','USD':'🇺🇸','EUR':'🇪🇺','TJS':'🇹🇯','CNY':'🇨🇳'};

class AppStore extends ChangeNotifier {
  static const _k = 'goalflow_v7';
  String? defaultCurrency;
  List<Goal> goals = [];
  List<TxRecord> txs = [];
  Map<String,double> rates = {'RUB':1,'USD':90,'EUR':99,'TJS':9.2,'CNY':12.5};
  int? ratesUpdated;
  String ratesStatus = 'default';
  bool expensesFromGoals = false;
  bool notificationsEnabled = false;
  String reportTab = 'money';
  String recMode = 'save';
  double recTarget = 0;
  double recMonths = 12;
  double recMonthly = 5000;

  List<Goal> get activeGoals => goals.where((g)=>g.completedAt==null).toList();
  List<Goal> get archivedGoals => goals.where((g)=>g.completedAt!=null).toList();
  double get totalTarget => activeGoals.fold(0.0,(s,g)=>s+g.target);
  double get totalCurrent => activeGoals.fold(0.0,(s,g)=>s+g.current);
  double get totalEarned => txs.where((t)=>t.type=='income').fold(0.0,(s,t)=>s+t.rub);
  double get totalSpent => txs.where((t)=>t.type=='expense').fold(0.0,(s,t)=>s+t.rub);

  double toRub(double a,String c)=>a*(rates[c]??1);
  double fromRub(double r,String c)=>r/(rates[c]??1);

  String fmt(double rub,[String? cur]){
    final c = cur ?? defaultCurrency ?? 'RUB';
    final v = fromRub(rub,c); final s = CUR_SYM[c]!;
    if(c=='USD') return '\$'+v.toStringAsFixed(v<100?2:0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'),(m)=>'${m[1]},');
    if(c=='EUR') return '€'+v.toStringAsFixed(v<100?2:0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'),(m)=>'${m[1]},');
    return '${v.round()} $s';
  }
  String fmtQuick(double v,String c){
    if(c=='USD') return '\$'+v.toStringAsFixed(2);
    if(c=='EUR') return '€'+v.toStringAsFixed(2);
    return '${v.abs()>=100?v.round():v.toStringAsFixed(2)} ${CUR_SYM[c]}';
  }
  String fmtDate(int ts){
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year}, ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  }
  String fmtDateShort(int ts){
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year}';
  }
  int? daysUntil(String? iso){
    if(iso==null||iso.isEmpty) return null;
    return DateTime.parse('${iso}T23:59:59').difference(DateTime.now()).inDays + 1;
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
    if(raw==null) return;
    final j = jsonDecode(raw);
    defaultCurrency = j['defaultCurrency'];
    goals = (j['goals'] as List? ?? []).map((e)=>Goal.fromJson(e)).toList();
    txs = (j['txs'] as List? ?? []).map((e)=>TxRecord.fromJson(e)).toList();
    rates = Map<String,double>.from((j['rates']??{}).map((k,v)=>MapEntry(k,(v as num).toDouble())));
    if(rates.isEmpty) rates = {'RUB':1,'USD':90,'EUR':99,'TJS':9.2,'CNY':12.5};
    ratesUpdated = j['ratesUpdated'];
    ratesStatus = j['ratesStatus']??'default';
    expensesFromGoals = j['expensesFromGoals']??false;
    notificationsEnabled = j['notificationsEnabled']??false;
    reportTab = j['reportTab']??'money';
    recMode = j['recMode']??'save';
    recTarget = (j['recTarget'] as num?)?.toDouble()??0;
    recMonths = (j['recMonths'] as num?)?.toDouble()??12;
    recMonthly = (j['recMonthly'] as num?)?.toDouble()??5000;
    notifyListeners();
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode({
      'defaultCurrency':defaultCurrency,'goals':goals.map((g)=>g.toJson()).toList(),
      'txs':txs.map((t)=>t.toJson()).toList(),'rates':rates,'ratesUpdated':ratesUpdated,
      'ratesStatus':ratesStatus,'expensesFromGoals':expensesFromGoals,
      'notificationsEnabled':notificationsEnabled,'reportTab':reportTab,
      'recMode':recMode,'recTarget':recTarget,'recMonths':recMonths,'recMonthly':recMonthly,
    }));
  }

  void setCurrency(String c){ defaultCurrency=c; save(); notifyListeners(); }
  void setRates(Map<String,double> r,String status){ rates=r; ratesUpdated=DateTime.now().millisecondsSinceEpoch; ratesStatus=status; save(); notifyListeners(); }
  void setReportTab(String t){ reportTab=t; save(); notifyListeners(); }
  void setRecMode(String m){ recMode=m; save(); notifyListeners(); }
  void toggleExpenses(){ expensesFromGoals=!expensesFromGoals; save(); notifyListeners(); }

  Future<bool> fetchRates() async {
    try {
      final res = await http.get(Uri.parse('https://open.er-api.com/v6/latest/RUB'));
      if(res.statusCode!=200) throw Exception();
      final j = jsonDecode(res.body);
      final nr = <String,double>{'RUB':1};
      for(final c in ['USD','EUR','TJS','CNY']){
        if(j['rates']!=null && j['rates'][c]!=null) nr[c] = 1.0/(j['rates'][c] as num);
      }
      setRates(nr,'ok');
      return true;
    } catch(e){ ratesStatus='error'; save(); notifyListeners(); return false; }
  }

  void addGoal(Goal g){ goals.add(g); save(); notifyListeners(); }
  void updateGoal(Goal g){ final i = goals.indexWhere((x)=>x.id==g.id); if(i>=0){goals[i]=g; save(); notifyListeners();} }
  void deleteGoal(String id){ goals.removeWhere((g)=>g.id==id); save(); notifyListeners(); }

  void archiveGoal(String id){
    final i = goals.indexWhere((g)=>g.id==id);
    if(i<0) return;
    goals[i].completedAt = DateTime.now().millisecondsSinceEpoch;
    save(); notifyListeners();
  }

  void _applyTx(TxRecord t){
    if(t.type=='income'){
      if(t.isAuto){
        final left = activeGoals.fold(0.0,(s,g)=>s+(g.target-g.current).clamp(0,double.infinity));
        if(left<=0){ if(activeGoals.isNotEmpty) activeGoals.first.current += t.rub; return; }
        for(final g in activeGoals){
          final l = (g.target-g.current).clamp(0,double.infinity);
          g.current += (l/left)*t.rub;
        }
      } else if(t.goalId!=null){
        final g = goals.firstWhere((x)=>x.id==t.goalId, orElse:()=>Goal(id:'',title:'',target:0,createdAt:0));
        if(g.id.isNotEmpty) g.current += t.rub;
      }
    } else {
      if(t.affectsGoal && t.goalId!=null){
        final g = goals.firstWhere((x)=>x.id==t.goalId, orElse:()=>Goal(id:'',title:'',target:0,createdAt:0));
        if(g.id.isNotEmpty) g.current = (g.current-t.rub).clamp(0,double.infinity);
      }
    }
  }
  void _revertTx(TxRecord t){
    if(t.type=='income'){
      if(t.isAuto){
        final left = activeGoals.fold(0.0,(s,g)=>s+(g.target-g.current).clamp(0,double.infinity));
        if(left<=0){ if(activeGoals.isNotEmpty) activeGoals.first.current = (activeGoals.first.current-t.rub).clamp(0,double.infinity); return; }
        for(final g in activeGoals){
          final l = (g.target-g.current).clamp(0,double.infinity);
          g.current = (g.current-(l/left)*t.rub).clamp(0,double.infinity);
        }
      } else if(t.goalId!=null){
        final g = goals.firstWhere((x)=>x.id==t.goalId, orElse:()=>Goal(id:'',title:'',target:0,createdAt:0));
        if(g.id.isNotEmpty) g.current = (g.current-t.rub).clamp(0,double.infinity);
      }
    } else {
      if(t.affectsGoal && t.goalId!=null){
        final g = goals.firstWhere((x)=>x.id==t.goalId, orElse:()=>Goal(id:'',title:'',target:0,createdAt:0));
        if(g.id.isNotEmpty) g.current += t.rub;
      }
    }
  }

  void addTx(TxRecord t){ _applyTx(t); txs.add(t); save(); notifyListeners(); }
  void updateTx(TxRecord t){
    final i = txs.indexWhere((x)=>x.id==t.id);
    if(i<0) return;
    _revertTx(txs[i]); _applyTx(t); txs[i]=t; save(); notifyListeners();
  }
  void deleteTx(String id){
    final i = txs.indexWhere((x)=>x.id==id);
    if(i<0) return;
    _revertTx(txs[i]); txs.removeAt(i); save(); notifyListeners();
  }
}
