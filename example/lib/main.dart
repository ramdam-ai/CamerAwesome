import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camerawesome/models/orientations.dart';
import 'package:camerawesome_example/utils/orientation_utils.dart';
import 'package:camerawesome_example/widgets/camera_buttons.dart';
import 'package:camerawesome_example/widgets/take_photo_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:path_provider/path_provider.dart';
import 'package:camerawesome/camerawesome_plugin.dart';

void main() {
  runApp(MaterialApp(
    home: MyApp(),
    debugShowCheckedModeBanner: false,
  ));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with TickerProviderStateMixin {

  double bestSizeRatio;

  String _lastPhotoPath;

  bool focus = false;

  bool fullscreen = true;

  ValueNotifier<CameraFlashes> switchFlash = ValueNotifier(CameraFlashes.NONE);

  // TODO: Add zoom smooth animation
  ValueNotifier<double> zoomNotifier = ValueNotifier(0);

  ValueNotifier<Size> photoSize = ValueNotifier(null);

  ValueNotifier<Sensors> sensor = ValueNotifier(Sensors.BACK);

  /// use this to call a take picture
  PictureController _pictureController = new PictureController();

  /// list of available sizes
  List<Size> availableSizes;

  AnimationController _iconsAnimationController;

  AnimationController _previewAnimationController;

  Animation<Offset> _previewAnimation;

  bool animationPlaying = false;

  Timer _previewDismissTimer;

  ValueNotifier<CameraOrientations> _orientation = ValueNotifier(CameraOrientations.PORTRAIT_UP);

  @override
  void initState() {
    super.initState();
    _iconsAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          animationPlaying = false;
        }
      });

    _previewAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1300),
      vsync: this,
    )..addStatusListener((status) {
//        if (status == AnimationStatus.completed) {
//          setState(() {});
//        }
      });
    _previewAnimation = Tween<Offset>(
      begin: const Offset(-2.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _previewAnimationController,
        curve: Curves.elasticOut,
        reverseCurve: Curves.elasticIn));

    photoSize.addListener(() {
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _iconsAnimationController.dispose();
    _previewAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Alignment alignment;
    bool mirror;
    switch (_orientation.value) {
      case CameraOrientations.PORTRAIT_UP:
      case CameraOrientations.PORTRAIT_DOWN:
        alignment = _orientation.value == CameraOrientations.PORTRAIT_UP
            ? Alignment.bottomLeft
            : Alignment.topLeft;
        mirror = _orientation.value == CameraOrientations.PORTRAIT_DOWN;
        break;
      case CameraOrientations.LANDSCAPE_LEFT:
      case CameraOrientations.LANDSCAPE_RIGHT:
        alignment = Alignment.topLeft;
        mirror = _orientation.value == CameraOrientations.LANDSCAPE_LEFT;
        break;
    }

    photoSize.addListener(() {
      if (mounted) setState(() {});
    });
    return Scaffold(
      body: SafeArea(
        child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          fullscreen ? buildFullscreenCamera() : buildSizedScreenCamera(),
          _buildInterface(),
          Align(
            alignment: alignment,
            child: Padding(
              padding: OrientationUtils.isOnPortraitMode(_orientation.value)
                  ? EdgeInsets.symmetric(horizontal: 35.0, vertical: 140)
                  : EdgeInsets.symmetric(vertical: 65.0),
              child: Transform.rotate(
                angle: OrientationUtils.convertOrientationToRadian(
                  _orientation.value,
                ),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(mirror ? pi : 0.0),
                  child: Dismissible(
                    onDismissed: (direction) {},
                    key: UniqueKey(),
                    child: SlideTransition(
                      position: _previewAnimation,
                      child: _buildPreviewPicture(reverseImage: mirror),
                    ),
                  ),
                ),
              ),
            ),
          ),

        ],
    ),
      ));
  }

  Widget _buildPreviewPicture({bool reverseImage = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(
          Radius.circular(15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black45,
            offset: Offset(2, 2),
            blurRadius: 25,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(3.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13.0),
          child: _lastPhotoPath != null
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(reverseImage ? pi : 0.0),
                  child: Image.file(
                    new File(_lastPhotoPath),
                    width: OrientationUtils.isOnPortraitMode(_orientation.value)
                        ? 128
                        : 256,
                  ),
                )
              : Container(
                  width: OrientationUtils.isOnPortraitMode(_orientation.value)
                      ? 128
                      : 256,
                  height: 228,
                  decoration: BoxDecoration(
                    color: Colors.black38,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.photo,
                      color: Colors.white,
                    ),
                  ),
                ), // TODO: Placeholder here
        ),
      ),
    );
  }

  Widget _buildInterface() {
    return SafeArea(
      child: Stack(
        children: <Widget>[
          _buildTopBar(),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              OptionButton(
                icon: Icons.switch_camera,
                rotationController: _iconsAnimationController,
                orientation: _orientation,
                onTapCallback: () async {
                  this.focus = !focus;
                  if (sensor.value == Sensors.FRONT) {
                    sensor.value = Sensors.BACK;
                  } else {
                    sensor.value = Sensors.FRONT;
                  }
                },
              ),
              SizedBox(
                width: 20.0,
              ),
              OptionButton(
                rotationController: _iconsAnimationController,
                icon: (switchFlash.value == CameraFlashes.ALWAYS)
                    ? Icons.flash_on
                    : (switchFlash.value == CameraFlashes.AUTO) ? Icons.flash_auto : Icons.flash_off,
                orientation: _orientation,
                onTapCallback: () {
                  switch(switchFlash.value) {
                    case CameraFlashes.NONE:
                      switchFlash.value = CameraFlashes.AUTO;
                      break;
                    case CameraFlashes.AUTO:
                      switchFlash.value = CameraFlashes.ALWAYS;
                      break;
                    case CameraFlashes.ALWAYS:
                      switchFlash.value = CameraFlashes.NONE;
                      break;
                  }
                  setState(() {});
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              OptionButton(
                icon: Icons.zoom_out,
                rotationController: _iconsAnimationController,
                orientation: _orientation,
                onTapCallback: () {
                  if (zoomNotifier.value >= 0.1) {
                    zoomNotifier.value -= 0.1;
                  }
                  setState(() {});
                },
              ),
              TakePhotoButton(
                onTap: () async {
                  final Directory extDir = await getTemporaryDirectory();
                  var testDir = await Directory('${extDir.path}/test')
                      .create(recursive: true);
                  final String filePath =
                      '${testDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
                  await _pictureController.takePicture(filePath);
                  // lets just make our phone vibrate
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _lastPhotoPath = filePath;
                  });
                  // TODO: Display loading on preview
                  // Display preview box animation
                  if(_previewAnimationController.status == AnimationStatus.completed) {
                    _previewAnimationController.reset();
                  }
                  _previewAnimationController.forward();
                  print("----------------------------------");
                  print("TAKE PHOTO CALLED");
                  print("==> hastakePhoto : ${await File(filePath).exists()}");
                  print("==> path : $filePath");
                  print("----------------------------------");
                },
              ),
              OptionButton(
                icon: Icons.zoom_in,
                rotationController: _iconsAnimationController,
                orientation: _orientation,
                onTapCallback: () {
                  if (zoomNotifier.value <= 0.9) {
                    zoomNotifier.value += 0.1;
                  }
                  setState(() {});
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                IconButton(
                  icon: Icon(
                      fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                      color: Colors.white),
                  onPressed: () => setState(() => fullscreen = !fullscreen),
                ),
                if (photoSize.value != null)
                  Text(
                    'res: ${photoSize.value.width.toInt()} / ${photoSize.value.height.toInt()}',
                    style: TextStyle(color: Colors.white),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _onOrientationChange(CameraOrientations newOrientation) {
    _orientation.value = newOrientation;
    if (_previewDismissTimer != null) {
      _previewDismissTimer.cancel();
    }
  }

  _onPermissionsResult(bool granted) {
    if (!granted) {
      AlertDialog alert = AlertDialog(
        title: Text('Error'),
        content: Text(
            'It seems you doesn\'t authorized some permissions. Please check on your settings and try again.'),
        actions: [
          FlatButton(
            child: Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );

      // show the dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return alert;
        },
      );
    }
  }

  Widget buildFullscreenCamera() {
    return Positioned(
        top: 0,
        left: 0,
        bottom: 0,
        right: 0,
        child: Center(
          child: CameraAwesome(
            onPermissionsResult: _onPermissionsResult,
            selectDefaultSize: (availableSizes) {
              this.availableSizes = availableSizes;
              return availableSizes[0];
            },
            photoSize: photoSize,
            sensor: sensor,
            switchFlashMode: switchFlash,
            zoom: zoomNotifier,
            onOrientationChanged: _onOrientationChange,
          ),
        ));
  }

  Widget buildSizedScreenCamera() {
    return Positioned(
        top: 0,
        left: 0,
        bottom: 0,
        right: 0,
        child: Container(
          color: Colors.black,
          child: Center(
            child: Container(
              height: 300,
              width: MediaQuery.of(context).size.width,
              child: CameraAwesome(
                onPermissionsResult: _onPermissionsResult,
                selectDefaultSize: (availableSizes) {
                  this.availableSizes = availableSizes;
                  return availableSizes[0];
                },
                photoSize: photoSize,
                sensor: sensor,
                fitted: true,
                switchFlashMode: switchFlash,
                zoom: zoomNotifier,
                onOrientationChanged: _onOrientationChange,
              ),
            ),
          ),
        ));
  }
}