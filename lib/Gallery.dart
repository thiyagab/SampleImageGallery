import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ui_firestore/firebase_ui_firestore.dart';
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

  GalleryPage(this.uid, {super.key});

  @override
  GalleryPageState createState() => GalleryPageState();
}

class GalleryPageState extends State<GalleryPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Uint8List>? _localimages;
  String title = 'Image Gallery';
  String description = '';
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  double? width;
  double? height;

  Future getImage(StateSetter bottomState) async {
    List<Uint8List>? images = await ImagePickerWeb.getMultiImagesAsBytes();

    bottomState(() {
      _localimages = images;
    });
  }

  Widget showEntries() {
    var usersQuery = firestore
        .collection('users')
        .doc(widget.uid)
        .collection('entries')
        .orderBy('ts');

    return FirestoreQueryBuilder<Map<String, dynamic>>(
      query: usersQuery,
      builder: (context, snapshot, _) {
        if (snapshot.hasError) {
          return Text("Failed to load objects ${snapshot.error}");
        }
        return GridView.builder(
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: (width! > height! && width! > 600) ? 6 : 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            // if we reached the end of the currently obtained items, we try to
            // obtain more items
            if (snapshot.hasMore && index + 1 == snapshot.docs.length) {
              // Tell FirestoreQueryBuilder to try to obtain more items.
              // It is safe to call this function from within the build method.
              snapshot.fetchMore();
            }
            final entry = snapshot.docs[index].data();
            entry['id']=snapshot.docs[index].id;
            return InkWell(
              onTap: () {
                showDialog(
                    context: context,
                    builder: (_) => showDetails(context, entry));
              },
              child: showThumbNails((entry['thumbnail'].length > 0)
                  ? entry['thumbnail']
                  : entry['url']),
            );
          },
          itemCount: snapshot.docs.length,
        );
      },
    );
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
      final fileRef = _storage.ref().child("$widget.uid/$fileName");
      UploadTask uploadTask = fileRef.putData(_image!);
      await uploadTask.whenComplete(() => null);
      String imageUrl = await fileRef.getDownloadURL();
      imageurls.add(imageUrl);
      //Resize and upload thumbnail, we can use firebase resize funciton if can enable billing
      // switch to blaze plan
      Uint8List thumbnail =
          Img.encodeJpg(Img.copyResize(Img.decodeImage(_image)!, width: 100));
      final resizedfileRef =
          _storage.ref().child("$widget.uid/$fileName" + "_tb");
      UploadTask resizeuploadTask = resizedfileRef.putData(thumbnail!);
      await resizeuploadTask.whenComplete(() => null);
      String thumbnailurl = await resizedfileRef.getDownloadURL();
      thumbnails.add(thumbnailurl);
      count += 1;
      setState(() {
        title = 'Uploading Image $count';
      });
    });

    await updateEntry(description, thumbnails, imageurls);

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Image(s) uploaded successfully"),
    ));
    setState(() {
      title = 'Image Gallery';
    });
  }

  updateEntry(String description, List thumbnails, List urls) async {
    await firestore
        .collection('users')
        .doc(widget.uid)
        .collection('entries')
        .add({
      'description': description,
      'thumbnail': thumbnails,
      'url': urls,
      'ts': DateTime.now().millisecondsSinceEpoch
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
          child: const Text("+")),
    );
  }

  body() {
    return Padding(padding: EdgeInsets.all(30), child: showEntries());
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
                      const SizedBox(height: 10),
                      TextField(
                        minLines: null,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
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
                      const SizedBox(height: 10),
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

  showPhotoView(List urls) {
    if (urls.length == 1) {
      return PhotoView(
        backgroundDecoration: const BoxDecoration(color: Colors.white70),
        imageProvider: NetworkImage(urls[0]),
      );
    } else {
      List newImageUrls = urls;
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

  showThumbNails(List urls) {
    if (urls.length == 1) {
      return Image.network(
        urls[0],
        fit: BoxFit.fitHeight,
        width: 100,
        errorBuilder: errorWidget,
      );
    } else {
      List newImageUrls = urls;
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

  showDetails(BuildContext context, Map<String, dynamic> entry) {
    bool readMode = true;
    String text=entry['description'];
    TextEditingController controller= TextEditingController(text:text);
    return StatefulBuilder(builder: (context, setState) {
      return Dialog(
          child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
        Visibility(
            visible: readMode,
            child: SizedBox(
            width: width! * 0.7,
            height: height! * 0.5,
            child: showPhotoView(entry['url']))),
        const SizedBox(
          height: 20,
        ),
        Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              minLines: null,
              maxLines: null,
              keyboardType: TextInputType.multiline,

              controller: controller,
              readOnly: readMode,
            )),
        const SizedBox(
          height: 5,
        ),
        ButtonBar(children:[
        TextButton(
            onPressed: () {
              if(!readMode){
                //Update clicked
                 firestore
                    .collection('users')
                    .doc(widget.uid)
                    .collection('entries').doc(entry['id']).update({'description':controller.text,'olddescription':entry['description']});

              }
              setState(() {
                readMode = !readMode;
              });

            },
            child: Text(readMode ? 'Edit' : 'Update')),
          Visibility(visible: !readMode,
              child:
          TextButton(
                onPressed: () {
                  setState(() {
                    readMode=!readMode;
                    controller.text=entry['description'];
                  });
                },
                child: const Text('Reset')))]
        ),
        const SizedBox(
          height: 5,
        ),
      ])));
    });
  }
}
