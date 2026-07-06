import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/listing.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listing_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';

/// Create a new listing, or edit an existing one when [existing] is given
/// (Feature 5 reuses this screen). Pops with `true` after a successful save
/// so callers know to reload their lists.
class CreateListingScreen extends ConsumerStatefulWidget {
  final Listing? existing;

  const CreateListingScreen({super.key, this.existing});

  @override
  ConsumerState<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  static const _maxPhotos = 5;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  String _listingType = 'sale';
  String _condition = 'used';
  String? _category;

  final _picker = ImagePicker();

  /// Photos already uploaded (edit mode only) that the user is keeping.
  final List<String> _existingUrls = [];

  /// Newly picked photos, not yet uploaded.
  final List<XFile> _newImages = [];
  final List<Uint8List> _newImagePreviews = [];

  bool _loading = false;
  String? _error;
  String? _photoError;

  bool get _isEditing => widget.existing != null;
  int get _photoCount => _existingUrls.length + _newImages.length;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleController.text = existing.title;
      _descriptionController.text = existing.description;
      _priceController.text = existing.price.toStringAsFixed(2);
      _listingType = existing.listingType;
      _condition = existing.condition;
      _category = existing.category;
      _existingUrls.addAll(existing.imageUrls);
    }
  }

  Future<void> _pickImages() async {
    final remaining = _maxPhotos - _photoCount;
    if (remaining <= 0) return;

    // pickMultiImage rejects limit < 2, so fall back to the single picker
    // when only one slot is left.
    final List<XFile> picked;
    if (remaining == 1) {
      final single = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1600,
      );
      picked = single == null ? [] : [single];
    } else {
      picked = await _picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1600,
        limit: remaining,
      );
    }
    if (picked.isEmpty) return;

    // pickMultiImage's `limit` isn't enforced on all platforms (notably
    // web), so trim here as well.
    final accepted = picked.take(remaining).toList();
    final previews = await Future.wait(accepted.map((f) => f.readAsBytes()));

    if (!mounted) return;
    setState(() {
      _newImages.addAll(accepted);
      _newImagePreviews.addAll(previews);
      _photoError = null;
    });
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState!.validate();
    if (_photoCount == 0) {
      setState(() => _photoError = 'Add at least 1 photo');
    }
    if (!formOk || _photoCount == 0) return;

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uploadedUrls = _newImages.isEmpty
          ? <String>[]
          : await ref
              .read(listingServiceProvider)
              .uploadListingImages(user.id, _newImages);

      final listing = Listing(
        sellerId: user.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        category: _category!,
        condition: _condition,
        listingType: _listingType,
        status: widget.existing?.status ?? 'active',
        imageUrls: [..._existingUrls, ...uploadedUrls],
      );

      final String listingId;
      if (_isEditing) {
        listingId = widget.existing!.id!;
        await ref.read(listingServiceProvider).updateListing(listingId, listing);
      } else {
        listingId = await ref.read(listingServiceProvider).createListing(listing);
      }

      // Index for semantic search — best-effort: a failed embed shouldn't
      // block publishing (the listing still exists, just isn't searchable
      // until re-indexed).
      try {
        await ref.read(backendServiceProvider).embedListing(listingId);
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? 'Listing updated!' : 'Listing published!')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Listing' : 'New Listing')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(context, 'I WANT TO'),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'sale', label: Text('Sell'), icon: Icon(Icons.sell_outlined)),
                      ButtonSegment(value: 'rent', label: Text('Rent out'), icon: Icon(Icons.schedule_outlined)),
                    ],
                    selected: {_listingType},
                    onSelectionChanged: (selection) =>
                        setState(() => _listingType = selection.first),
                  ),
                  const SizedBox(height: 20),
                  _label(context, 'PHOTOS (1-5)'),
                  const SizedBox(height: 8),
                  _buildPhotoStrip(context),
                  if (_photoError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _photoError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _label(context, 'TITLE'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Casio FX-570 calculator',
                      counterText: '',
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Enter a title' : null,
                  ),
                  const SizedBox(height: 20),
                  _label(context, 'DESCRIPTION'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Condition details, pickup spot on campus, etc.',
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Enter a description' : null,
                  ),
                  const SizedBox(height: 20),
                  _label(context, _listingType == 'rent' ? 'PRICE (RM, PER DAY)' : 'PRICE (RM)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      prefixText: 'RM ',
                      hintText: '0.00',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter a price';
                      }
                      final price = double.tryParse(value.trim());
                      if (price == null || price < 0) {
                        return 'Enter a valid price';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _label(context, 'CATEGORY'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _category,
                    hint: const Text('Select a category'),
                    items: Listing.categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (value) => setState(() => _category = value),
                    validator: (value) => value == null ? 'Select a category' : null,
                  ),
                  const SizedBox(height: 20),
                  _label(context, 'CONDITION'),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'new', label: Text('New')),
                      ButtonSegment(value: 'used', label: Text('Used')),
                    ],
                    selected: {_condition},
                    onSelectionChanged: (selection) =>
                        setState(() => _condition = selection.first),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isEditing ? 'Save changes' : 'Publish listing'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    return Semantics(
      label: text,
      child: Text(text, style: Theme.of(context).textTheme.labelLarge),
    );
  }

  Widget _photoThumb({required Widget image, required VoidCallback onRemove}) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: image,
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.inkDeep,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoStrip(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Already-uploaded photos being kept (edit mode)
          for (var i = 0; i < _existingUrls.length; i++)
            _photoThumb(
              image: CachedNetworkImage(
                imageUrl: _existingUrls[i],
                width: 96,
                height: 96,
                fit: BoxFit.cover,
              ),
              onRemove: () => setState(() => _existingUrls.removeAt(i)),
            ),
          // Newly picked photos
          for (var i = 0; i < _newImagePreviews.length; i++)
            _photoThumb(
              image: Image.memory(
                _newImagePreviews[i],
                width: 96,
                height: 96,
                fit: BoxFit.cover,
              ),
              onRemove: () => setState(() {
                _newImages.removeAt(i);
                _newImagePreviews.removeAt(i);
              }),
            ),
          if (_photoCount < _maxPhotos)
            InkWell(
              onTap: _pickImages,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: AppColors.slate),
                    SizedBox(height: 4),
                    Text('Add', style: TextStyle(color: AppColors.slate, fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
