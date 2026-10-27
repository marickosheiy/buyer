import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../design/lumear_theme.dart';
import '../services/api_service.dart';
import '../services/mobile_number.dart';
import '../services/top_notification.dart';
import 'product_media.dart';
import 'seller_shop.dart';
import 'seller_shop_images.dart';

class SellerShopEditorScreen extends StatefulWidget {
  const SellerShopEditorScreen({super.key, required this.shop});
  final SellerShop shop;

  @override
  State<SellerShopEditorScreen> createState() => _SellerShopEditorScreenState();
}

class _SellerShopEditorScreenState extends State<SellerShopEditorScreen> {
  final formKey = GlobalKey<FormState>();
  late final controllers = <String, TextEditingController>{
    'owner': TextEditingController(text: widget.shop.owner),
    'name': TextEditingController(text: widget.shop.name),
    'description': TextEditingController(text: widget.shop.description),
    'email': TextEditingController(text: widget.shop.email),
    'phone': TextEditingController(
      text: MobileNumber.forEditing(widget.shop.phone),
    ),
  };
  late ProductMedia? profileImage = widget.shop.profileImage;
  late ProductMedia? coverImage = widget.shop.coverImage;
  bool saving = false;
  bool picking = false;
  bool profileChanged = false;
  bool coverChanged = false;
  String? error;

  Future<void> pickPhoto({required bool profile}) async {
    if (saving || picking) return;
    setState(() {
      picking = true;
      error = null;
    });
    try {
      final photo = await ProductMedia.pick(video: false, existing: []);
      if (photo == null || !mounted) return;
      // Reject renamed or corrupt files before saving them as shop pictures.
      final codec = await ui.instantiateImageCodec(
        photo.bytes!,
        targetWidth: 1024,
      );
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
      if (!mounted) return;
      setState(() {
        if (profile) {
          profileImage = photo;
          profileChanged = true;
        } else {
          coverImage = photo;
          coverChanged = true;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FormatException ? e.message : 'Unable to open this photo. Choose a valid JPG, PNG or WEBP image.',
        );
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> save() async {
    if (saving || picking || !formKey.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final values = {
      for (final e in controllers.entries) e.key: e.value.text.trim(),
    };
    setState(() {
      saving = true;
      error = null;
    });
    try {
      if (widget.shop.connected) {
        await ApiService.patch(
          '/seller/shop',
          body: {
            ...values,
            if (profileChanged) 'profile_image': profileImage?.toJson(),
            if (coverChanged) 'cover_image': coverImage?.toJson(),
          },
        );
      }
      if (!mounted) return;
      widget.shop
        ..profileImage = profileImage
        ..coverImage = coverImage
        ..update(
          owner: values['owner']!,
          name: values['name']!,
          description: values['description']!,
          email: values['email']!,
          phone: values['phone']!,
        );
      setState(() => saving = false);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          saving = false;
        });
        showTopNotification(context, SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget photoControls({required bool profile}) {
    final image = profile ? profileImage : coverImage;
    final label = profile ? 'profile picture' : 'background picture';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          onPressed: saving || picking
              ? null
              : () => pickPhoto(profile: profile),
          child: Row(
            children: [
              Icon(
                profile ? Icons.add_a_photo_outlined : Icons.panorama_outlined,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${image == null ? 'Add' : 'Change'} $label',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        if (image != null)
          TextButton(
            onPressed: saving || picking
                ? null
                : () => setState(() {
                    if (profile) {
                      profileImage = null;
                      profileChanged = true;
                    } else {
                      coverImage = null;
                      coverChanged = true;
                    }
                  }),
            child: Text('Remove $label'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Edit shop profile')),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  if (saving || picking) const LinearProgressIndicator(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SellerShopImages(
                              profileImage: profileImage,
                              coverImage: coverImage,
                            ),
                            const SizedBox(height: 16),
                            photoControls(profile: true),
                            photoControls(profile: false),
                            const SizedBox(height: 8),
                            const Text(
                              'JPG, PNG or WEBP · Up to 5 MB per photo.',
                            ),
                            const SizedBox(height: 24),
                            if (error != null) ...[
                              Text(
                                error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            for (final field in const {
                              'owner': 'Seller name',
                              'name': 'Shop name',
                              'description': 'Shop story',
                              'email': 'Email address',
                              'phone': 'Mobile number',
                            }.entries)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: TextFormField(
                                  controller: controllers[field.key],
                                  enabled: !saving,
                                  readOnly:
                                      widget.shop.connected &&
                                      (field.key == 'email' ||
                                          field.key == 'phone'),
                                  decoration: InputDecoration(
                                    labelText: field.value,
                                    errorMaxLines: 2,
                                    helperText:
                                        field.key == 'owner' ||
                                            field.key == 'name'
                                        ? 'Required'
                                        : 'Optional',
                                  ),
                                  maxLength: field.key == 'description'
                                      ? 300
                                      : field.key == 'phone'
                                      ? MobileNumber.maxLength
                                      : 100,
                                  maxLines: field.key == 'description' ? 3 : 1,
                                  inputFormatters: field.key == 'phone'
                                      ? MobileNumber.inputFormatters
                                      : null,
                                  keyboardType: field.key == 'email'
                                      ? TextInputType.emailAddress
                                      : field.key == 'phone'
                                      ? TextInputType.phone
                                      : TextInputType.text,
                                  validator: (value) {
                                    final text = value?.trim() ?? '';
                                    if ((field.key == 'owner' ||
                                            field.key == 'name') &&
                                        text.isEmpty) {
                                      return 'Please enter your ${field.value.toLowerCase()}.';
                                    }
                                    if (field.key == 'email' &&
                                        text.isNotEmpty &&
                                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                            .hasMatch(text)) {
                                      return 'Enter a valid email address.';
                                    }
                                    if (field.key == 'phone' &&
                                        text.isNotEmpty &&
                                        !MobileNumber.isValid(text)) {
                                      return MobileNumber.error;
                                    }
                                    return null;
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: saving
                                ? null
                                : () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: saving || picking ? null : save,
                            child: Text(saving ? 'Saving…' : 'Save changes'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
