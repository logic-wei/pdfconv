import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';

import 'src/pdfconv_controller.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'pdf转换器',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'pdf转换器'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<String> files = [];
  List<String> filesNote = [];
  String? outPath;

  String baseUrl = "https://ark.cn-beijing.volces.com/api/v3";
  String apiKey = "902eca5f-38fd-487f-9cc2-0def5b8e7790";
  String model = "doubao-1-5-thinking-vision-pro-250428";
  String prompt = "将图片转换为文本格式的表格数据，行数据用换行符分隔，列数据用|分隔";

  PdfConvController? pdfConv;

  @override
  Widget build(BuildContext context) {
    if (pdfConv == null && isLLMSet()) {
      pdfConv = PdfConvController(
        baseUrl: baseUrl,
        apiKey: apiKey,
        model: model,
        prompt: prompt,
      );
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: () async {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  List<TextEditingController> txtCtrls = [];
                  for (var i = 0; i < 4; i += 1) {
                    txtCtrls.add(TextEditingController());
                  }
                  txtCtrls[0].text = baseUrl;
                  txtCtrls[1].text = apiKey;
                  txtCtrls[2].text = model;
                  txtCtrls[3].text = prompt;

                  return AlertDialog(
                    title: Text("自定义大模型"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          decoration: InputDecoration(
                            labelText: "base url",
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => baseUrl = value,
                          controller: txtCtrls[0],
                        ),
                        SizedBox(height: 15),
                        TextField(
                          decoration: InputDecoration(
                            labelText: "api key",
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => apiKey = value,
                          controller: txtCtrls[1],
                        ),
                        SizedBox(height: 15),
                        TextField(
                          decoration: InputDecoration(
                            labelText: "model",
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => model = value,
                          controller: txtCtrls[2],
                        ),
                        SizedBox(height: 15),
                        TextField(
                          decoration: InputDecoration(
                            labelText: "prompt",
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => prompt = value,
                          controller: txtCtrls[3],
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text("取消"),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            baseUrl = txtCtrls[0].text;
                            apiKey = txtCtrls[1].text;
                            model = txtCtrls[2].text;
                            prompt = txtCtrls[3].text;
                          });
                          Navigator.of(context).pop();
                        },
                        child: Text("确定"),
                      ),
                    ],
                  );
                },
              );
            },
            icon: Icon(Icons.settings),
          ),
        ],
      ),
      body: Center(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: files.length,
                itemBuilder: (BuildContext ctx, int idx) {
                  return ListTile(
                    title: Text(files[idx]),
                    subtitle: Text(filesNote[idx]),
                    trailing: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          files.removeAt(idx);
                          filesNote.removeAt(idx);
                        });
                      },
                      child: Text("删除"),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            tooltip: "添加",
            child: Icon(Icons.add),
            onPressed: () async {
              var result = await FilePicker.platform.pickFiles(
                dialogTitle: "选择一个或多个文件",
                type: FileType.custom,
                allowedExtensions: ["pdf"],
                allowMultiple: true,
              );
              if (result == null) {
                return;
              }
              setState(() {
                for (var i in result.files) {
                  if (i.path == null) {
                    continue;
                  }
                  files.add(i.path!);
                  filesNote.add("新添加");
                }
              });
            },
          ),
          SizedBox(width: 16),
          FloatingActionButton(
            tooltip: "保存",
            child: Icon(Icons.save),
            onPressed: () async {
              var result = await FilePicker.platform.getDirectoryPath(
                dialogTitle: "选择输出文件夹",
              );
              if (result == null) {
                return;
              }
              setState(() {
                outPath = result;
              });
            },
          ),
          SizedBox(width: 16),
          FloatingActionButton(
            tooltip: "打开",
            child: Icon(Icons.folder_open),
            onPressed: () async {
              if (outPath == null) {
                return;
              }
              await OpenFilex.open(outPath!);
            },
          ),
          SizedBox(width: 16),
          FloatingActionButton(
            tooltip: "开始",
            child: Icon(Icons.play_arrow_rounded),
            onPressed: () async {
              if (!isLLMSet()) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("请设置大模型参数"),
                    action: SnackBarAction(label: "close", onPressed: () {}),
                  ),
                );
                return;
              }

              if (outPath == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("请选择输出文件夹"),
                    action: SnackBarAction(label: "close", onPressed: () {}),
                  ),
                );
                return;
              }
              int i = 0;
              for (final file in files) {
                await pdfConv?.convPdfByAiAndSave(file, outPath!, (String note) {
                  setState(() {
                    filesNote[i] = note;
                  });
                });
                i += 1;
              }
            },
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  bool isLLMSet() {
    if (baseUrl.compareTo("") == 0) {
      return false;
    }
    if (apiKey.compareTo("") == 0) {
      return false;
    }
    if (model.compareTo("") == 0) {
      return false;
    }
    if (prompt.compareTo("") == 0) {
      return false;
    }
    return true;
  }
}
