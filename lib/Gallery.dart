import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:html' as html;
import 'dart:io' as io;
import 'package:image_picker_web/image_picker_web.dart';

class GalleryPage extends StatefulWidget {
  String uid;

  GalleryPage(this.uid);

  @override
  _GalleryPageState createState() => _GalleryPageState(this.uid);
}

class _GalleryPageState extends State<GalleryPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  Uint8List? _image;
  String title = 'Image Gallery';
  String description = '';
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  List<String> _imageUrls = [];
  List<String> descriptions = [];
  double? width;
  double? height;
  String uid;

  _GalleryPageState(this.uid);

  Future getImage(StateSetter bottomState) async {
    var image = await ImagePickerWeb.getImageAsBytes();

    bottomState(() {
      _image = image;
    });
  }

  @override
  void initState() {
    super.initState();

    _database.ref().child(uid).onValue.listen((event) {
      setState(() {
        _imageUrls = [];
        if (event.snapshot.value != null ||
            event.snapshot.value.runtimeType == Map) {
          Map<dynamic, dynamic> images = event.snapshot.value as Map;
          images.forEach((key, value) {
            _imageUrls.add(value["url"]);
            descriptions.add(value["description"]);
          });
        }
      });
    });
  }

  void _uploadImage() async {
    if (_image == null) return;
    setState(() {
      title = 'Uploading...';
    });
    String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final fileRef = _storage.ref().child("$uid/$fileName");
    UploadTask uploadTask = fileRef.putData(_image!);
    await uploadTask.whenComplete(() => null);

    // uploadTask.whenComplete(() => null)
    String imageUrl = await fileRef.getDownloadURL();

    _database.ref().child(uid).push().set({
      "url": imageUrl,
      "description": description == null ? '' : description,
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("Image uploaded successfully"),
    ));
    setState(() {
      title = 'Image Gallery';
    });
  }

  @override
  Widget build(BuildContext context) {
    width = MediaQuery.of(context).size.width;
    height = MediaQuery.of(context).size.height;
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(title),
      ),
      body: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          children: <Widget>[
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: (width! > height! && width! > 600) ? 6 : 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  return InkWell(
                      onTap: () {
                        showDialog(
                            context: context,
                            builder: (_) => showDetails(
                                _imageUrls[index], descriptions[index]));
                      },
                      child: Image.network(
                        _imageUrls[index],
                        fit: BoxFit.fitHeight,
                        width: 100,
                      ));
                },
                itemCount: _imageUrls.length,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () {
            showAddPicDialog(context);
          },
          child: Text("+")),
    );
  }

  showAddPicDialog(BuildContext context) {
    showModalBottomSheet(
        context: context,
        builder: (newcontext) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return SingleChildScrollView(
                child: Container(
                    padding: EdgeInsets.all(10),
                    child: Column(children: <Widget>[
                      _image == null
                          ? Container()
                          : Image.memory(
                              _image!,
                              fit: BoxFit.fitHeight,
                              width: 100,
                            ),
                      SizedBox(height: 10),
                      TextField(
                        minLines: 3,
                        maxLines: 20,
                        decoration: InputDecoration(
                          labelText: "Description",
                        ),
                        onChanged: (value) {
                          setState(() {
                            description = value;
                          });
                        },
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        child: Text("Choose Image"),
                        onPressed: () {
                          getImage(setState);
                        },
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        child: Text("Upload Image"),
                        onPressed: () {
                          Navigator.pop(context);
                          _uploadImage();
                        },
                      )
                    ])));
          });
        });
  }

  showDetails(String imageUrl, String description) {
    return Dialog(
        child: Column(children: [
      Image.network(
        imageUrl,
        fit: BoxFit.fitHeight,
        width: 300,
      ),
      SizedBox(
        height: 20,
      ),
      Text(description)
    ]));
  }
}
