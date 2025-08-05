import 'dart:io';
import 'dart:convert';

import 'package:openai_dart/openai_dart.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as pathlib;

class PdfConvController {
  String baseUrl;
  String apiKey;
  String model;
  String prompt;

  late OpenAIClient aiClient;

  PdfConvController({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.prompt,
  }) {
    aiClient = OpenAIClient(baseUrl: baseUrl, apiKey: apiKey);
  }

  Future<String?> convB64ImageByAi(String imageBase64) async {
    CreateChatCompletionResponse res;
    try {
      res = await aiClient.createChatCompletion(
        request: CreateChatCompletionRequest(
          model: ChatCompletionModel.modelId(model),
          messages: [
            ChatCompletionMessage.system(
              content: 'You are a helpful OCR machine.',
            ),
            ChatCompletionMessage.user(
              content: ChatCompletionUserMessageContent.parts([
                ChatCompletionMessageContentPart.text(text: prompt),
                ChatCompletionMessageContentPart.image(
                  /*
                  imageUrl: ChatCompletionMessageImageUrl(
                    url: imageBase64,
                    detail: ChatCompletionMessageImageDetail.high,
                  ),
                  */
                  imageUrl: ChatCompletionMessageImageUrl.fromJson({
                    "url": "data:image/png;base64,$imageBase64",
                    "detail": "high",
                  }),
                ),
              ]),
            ),
          ],
        ),
      );
      return res.choices.first.message.content;
    } catch (e) {
      //print("Exp: $e");
    }

    return null;
  }

  Future<String?> convImageByAi(List<int> imageBytes) async {
    return await convB64ImageByAi(base64.encode(imageBytes));
  }

  Future<void> convPdfByAi(
    String path,
    Function(String) onOutput,
    Function(String)? onNote,
  ) async {
    onNote?.call("初始化pdfrx");
    await pdfrxInitialize();

    onNote?.call("打开文件中");
    final doc = await PdfDocument.openFile(path);
    int i = 0;
    int total = doc.pages.length;

    for (final page in doc.pages) {
      i += 1;
      onNote?.call("第$i/$total页: 渲染中");
      final pageImage = await page.render(
        fullWidth: page.width * 2,
        fullHeight: page.height * 2,
      );

      onNote?.call("第$i/$total页: 生成图片中");
      final image = pageImage!.createImageNF();
      final imagePng = img.encodePng(image);

      onNote?.call("第$i/$total页: AI处理中");
      final curResult = await convImageByAi(imagePng);
      if (curResult != null) {
        onOutput("$curResult\n");
      } else {
        onNote?.call("第$i/$total页: 处理失败");
      }
      pageImage.dispose();
    }
    doc.dispose();
    onNote?.call("处理完成:)");
  }

  Future<void> convPdfByAiAndSave(
    String path,
    String outPath,
    Function(String)? onNote,
  ) async {
    String outFileName = pathlib.basenameWithoutExtension(path);
    String outFilePath = pathlib.join(outPath, "$outFileName.txt");
    File outFile = File(outFilePath);

    await convPdfByAi(path, (String content) {
      outFile.writeAsString(content, mode: FileMode.append);
    }, onNote);
  }
}
