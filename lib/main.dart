import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'かんたんな家計簿',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const KakeiboHomePage(),
    );
  }
}

class KakeiboHomePage extends StatefulWidget {
  const KakeiboHomePage({super.key});
  @override
  State<KakeiboHomePage> createState() => _KakeiboHomePageState();
}

class _KakeiboHomePageState extends State<KakeiboHomePage> {
  List<String> _tabs = ['全財産', '臨時', '趣味'];
  Map<String, int> _balances = {};
  List<Map<String, dynamic>> _history = [];
  String _currentTab = '全財産';
  
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tabs = prefs.getStringList('tabs') ?? ['全財産', '臨時', '趣味'];
      if (!_tabs.contains(_currentTab)) _currentTab = _tabs[0];
      for (var tab in _tabs) {
        _balances[tab] = prefs.getInt('bal_$tab') ?? 0;
      }
      String? historyJson = prefs.getString('history_data');
      if (historyJson != null) {
        _history = List<Map<String, dynamic>>.from(json.decode(historyJson));
      }
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('tabs', _tabs);
    for (var tab in _tabs) {
      await prefs.setInt('bal_$tab', _balances[tab] ?? 0);
    }
    await prefs.setString('history_data', json.encode(_history));
  }

  void _applyToBalance(bool isPositive) {
    int amount = int.tryParse(_amountController.text) ?? 0;
    String memo = _memoController.text.trim().isEmpty ? 'メモなし' : _memoController.text;
    if (amount == 0) return;

    setState(() {
      _balances[_currentTab] = (_balances[_currentTab] ?? 0) + (isPositive ? amount : -amount);
      _history.insert(0, {
        'title': _currentTab,
        'amount': isPositive ? amount : -amount,
        'memo': memo,
        'date': DateTime.now().toString().substring(5, 16),
      });
      _amountController.clear();
      _memoController.clear();
      FocusScope.of(context).unfocus(); 
    });
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('かんたんな家計簿'), backgroundColor: Colors.blue.shade100),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text('メニュー', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.calculate),
              title: const Text('簡易的な電卓'),
              onTap: () { Navigator.pop(context); _showCalcDialog(); },
            ),
            ListTile(
              leading: const Icon(Icons.tab_unselected),
              title: const Text('タブ名の変更'),
              onTap: () { Navigator.pop(context); _showTabEditDialog(); },
            ),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.red),
              title: const Text('カテゴリーを初期化', style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(context); _resetTabs(); },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _tabs.map((tab) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                child: ChoiceChip(
                  label: Text(tab),
                  selected: _currentTab == tab,
                  onSelected: (s) => setState(() => _currentTab = tab),
                ),
              )).toList(),
            ),
          ),
          Card(
            margin: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: ListTile(
              title: Text('$_currentTab の残高'),
              trailing: Text('¥${_balances[_currentTab] ?? 0}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '金額を入力', prefixText: '¥ ', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _memoController,
                  decoration: const InputDecoration(labelText: 'メモ（内容）', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: ElevatedButton(onPressed: () => _applyToBalance(false), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50), child: const Text('支出'))),
                    const SizedBox(width: 8),
                    Expanded(child: ElevatedButton(onPressed: () => _applyToBalance(true), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade50), child: const Text('収入'))),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('最近の履歴', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final item = _history[index];
                return ListTile(
                  dense: true,
                  leading: Icon(item['amount'] > 0 ? Icons.add_circle : Icons.remove_circle, color: item['amount'] > 0 ? Colors.green : Colors.red),
                  title: Text('${item['memo']}'),
                  subtitle: Text('${item['date']} (${item['title']})'),
                  trailing: Text('¥${item['amount']}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- 📱 電卓の四則演算を含む完全実装 ---

  void _showCalcDialog() {
    String display = "0";
    double? firstVal;
    String? op;
    bool shouldReset = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            void press(String k) {
              setDlgState(() {
                if (k == 'C') {
                  display = "0"; firstVal = null; op = null;
                } else if (k == '+' || k == '-' || k == '×' || k == '÷') {
                  firstVal = double.tryParse(display);
                  op = k; shouldReset = true;
                } else if (k == '=') {
                  if (firstVal != null && op != null) {
                    double s = double.parse(display);
                    double res = 0;
                    if (op == '+') res = firstVal! + s;
                    if (op == '-') res = firstVal! - s;
                    if (op == '×') res = firstVal! * s;
                    if (op == '÷') res = s != 0 ? firstVal! / s : 0;
                    display = res.toString().endsWith('.0') ? res.toInt().toString() : res.toStringAsFixed(1);
                    firstVal = null; op = null;
                  }
                } else {
                  if (display == "0" || shouldReset) { display = k; shouldReset = false; }
                  else { display += k; }
                }
              });
            }

            return AlertDialog(
              title: const Text('簡易電卓'),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity, alignment: Alignment.centerRight,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                      child: Text(display, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 15),
                    // 4列の電卓ボタン
                    GridView.count(
                      shrinkWrap: true, crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8,
                      children: [
                        '7','8','9','÷','4','5','6','×','1','2','3','-','0','C','=','+'
                      ].map((k) => ElevatedButton(
                        style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, backgroundColor: (int.tryParse(k) == null && k != 'C') ? Colors.orange.shade100 : null),
                        onPressed: () => press(k),
                        child: Text(k, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      )).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
                ElevatedButton(onPressed: () { _amountController.text = display; Navigator.pop(context); }, child: const Text('金額に反映')),
              ],
            );
          },
        );
      },
    );
  }

  void _showTabEditDialog() {
    List<TextEditingController> controllers = _tabs.map((t) => TextEditingController(text: t)).toList();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('タブ名の変更'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(controllers.length, (i) => TextField(controller: controllers[i], decoration: InputDecoration(labelText: 'カテゴリー ${i + 1}'))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          ElevatedButton(onPressed: () {
            setState(() {
              for (int i = 0; i < _tabs.length; i++) {
                _tabs[i] = controllers[i].text.trim().isEmpty ? _tabs[i] : controllers[i].text;
              }
              _currentTab = _tabs[0];
            });
            _saveData();
            Navigator.pop(context);
          }, child: const Text('保存')),
        ],
      ),
    );
  }

  void _resetTabs() {
    setState(() {
      _tabs = ['全財産', '臨時', '趣味'];
      _currentTab = _tabs[0];
      _balances = {'全財産': 0, '臨時': 0, '趣味': 0};
      _history.clear();
    });
    _saveData();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('初期化しました')));
  }
}