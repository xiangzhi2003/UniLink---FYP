import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/listing.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listing_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_tokens.dart';
import '../../utils/error_messages.dart';
import '../../widgets/app_button.dart';
import '../../widgets/colored_header.dart';

/// Create a new listing, or edit an existing one when [existing] is given.
/// A 3-step wizard (Basics → Category & Condition → Pricing & Location).
/// Pops with `true` after a successful save so callers know to reload.
class CreateListingScreen extends ConsumerStatefulWidget {
  final Listing? existing;

  const CreateListingScreen({super.key, this.existing});

  @override
  ConsumerState<CreateListingScreen> createState() =>
      _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  static const _maxPhotos = 5;
  static const _stepCount = 3;
  static const _stepTitles = [
    'Basics',
    'Category & Condition',
    'Pricing & Location',
  ];

  final _pageController = PageController();
  int _step = 0;

  final _basicsFormKey = GlobalKey<FormState>();
  final _pricingFormKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _tagsController = TextEditingController();

  String _listingType = 'sale';
  String _condition = 'used';
  String? _category;
  String? _categoryError;

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
      _locationController.text = existing.location ?? '';
      _tagsController.text = existing.tags.join(', ');
    }

    // Keeps the pricing step's live preview card in sync as the user types —
    // TextEditingController changes don't trigger a rebuild on their own.
    _titleController.addListener(_refreshPreview);
    _priceController.addListener(_refreshPreview);
  }

  void _refreshPreview() {
    if (_step == 2) setState(() {});
  }

  /// Splits the free-text tags field on commas/whitespace into clean,
  /// lowercase tags (blank entries dropped).
  List<String> _parseTags(String raw) {
    return raw
        .split(RegExp(r'[,\s]+'))
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toList();
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

  void _goToStep(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: AppDurations.normal,
      curve: Curves.easeOut,
    );
  }

  /// Validates only the fields on the current step before advancing — the
  /// wizard's pages all exist in the tree at once (a plain `PageView`, not
  /// `.builder`), so a single whole-form `validate()` would also touch
  /// not-yet-filled fields on later steps and block progress unfairly.
  void _next() {
    if (_step == 0) {
      final basicsOk = _basicsFormKey.currentState!.validate();
      final photosOk = _photoCount > 0;
      setState(() => _photoError = photosOk ? null : 'Add at least 1 photo');
      if (!basicsOk || !photosOk) return;
    } else if (_step == 1) {
      if (_category == null) {
        setState(() => _categoryError = 'Select a category');
        return;
      }
    }
    if (_step < _stepCount - 1) _goToStep(_step + 1);
  }

  void _back() {
    if (_step > 0) {
      _goToStep(_step - 1);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _submit() async {
    final pricingOk = _pricingFormKey.currentState!.validate();
    if (!pricingOk) return;

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uploadedUrls =
          _newImages.isEmpty
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
        tags: _parseTags(_tagsController.text),
        location:
            _locationController.text.trim().isEmpty
                ? null
                : _locationController.text.trim(),
      );

      final String listingId;
      if (_isEditing) {
        listingId = widget.existing!.id!;
        await ref
            .read(listingServiceProvider)
            .updateListing(listingId, listing);
      } else {
        listingId = await ref
            .read(listingServiceProvider)
            .createListing(listing);
      }

      // Index for semantic search — best-effort: a failed embed shouldn't
      // block publishing (the listing still exists, just isn't searchable
      // until re-indexed).
      try {
        await ref.read(backendServiceProvider).embedListing(listingId);
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Listing updated!' : 'Listing published!',
            ),
          ),
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
    _pageController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildBasicsStep(context),
                    _buildCategoryStep(context),
                    _buildPricingStep(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return ColoredHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _back,
                icon: const Icon(Icons.chevron_left, color: Colors.white),
              ),
              Expanded(
                child: Text(
                  _isEditing ? 'Edit Listing' : 'Post a Listing',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${_step + 1}/$_stepCount',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (var i = 0; i < _stepCount; i++) ...[
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= _step ? Colors.white : Colors.white24,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                if (i < _stepCount - 1) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'STEP ${_step + 1} — ${_stepTitles[_step].toUpperCase()}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicsStep(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Form(
        key: _basicsFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _titleController,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Casio FX-570 calculator',
                counterText: '',
              ),
              validator:
                  (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Enter a title'
                          : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Condition details, pickup spot on campus, etc.',
              ),
              validator:
                  (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Enter a description'
                          : null,
            ),
            const SizedBox(height: AppSpacing.xl),
            _label(context, 'PHOTOS (1-$_maxPhotos)'),
            const SizedBox(height: AppSpacing.sm),
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
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(label: 'Next', onPressed: _next),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryStep(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: _category,
            hint: const Text('Select a category'),
            items:
                Listing.categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
            onChanged:
                (value) => setState(() {
                  _category = value;
                  _categoryError = null;
                }),
            decoration: InputDecoration(
              labelText: 'Category',
              errorText: _categoryError,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _label(context, 'CONDITION'),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'new', label: Text('New')),
              ButtonSegment(value: 'used', label: Text('Used')),
            ],
            selected: {_condition},
            onSelectionChanged:
                (selection) => setState(() => _condition = selection.first),
          ),
          const SizedBox(height: AppSpacing.lg),
          _label(context, 'I WANT TO'),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'sale',
                label: Text('Sell'),
                icon: Icon(Icons.sell_outlined),
              ),
              ButtonSegment(
                value: 'rent',
                label: Text('Rent out'),
                icon: Icon(Icons.schedule_outlined),
              ),
            ],
            selected: {_listingType},
            onSelectionChanged:
                (selection) => setState(() => _listingType = selection.first),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Row(
            children: [
              Expanded(child: SecondaryButton(label: 'Back', onPressed: _back)),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: PrimaryButton(label: 'Next', onPressed: _next)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPricingStep(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isRent = _listingType == 'rent';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Form(
        key: _pricingFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(context, 'PRICE (RM)'),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                prefixText: 'RM ',
                hintText: isRent ? '0.00 per day' : '0.00',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a price';
                }
                final price = double.tryParse(value.trim());
                if (price == null || price < 0) return 'Enter a valid price';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            _label(context, 'MEETUP LOCATION'),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                hintText: 'e.g. Faculty of Computing, UTM',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _label(context, 'TAGS (COMMA SEPARATED)'),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                hintText: 'e.g. calculus, math, year1',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _buildPreviewCard(context, scheme, isRent),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: AppSpacing.xxl),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Back',
                    onPressed: _loading ? null : _back,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: PrimaryButton(
                    label: _isEditing ? 'Save changes' : 'Publish listing',
                    isLoading: _loading,
                    onPressed: _loading ? null : _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(
    BuildContext context,
    ColorScheme scheme,
    bool isRent,
  ) {
    final title = _titleController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PREVIEW',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title.isEmpty ? 'Your listing title' : title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'RM ${price.toStringAsFixed(0)}${isRent ? ' /day' : ''}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_condition == 'new' ? 'New' : 'Used'}${_category != null ? ' · $_category' : ''}',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    return Semantics(
      label: text,
      child: Text(text, style: Theme.of(context).textTheme.labelLarge),
    );
  }

  Widget _photoThumb(
    BuildContext context, {
    required Widget image,
    required VoidCallback onRemove,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: image,
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: scheme.inverseSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: scheme.onInverseSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoStrip(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Already-uploaded photos being kept (edit mode)
          for (var i = 0; i < _existingUrls.length; i++)
            _photoThumb(
              context,
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
              context,
              image: Image.memory(
                _newImagePreviews[i],
                width: 96,
                height: 96,
                fit: BoxFit.cover,
              ),
              onRemove:
                  () => setState(() {
                    _newImages.removeAt(i);
                    _newImagePreviews.removeAt(i);
                  }),
            ),
          if (_photoCount < _maxPhotos)
            InkWell(
              onTap: _pickImages,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
