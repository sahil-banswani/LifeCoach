import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:html/parser.dart' as htmlParser;

class Content extends StatefulWidget {
  final int id;

  const Content({Key? key, required this.id}) : super(key: key);

  @override
  State<Content> createState() => _ContentState();
}

class _ContentState extends State<Content> {
  List<Map<String, String>> responseData = [];
  List<List<Map<String, String>>> secondResponseData = [];
  int selectedIndex = 0;
  List<bool> isContentVisible = [];
  bool isSpeaking = false;
  final _flutterTts = FlutterTts();

  void initializeTts() {
    _flutterTts.setStartHandler(() {
      setState(() {
        isSpeaking = true;
      });
    });
    _flutterTts.setCompletionHandler(() {
      setState(() {
        isSpeaking = false;
      });
    });
    _flutterTts.setErrorHandler((message) {
      setState(() {
        isSpeaking = false;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  void speak(String text) async {
    final strippedText = _stripHtmlTags(text);
    await _flutterTts.speak(strippedText);
  }

  String _stripHtmlTags(String htmlText) {
    final regex = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    final parsedText = htmlParser.parse(htmlText);
    final strippedText = parsedText.body!.text.trim();
    final normalizedText = strippedText.replaceAll(regex, '');
    return normalizedText;
  }

  void stop() async {
    await _flutterTts.stop();
    setState(() {
      isSpeaking = false;
    });
  }

  @override
  void dispose() {
    super.dispose();
    _flutterTts.stop();
  }

  Future<void> fetchData() async {
    try {
      final firstUri = Uri.parse(
          'https://jobportal.techallylabs.com/api/v1/life-coach/top-nav/${widget.id}');
      final firstResponse = await http.get(firstUri);

      if (firstResponse.statusCode == 200) {
        final decodedData = jsonDecode(firstResponse.body) as List<dynamic>;
        final dataList = decodedData.map((data) {
          final name = data['name'].toString();
          final id = data['id'].toString();
          return {'name': name, 'id': id};
        }).toList();
        setState(() {
          responseData = dataList;
          isContentVisible =
              List.generate(responseData.length, (_) => false);
        });
      }

      final secondResponseList = await Future.wait(responseData.map((data) {
        final secondUri = Uri.parse(
            'https://jobportal.techallylabs.com/api/v1/life-coach/types/${data['id']}');
        return http.get(secondUri).then((secondResponse) {
          if (secondResponse.statusCode == 200) {
            final decodedData =
            jsonDecode(secondResponse.body) as List<dynamic>;
            final dataList = decodedData.map((data) {
              final name = data['name'].toString();
              final content = data['content'].toString();
              return {'name': name, 'content': content};
            }).toList();
            return dataList;
          }
          return [];
        });
      }));

      setState(() {
        secondResponseData =
            secondResponseList.cast<List<Map<String, String>>>();
      });
    } catch (err) {
      print(err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        centerTitle: true,
        backgroundColor: const Color(0xFF08154A),
      ),
      body: DefaultTabController(
        length: responseData.length,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabs: responseData
                  .map(
                    (data) => Tab(
                  child: Container(
                    alignment: Alignment.center,
                    constraints: const BoxConstraints.expand(
                      width: 150,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6ECF9),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Text(
                      data['name'] ?? " ",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF08154A),
                      ),
                    ),
                  ),
                ),
              )
                  .toList(),
              onTap: (index) {
                setState(() {
                  selectedIndex = index;
                });
              },
            ),
            Expanded(
              child: Container(
                color: Colors.white,
                child: TabBarView(
                  children: secondResponseData.isNotEmpty
                      ? List.generate(secondResponseData.length, (i) {
                    final secondResponse = secondResponseData[i];
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          for (final response in secondResponse)
                            Column(
                              children: [
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        speak(response['name'] ?? '');
                                      },
                                      child: Text(
                                        '${response['name'] ?? ''} :',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          color: Color(0xFF08154A),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          isContentVisible[i] =
                                          !isContentVisible[i];
                                        });
                                      },
                                      child: Icon(
                                        isContentVisible[i]
                                            ? Icons.arrow_drop_down
                                            : Icons.arrow_drop_up,
                                        color: const Color(0xFF08154A),
                                      ),
                                    ),
                                  ],
                                ),
                                if (isContentVisible[i])
                                  const SizedBox(height: 10),
                                AnimatedCrossFade(
                                  duration: const Duration(
                                      milliseconds: 300),
                                  crossFadeState:
                                  isContentVisible[i]
                                      ? CrossFadeState.showFirst
                                      : CrossFadeState.showSecond,
                                  firstChild: GestureDetector(
                                    onTap: () {
                                      speak(response['content'] ??
                                          '');
                                    },
                                    child: HtmlWidget(
                                      '<div style="text-align: center;color:#08154A;font-size: 18px">${response['content'] ?? ''}</div>',
                                      webView: true,
                                    ),
                                  ),
                                  secondChild: Container(),
                                ),
                              ],
                            ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    );
                  })
                      : [
                    const Center(
                      child: Text('No data available',style: TextStyle(color: Color(0xFF08154A),fontWeight: FontWeight.bold),),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
