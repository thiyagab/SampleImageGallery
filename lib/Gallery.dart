import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
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
  List<Uint8List>? _images;
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
      _images = images;
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
    if (_images == null || _images!.isEmpty) return;
    setState(() {
      title = 'Uploading...';
    });
    List<String> imageurls = [];
    int count = 1;
    await Future.forEach(_images!.toList(), (Uint8List _image) async {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final fileRef = _storage.ref().child("$uid/$fileName");
      UploadTask uploadTask = fileRef.putData(_image!);
      await uploadTask.whenComplete(() => null);

      // uploadTask.whenComplete(() => null)b
      String imageUrl = await fileRef.getDownloadURL();
      imageurls.add(imageUrl);
      count += 1;
      setState(() {
        title = 'Uploading...$count';
      });
    });

    _database.ref().child(uid).push().set({
      "url": imageurls.length == 1 ? imageurls[0] : imageurls,
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
                          context: context, builder: (_) => showDetails(index));
                    },
                    child: showNetworkImages(index),
                  );
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

  showNetworkImages(int index) {
    if (_imageUrls[index].runtimeType == String) {
      return Image.network(
        _imageUrls[index],
        fit: BoxFit.fitHeight,
        width: 100,
      );
    } else if (_imageUrls[index].runtimeType == List) {
      List newImageUrls = _imageUrls[index];
      return ImageSlideshow(

          /// Width of the [ImageSlideshow].
          width: double.infinity,

          /// Height of the [ImageSlideshow].
          height: 200,

          /// The page to show when first creating the [ImageSlideshow].
          initialPage: 0,

          /// The color to paint the indicator.
          indicatorColor: Colors.blue,

          /// The color to paint behind th indicator.
          indicatorBackgroundColor: Colors.grey,

          /// Called whenever the page in the center of the viewport changes.
          onPageChanged: (value) {
            print('Page changed: $value');
          },

          /// Auto scroll interval.
          /// Do not auto scroll with null or 0.
          autoPlayInterval: 3000,

          /// Loops back to first slide.
          isLoop: true,

          /// The widgets to display in the [ImageSlideshow].
          /// Add the sample image file into the images folder
          children: newImageUrls!.map((_image) {
            return Image.network(
              _image!,
              fit: BoxFit.fitHeight,
              width: 100,
            );
          }).toList());
    }
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
                      _images == null || _images!.isEmpty
                          ? Container()
                          : showImages(),
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

  Widget showImages() {
    if (_images!.isNotEmpty && _images!.length == 1) {
      return Image.memory(
        _images![0],
        fit: BoxFit.fitHeight,
        width: 100,
      );
    } else {
      return ImageSlideshow(

          /// Width of the [ImageSlideshow].
          width: double.infinity,

          /// Height of the [ImageSlideshow].
          height: 200,

          /// The page to show when first creating the [ImageSlideshow].
          initialPage: 0,

          /// The color to paint the indicator.
          indicatorColor: Colors.blue,

          /// The color to paint behind th indicator.
          indicatorBackgroundColor: Colors.grey,

          /// Called whenever the page in the center of the viewport changes.
          onPageChanged: (value) {
            print('Page changed: $value');
          },

          /// Auto scroll interval.
          /// Do not auto scroll with null or 0.
          autoPlayInterval: 3000,

          /// Loops back to first slide.
          isLoop: true,

          /// The widgets to display in the [ImageSlideshow].
          /// Add the sample image file into the images folder
          children: imageSlides());
    }
  }

  List<Widget> imageSlides() {
    return _images!.map((_image) {
      return Image.memory(
        _image!,
        fit: BoxFit.fitHeight,
        width: 100,
      );
    }).toList();
  }

  showDetails(int index) {
    return Dialog(
        child: SingleChildScrollView(
            child: Column(children: [
      showNetworkImages(index),
      SizedBox(
        height: 20,
      ),
      Text(descriptions[index]),
      SizedBox(
        height: 10,
      )
    ])));
  }
}
