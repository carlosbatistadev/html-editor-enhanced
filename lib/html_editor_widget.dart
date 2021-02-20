import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:html_editor_enhanced/utils/pick_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

bool callbacksInitialized = false;

class HtmlEditorWidget extends StatelessWidget {
  HtmlEditorWidget({
    Key key,
    this.value,
    this.height,
    this.useBottomSheet,
    this.imageWidth,
    this.showBottomToolbar,
    this.hint,
    this.callbacks,
  }) : super(key: key);

  final String value;
  final double height;
  final bool useBottomSheet;
  final double imageWidth;
  final bool showBottomToolbar;
  final String hint;
  final UniqueKey webViewKey = UniqueKey();
  final Callbacks callbacks;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: InAppWebView(
            initialFile: 'packages/html_editor_enhanced/assets/summernote.html',
            onWebViewCreated: (webViewController) {
              controller = webViewController;
            },
            initialOptions: InAppWebViewGroupOptions(
              crossPlatform: InAppWebViewOptions(
                javaScriptEnabled: true,
                debuggingEnabled: true,
              ),
              //todo flutter_inappwebview 5.0.0
              /*android: AndroidInAppWebViewOptions(
                    useHybridComposition: true,
                  )*/
            ),
            gestureRecognizers: {
              Factory<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer())
            },
            onConsoleMessage: (controller, consoleMessage) {
              String message = consoleMessage.message;
              //todo determine whether this processing is necessary
              if (message.isEmpty ||
                  message == "<p></p>" ||
                  message == "<p><br></p>" ||
                  message == "<p><br/></p>") {
                message = "";
              }
              text = message;
            },
            onLoadStop: (InAppWebViewController controller, String url) async {
              //set the hint once the editor is loaded
              if (hint != null) {
                HtmlEditor.setHint(hint);
              } else {
                HtmlEditor.setHint("");
              }

              HtmlEditor.setFullScreen();
              //set the text once the editor is loaded
              if (value != null) {
                HtmlEditor.setText(value);
              }
              //initialize callbacks
              if (callbacks != null && !callbacksInitialized) {
                addJSCallbacks();
                addJSHandlers();
                callbacksInitialized = true;
              }
            },
          ),
        ),
        showBottomToolbar ? Divider() : Container(height: 0, width: 0),
        showBottomToolbar ? Padding(
          padding: const EdgeInsets.only(
              left: 4.0, right: 4, bottom: 8, top: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              toolbarIcon(
                  Icons.image,
                  "Image",
                  onTap: () async {
                    PickedFile file;
                    if (useBottomSheet) {
                      file = await bottomSheetPickImage(context);

                    } else {
                      file = await dialogPickImage(context);
                    }
                    if (file != null) {
                      String filename = p.basename(file.path);
                      List<int> imageBytes = await file.readAsBytes();
                      String base64Image =
                          "<img width=\"$imageWidth%\" src=\"data:image/png;base64, "
                          "${base64Encode(imageBytes)}\" data-filename=\"$filename\">";

                      String txt =
                          "\$('.note-editable').append( '" + base64Image + "');";
                      controller.evaluateJavascript(source: txt);
                    }
                  }
              ),
              toolbarIcon(
                  Icons.content_copy,
                  "Copy",
                  onTap: () async {
                    String data = await HtmlEditor.getText();
                    Clipboard.setData(new ClipboardData(text: data));
                  }
              ),
              toolbarIcon(
                  Icons.content_paste,
                  "Paste",
                  onTap: () async {
                    ClipboardData data =
                    await Clipboard.getData(Clipboard.kTextPlain);
                    String txtIsi = data.text
                        .replaceAll("'", '\\"')
                        .replaceAll('"', '\\"')
                        .replaceAll("[", "\\[")
                        .replaceAll("]", "\\]")
                        .replaceAll("\n", "<br/>")
                        .replaceAll("\n\n", "<br/>")
                        .replaceAll("\r", " ")
                        .replaceAll('\r\n', " ");
                    String txt =
                        "\$('.note-editable').append( '" + txtIsi + "');";
                    controller.evaluateJavascript(source: txt);
                  }
              ),
            ],
          ),
        ) : Container(height: 0, width: 0),
      ],
    );
  }

  void addJSCallbacks() {
    if (callbacks.onChange != null) {
      controller.evaluateJavascript(
        source: """
          \$('#summernote').on('summernote.change', function(_, contents, \$editable) {
            window.flutter_inappwebview.callHandler('onChange', contents);
          });
        """
      );
    }
    if (callbacks.onEnter != null) {
      controller.evaluateJavascript(
          source: """
          \$('#summernote').on('summernote.enter', function() {
            window.flutter_inappwebview.callHandler('onEnter', 'fired');
          });
        """
      );
    }
  }

  void addJSHandlers() {
    if (callbacks.onChange != null) {
      controller.addJavaScriptHandler(handlerName: 'onChange', callback: (contents) {
        callbacks.onChange.call(contents.first.toString());
      });
    }
    if (callbacks.onEnter != null) {
      controller.addJavaScriptHandler(handlerName: 'onEnter', callback: (_) {
        callbacks.onEnter.call();
      });
    }
  }
}