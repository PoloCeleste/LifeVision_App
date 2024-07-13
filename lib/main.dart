import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification.dart';
import 'package:webview_flutter/webview_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _collectionName;
  int _documentCount = 0;
  int _failedInspectionCount = 0;
  Set<String> _uniqueFailedDocumentIds = {};
  late String _Dialog = '';
  @override
  void initState() {
    super.initState();
    FlutterLocalNotification.init();
    // 오늘 날짜를 포함하는 콜렉션 이름 생성
    _collectionName = DateTime.now().toLocal().toString().split(' ')[0];
    // 앱이 처음 시작될 때 문서 개수 및 불합격 검사 개수 가져오기
    Future.delayed(const Duration(seconds: 1),
        FlutterLocalNotification.requestNotificationPermission());
    _getDocumentCount();
    _checkNotiField();
    // Firestore의 변경 사항 실시간 감지
    _subscribeToDocumentChanges();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('근무자 검사 현황'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.all(25),
            child: Text(
              '금일 현황판',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(
            height: 30,
            color: Colors.black,
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              _openWebView();
            },
            child: Text(
              '검사 총 인원 : $_documentCount',
              style: const TextStyle(fontSize: 18.0),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              _Dialog = '';
              _notifyFailedApplicants(_uniqueFailedDocumentIds, 1);
              FlutterDialog();
            },
            child: Text(
              '검사 불합격 : $_failedInspectionCount',
              style: const TextStyle(fontSize: 18.0),
            ),
          ),
        ],
      ),
    );
  }

  // Firestore에서 문서 개수 가져오기
  Future<void> _getDocumentCount() async {
    try {
      // 콜렉션 참조 생성
      CollectionReference collectionRef =
          _firestore.collection(_collectionName);

      // 콜렉션의 문서 스냅샷 가져오기
      QuerySnapshot querySnapshot = await collectionRef.get();

      // 문서 개수 업데이트
      setState(() {
        _documentCount = querySnapshot.size;
      });
    } catch (e) {
      print('에러 발생: $e');
    }
  }

  // Firestore에서 불합격 검사 개수 가져오기
  Future<void> _checkNotiField() async {
    try {
      // 콜렉션 참조 생성
      CollectionReference collectionRef =
          _firestore.collection(_collectionName);

      // 콜렉션의 문서 스냅샷 가져오기
      QuerySnapshot failedDocuments =
          await collectionRef.where('Shoes', isEqualTo: false).get();
      QuerySnapshot failedDocuments2 =
          await collectionRef.where('Belt', isEqualTo: false).get();
      QuerySnapshot failedDocuments3 =
          await collectionRef.where('Helmet', isEqualTo: false).get();

      // 중복을 방지하기 위해 Set 사용
      Set<String> uniqueFailedDocumentIds = {};

      // 중복된 문서를 제거하면서 Set에 추가
      uniqueFailedDocumentIds.addAll(failedDocuments.docs.map((doc) => doc.id));
      uniqueFailedDocumentIds
          .addAll(failedDocuments2.docs.map((doc) => doc.id));
      uniqueFailedDocumentIds
          .addAll(failedDocuments3.docs.map((doc) => doc.id));

      // 결과의 길이가 불합격 문서 개수
      setState(() {
        _failedInspectionCount = uniqueFailedDocumentIds.length;
        _uniqueFailedDocumentIds = uniqueFailedDocumentIds;
      });
      print('불합격 인원 수: $_failedInspectionCount');
      _notifyFailedApplicants(uniqueFailedDocumentIds, 0);
    } catch (e) {
      print('에러 발생: $e');
    }
  }

  // Firestore의 변경 사항 실시간 감지
  void _subscribeToDocumentChanges() {
    _firestore.collection(_collectionName).snapshots().listen((event) {
      // 문서가 추가 또는 삭제될 때마다 호출됨
      int documentCount = event.size;
      print('검사 인원이 변경되었습니다: $documentCount');

      // 문서 개수 업데이트
      setState(() {
        _documentCount = documentCount;
      });
      // 불합격 검사 개수 업데이트
      _checkNotiField();
    });
  }

  void _notifyFailedApplicants(Set documents, mod) async {
    if (mod == 0) {
      int i = 0;
      for (var document in documents) {
        print('Check ${document}');
        try {
          DocumentSnapshot documentSnapshot =
              await _firestore.collection(_collectionName).doc(document).get();

          Map<String, dynamic> data =
              documentSnapshot.data() as Map<String, dynamic>;
          if (documentSnapshot.exists && data.containsKey('Noti')) {
            print('불합격자: ${document}');
            if (data['Noti'] == false) {
              FlutterLocalNotification.showNotification(
                  i, '검사 불합격', '${document} 불합격');
              await _firestore
                  .collection(_collectionName)
                  .doc(document)
                  .update({'Noti': true});
              print('${document} Noti 업데이트 성공');
              i++;
            }
          } else {
            print('Noti 필드가 존재하지 않습니다.');
          }
        } catch (e) {
          print('Noti 필드 업데이트 중 에러 발생: $e');
        }
      }
    } else if (mod == 1) {
      int i = 0;
      for (var document in documents) {
        FlutterLocalNotification.showNotification(
            i, '검사 불합격', '${document} 불합격');
        _Dialog = '$_Dialog \n $document';
        i++;
      }
    }
  }

  void FlutterDialog() {
    showDialog(
        context: context,
        //barrierDismissible - Dialog를 제외한 다른 화면 터치 x
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            // RoundedRectangleBorder - Dialog 화면 모서리 둥글게 조절
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0)),
            //Dialog Main Title
            title: Column(
              children: <Widget>[
                new Text("검사 불합격자"),
              ],
            ),
            //
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$_Dialog',
                ),
              ],
            ),
            actions: <Widget>[
              new ElevatedButton(
                child: new Text("확인"),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          );
        });
  }

  void _openWebView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WebViewPage(),
      ),
    );
  }
}

class WebViewPage extends StatelessWidget {
  const WebViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('검사 세부 내역'),
      ),
      body: const WebView(
        initialUrl: 'https://poloceleste.netlify.app',
        javascriptMode: JavascriptMode.unrestricted,
      ),
    );
  }
}
