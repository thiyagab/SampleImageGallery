import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:image_picker_web/image_picker_web.dart';

class GalleryPage extends StatefulWidget {
  String uid;

  GalleryPage(this.uid);

  @override
  _GalleryPageState createState() => _GalleryPageState(this.uid);
}

class _GalleryPageState extends State<GalleryPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  List<Uint8List>? _localimages;
  String title = 'Image Gallery';
  String description = '';
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  List _imageUrls = [];
  List<String> descriptions = [];
  double? width;
  double? height;
  String uid;

  _GalleryPageState(this.uid);

  Future getImage(StateSetter bottomState) async {
    List<Uint8List>? images = await ImagePickerWeb.getMultiImagesAsBytes();

    bottomState(() {
      _localimages = images;
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
    if (_localimages == null || _localimages!.isEmpty) return;
    setState(() {
      title = 'Uploading...';
    });
    List<String> imageurls = [];
    int count = 1;
    await Future.forEach(_localimages!.toList(), (Uint8List _image) async {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final fileRef = _storage.ref().child("$uid/$fileName");
      UploadTask uploadTask = fileRef.putData(_image!);
      await uploadTask.whenComplete(() => null);
      String imageUrl = await fileRef.getDownloadURL();
      imageurls.add(imageUrl);
      count += 1;
      setState(() {
        title = 'Uploading Image $count';
      });
    });

    _database.ref().child(uid).push().set({
      "url": imageurls.length == 1 ? imageurls[0] : imageurls,
      "description": description ?? '',
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Image(s) uploaded successfully"),
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
      body: body(),
      floatingActionButton: FloatingActionButton(
          onPressed: () {
            showAddPicDialog(context);
          },
          child: Text("+")),
    );
  }

  body() {
    return Padding(
        padding: EdgeInsets.all(30),
        child: GridView.builder(
          shrinkWrap: true,
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
                    context: context, builder: (_) => showDetails(index));
              },
              child: showNetworkImages(index),
            );
          },
          itemCount: _imageUrls.length,
        ));
  }

  showAddPicDialog(BuildContext context) {
    showModalBottomSheet(
        context: context,
        builder: (newcontext) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return SingleChildScrollView(
                child: Container(
                    padding: const EdgeInsets.all(10),
                    child: Column(children: <Widget>[
                      _localimages == null || _localimages!.isEmpty
                          ? Container()
                          : showLocalImages(),
                      SizedBox(height: 10),
                      TextField(
                        minLines: 3,
                        maxLines: 20,
                        decoration: const InputDecoration(
                          labelText: "Description",
                        ),
                        onChanged: (value) {
                          setState(() {
                            description = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        child: const Text("Choose Image"),
                        onPressed: () {
                          getImage(setState);
                        },
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        child: const Text("Upload Image"),
                        onPressed: () {
                          Navigator.pop(context);
                          _uploadImage();
                        },
                      )
                    ])));
          });
        });
  }

  Widget showLocalImages() {
    if (_localimages!.isNotEmpty && _localimages!.length == 1) {
      return Image.memory(
        _localimages![0],
        fit: BoxFit.fitHeight,
        width: 100,
      );
    } else {
      return ImageSlideshow(
          indicatorColor: Colors.blue,
          autoPlayInterval: 3000,
          isLoop: true,
          children: _localimages!.map((_image) {
            return Image.memory(
              _image!,
              fit: BoxFit.fitHeight,
              width: 100,
            );
          }).toList());
    }
  }

  showNetworkImages(int index) {
    if (_imageUrls[index].runtimeType == String) {
      return Image.network(
        _imageUrls[index],
        fit: BoxFit.fitHeight,
        width: 100,
      );
    } else {
      List newImageUrls = _imageUrls[index];
      return ImageSlideshow(
          indicatorColor: Colors.blue,
          autoPlayInterval: 3000,
          isLoop: true,
          children: newImageUrls!.map((image) {
            return Image.network(
              image!,
              fit: BoxFit.fitHeight,
              width: 100,
            );
          }).toList());
    }
  }

  showDetails(int index) {
    return Dialog(
        child: SingleChildScrollView(
            child: Column(children: [
      showNetworkImages(index),
      const SizedBox(
        height: 20,
      ),
      Text(descriptions[index]),
      const SizedBox(
        height: 10,
      )
    ])));
  }
}
