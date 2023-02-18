import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:image_picker_web/image_picker_web.dart';
import 'package:image/image.dart' as Img;
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

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
  List thumbnails = [];
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
            thumbnails.add(value['thumbnail'] ?? value["url"]);
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
    List<String> thumbnails = [];
    int count = 1;
    await Future.forEach(_localimages!.toList(), (Uint8List _image) async {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final fileRef = _storage.ref().child("$uid/$fileName");
      UploadTask uploadTask = fileRef.putData(_image!);
      await uploadTask.whenComplete(() => null);
      String imageUrl = await fileRef.getDownloadURL();
      imageurls.add(imageUrl);
      //Resize and upload thumbnail, we can use firebase resize funciton if can enable billing
      // switch to blaze plan
      Uint8List thumbnail =
          Img.encodeJpg(Img.copyResize(Img.decodeImage(_image)!, width: 100));
      final resizedfileRef = _storage.ref().child("$uid/$fileName" + "_tb");
      UploadTask resizeuploadTask = resizedfileRef.putData(thumbnail!);
      await resizeuploadTask.whenComplete(() => null);
      String thumbnailurl = await resizedfileRef.getDownloadURL();
      thumbnails.add(thumbnailurl);
      count += 1;
      setState(() {
        title = 'Uploading Image $count';
      });
    });

    _database.ref().child(uid).push().set({
      "url": imageurls.length == 1 ? imageurls[0] : imageurls,
      "thumbnail": thumbnails.length == 1 ? thumbnails[0] : thumbnails,
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
              child: showThumbNails(index),
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
        width: 300,
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
              width: 300,
            );
          }).toList());
    }
  }

  showPhotoView(int index) {
    if (_imageUrls[index].runtimeType == String) {
      return PhotoView(
        backgroundDecoration: const BoxDecoration(color: Colors.white70),
        imageProvider: NetworkImage(_imageUrls[index]),
      );
    } else {
      List newImageUrls = _imageUrls[index];
      return PhotoViewGallery.builder(
          scrollPhysics: const BouncingScrollPhysics(),
          itemCount: newImageUrls.length,
          backgroundDecoration: const BoxDecoration(color: Colors.white70),
          enableRotation: true,
          gaplessPlayback: true,
          allowImplicitScrolling: true,
          builder: (BuildContext context, int index) {
            return PhotoViewGalleryPageOptions(
                initialScale: PhotoViewComputedScale.contained * 0.5,
                maxScale: PhotoViewComputedScale.covered * 1.1,
                imageProvider: NetworkImage(newImageUrls[index]));
          });
    }
  }

  showThumbNails(int index) {
    if (_imageUrls[index].runtimeType == String) {
      return Image.network(
        thumbnails[index],
        fit: BoxFit.fitHeight,
        width: 100,
        errorBuilder: errorWidget,
      );
    } else {
      List newImageUrls = thumbnails[index];
      return ImageSlideshow(
          indicatorColor: Colors.blue,
          autoPlayInterval: 3000,
          isLoop: true,
          children: newImageUrls!.map((image) {
            return Image.network(
              image,
              fit: BoxFit.fitHeight,
              width: 100,
              errorBuilder: errorWidget,
            );
          }).toList());
    }
  }

  Widget errorWidget(context, error, stackTrace) {
    return Text("no file");
  }

  showDetails(int index) {
    return Dialog(
        child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 400, height: 500, child: showPhotoView(index)),
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
