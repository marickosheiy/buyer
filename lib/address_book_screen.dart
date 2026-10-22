import 'design/lumear_theme.dart';

import 'dart:convert';

import 'package:flutter/material.dart';

import 'services/ui_action.dart';

import 'package:http/http.dart' as http;

import 'address_manager.dart';
import 'design/components.dart';

class AddressBookScreen extends StatefulWidget {
  final String? selectedAddressId;

  const AddressBookScreen({super.key, this.selectedAddressId});

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  static Color get cream => LumearColors.cream;
  static Color get maroon => LumearColors.maroon;
  static Color get darkMaroon => LumearColors.dark;
  static Color get lightMaroon => LumearColors.light;
  static Color get fieldColor => LumearColors.field;
  static Color get darkText => LumearColors.ink;

  String? selectedId;

  @override
  void initState() {
    super.initState();

    selectedId =
        widget.selectedAddressId ?? AddressManager.instance.defaultAddress?.id;
  }

  // ============================================================
  // USE SELECTED ADDRESS
  // ============================================================

  void useSelectedAddress() {
    if (selectedId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select an address first.'),
          backgroundColor: LumearColors.action,
        ),
      );
      return;
    }

    final address = AddressManager.instance.addresses.value.firstWhere(
      (item) => item.id == selectedId,
    );

    Navigator.pop(context, address);
  }

  // ============================================================
  // ADD ADDRESS
  // ============================================================

  Future<void> addAddress() async {
    final result = await Navigator.push<SavedAddress?>(
      context,
      MaterialPageRoute(builder: (context) => const AddressFormScreen()),
    );

    if (!mounted || result == null) return;

    setState(() {
      selectedId = result.id;
    });
  }

  // ============================================================
  // EDIT ADDRESS
  // ============================================================

  Future<void> editAddress(SavedAddress address) async {
    final result = await Navigator.push<SavedAddress?>(
      context,
      MaterialPageRoute(
        builder: (context) => AddressFormScreen(existingAddress: address),
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      selectedId = result.id;
    });
  }

  // ============================================================
  // DELETE ADDRESS
  // ============================================================

  Future<void> deleteAddress(SavedAddress address) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cream,
          title: Text(
            'Delete Address?',
            style: TextStyle(color: darkMaroon, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete your ${address.label.toLowerCase()} address?',
            style: TextStyle(color: darkText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('CANCEL', style: TextStyle(color: lightMaroon)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'DELETE',
                style: TextStyle(color: maroon, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) return;

    if (!await runBuyerAction(
      context,
      () => AddressManager.instance.deleteAddress(address.id),
    )) {
      return;
    }

    if (!mounted) return;

    setState(() {
      if (selectedId == address.id) {
        selectedId = AddressManager.instance.defaultAddress?.id;
      }
    });
  }

  // ============================================================
  // SET DEFAULT
  // ============================================================

  Future<void> setDefault(SavedAddress address) async {
    if (!await runBuyerAction(
      context,
      () => AddressManager.instance.setDefault(address.id),
    )) {
      return;
    }
    if (!mounted) return;

    setState(() {
      selectedId = address.id;
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    LumearAppearance.watch(context);
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: cream,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: darkMaroon,
            size: 20,
          ),
        ),
        title: Text(
          'Your address book',
          style: TextStyle(
            color: darkMaroon,
            fontFamily: 'CormorantGaramond',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ValueListenableBuilder<List<SavedAddress>>(
        valueListenable: AddressManager.instance.addresses,
        builder: (context, addresses, child) {
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 22),
                child: PageHeading(
                  'A place for your finds.',
                  eyebrow: 'DELIVERY DETAILS',
                ),
              ),
              Expanded(
                child: addresses.isEmpty
                    ? buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                        itemCount: addresses.length,
                        itemBuilder: (context, index) {
                          final address = addresses[index];

                          return buildAddressCard(address);
                        },
                      ),
              ),

              // ==================================================
              // BOTTOM BUTTONS
              // ==================================================
              Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                decoration: BoxDecoration(
                  color: cream,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: addAddress,
                        icon: const Icon(Icons.add_rounded, size: 21),
                        label: const Text(
                          'ADD NEW ADDRESS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: maroon,
                          side: BorderSide(color: maroon, width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),

                    if (addresses.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: useSelectedAddress,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: LumearColors.action,
                            foregroundColor: LumearColors.ivory,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'USE THIS ADDRESS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: fieldColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.location_on_outlined, color: maroon, size: 45),
            ),
            const SizedBox(height: 20),
            Text(
              'No Saved Addresses',
              style: TextStyle(
                color: darkMaroon,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a delivery address so you can check out faster.',
              textAlign: TextAlign.center,
              style: TextStyle(color: lightMaroon, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: addAddress,
              style: ElevatedButton.styleFrom(
                backgroundColor: LumearColors.action,
                foregroundColor: LumearColors.ivory,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'ADD ADDRESS',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ADDRESS CARD
  // ============================================================

  Widget buildAddressCard(SavedAddress address) {
    final isSelected = selectedId == address.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedId = address.id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: LumearColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? maroon : LumearColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // RADIO
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? maroon : lightMaroon,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: maroon,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              address.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: darkText,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          buildLabel(address.label),
                        ],
                      ),

                      const SizedBox(height: 5),

                      Text(
                        address.phone,
                        style: TextStyle(color: lightMaroon, fontSize: 11),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  onPressed: () => editAddress(address),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.edit_outlined, color: maroon, size: 19),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: fieldColor,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_outlined, color: maroon, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address.formattedAddress,
                      style: TextStyle(
                        color: darkText,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                if (address.isDefault)
                  const Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                        size: 17,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Default',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                else
                  GestureDetector(
                    onTap: () => setDefault(address),
                    child: Text(
                      'Set as Default',
                      style: TextStyle(
                        color: maroon,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                const Spacer(),

                GestureDetector(
                  onTap: () => deleteAddress(address),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: lightMaroon,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildLabel(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: fieldColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: maroon,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ==================================================================
// ADDRESS FORM
// ==================================================================

class AddressFormScreen extends StatefulWidget {
  final SavedAddress? existingAddress;

  const AddressFormScreen({super.key, this.existingAddress});

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  static Color get cream => LumearColors.cream;
  static Color get maroon => LumearColors.maroon;
  static Color get darkMaroon => LumearColors.dark;
  static Color get lightMaroon => LumearColors.light;
  static Color get darkText => LumearColors.ink;

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final houseStreetController = TextEditingController();
  final postalCodeController = TextEditingController();
  bool saving = false;

  String selectedLabel = 'Home';

  String? selectedRegion;
  String? selectedProvince;
  String? selectedCity;
  String? selectedBarangay;

  List<Map<String, dynamic>> regions = [];
  List<Map<String, dynamic>> provinces = [];
  List<Map<String, dynamic>> cities = [];
  List<Map<String, dynamic>> barangays = [];

  bool loadingRegions = true;
  bool loadingProvinces = false;
  bool loadingCities = false;
  bool loadingBarangays = false;

  @override
  void initState() {
    super.initState();

    if (widget.existingAddress != null) {
      final address = widget.existingAddress!;

      nameController.text = address.fullName;
      phoneController.text = address.phone;
      houseStreetController.text = address.houseStreet;
      postalCodeController.text = address.postalCode;

      selectedLabel = address.label;
    }

    loadRegions();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    houseStreetController.dispose();
    postalCodeController.dispose();
    super.dispose();
  }

  // ============================================================
  // PSGC API
  // ============================================================

  static const String baseUrl = 'https://psgc.cloud/api/v2';

  Future<List<Map<String, dynamic>>> fetchData(String endpoint) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl$endpoint'));

      if (response.statusCode != 200) {
        throw Exception('Failed to load data');
      }

      final decoded = jsonDecode(response.body);

      if (decoded is List) {
        return List<Map<String, dynamic>>.from(
          decoded.map((item) => Map<String, dynamic>.from(item)),
        );
      }

      if (decoded is Map && decoded['data'] is List) {
        return List<Map<String, dynamic>>.from(
          decoded['data'].map((item) => Map<String, dynamic>.from(item)),
        );
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> loadRegions() async {
    setState(() {
      loadingRegions = true;
    });

    final result = await fetchData('/regions');

    if (!mounted) return;

    setState(() {
      regions = result;
      loadingRegions = false;
    });

    // Restore existing address region
    if (widget.existingAddress != null) {
      final existing = widget.existingAddress!;

      final match = regions.where(
        (region) => _getName(region) == existing.region,
      );

      if (match.isNotEmpty) {
        final region = match.first;

        setState(() {
          selectedRegion = _getCode(region);
        });

        await loadProvinces(selectedRegion!, restoreValue: existing.province);
      }
    }
  }

  Future<void> loadProvinces(String regionCode, {String? restoreValue}) async {
    setState(() {
      loadingProvinces = true;
      provinces = [];
      cities = [];
      barangays = [];
      selectedProvince = null;
      selectedCity = null;
      selectedBarangay = null;
    });

    final result = await fetchData('/regions/$regionCode/provinces');

    if (!mounted) return;

    setState(() {
      provinces = result;
      loadingProvinces = false;
    });

    if (restoreValue != null) {
      final match = provinces.where(
        (province) => _getName(province) == restoreValue,
      );

      if (match.isNotEmpty) {
        final province = match.first;

        setState(() {
          selectedProvince = _getCode(province);
        });

        await loadCities(
          selectedProvince!,
          restoreValue: widget.existingAddress?.cityMunicipality,
        );
      }
    }
  }

  Future<void> loadCities(String provinceCode, {String? restoreValue}) async {
    setState(() {
      loadingCities = true;
      cities = [];
      barangays = [];
      selectedCity = null;
      selectedBarangay = null;
    });

    final result = await fetchData(
      '/provinces/$provinceCode/cities-municipalities',
    );

    if (!mounted) return;

    setState(() {
      cities = result;
      loadingCities = false;
    });

    if (restoreValue != null) {
      final match = cities.where((city) => _getName(city) == restoreValue);

      if (match.isNotEmpty) {
        final city = match.first;

        setState(() {
          selectedCity = _getCode(city);
        });

        await loadBarangays(
          selectedCity!,
          restoreValue: widget.existingAddress?.barangay,
        );
      }
    }
  }

  Future<void> loadBarangays(String cityCode, {String? restoreValue}) async {
    setState(() {
      loadingBarangays = true;
      barangays = [];
      selectedBarangay = null;
    });

    final result = await fetchData(
      '/cities-municipalities/$cityCode/barangays',
    );

    if (!mounted) return;

    setState(() {
      barangays = result;
      loadingBarangays = false;
    });

    if (restoreValue != null) {
      final match = barangays.where(
        (barangay) => _getName(barangay) == restoreValue,
      );

      if (match.isNotEmpty) {
        setState(() {
          selectedBarangay = _getCode(match.first);
        });
      }
    }
  }

  String _getName(Map<String, dynamic> item) {
    return (item['name'] ??
            item['region_name'] ??
            item['province_name'] ??
            item['city_name'] ??
            item['barangay_name'] ??
            '')
        .toString();
  }

  String _getCode(Map<String, dynamic> item) {
    return (item['code'] ?? item['psgc_code'] ?? item['code_name'] ?? '')
        .toString();
  }

  String? getSelectedName(List<Map<String, dynamic>> list, String? code) {
    if (code == null) return null;

    for (final item in list) {
      if (_getCode(item) == code) {
        return _getName(item);
      }
    }

    return null;
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> saveAddress() async {
    if (saving) return;
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final houseStreet = houseStreetController.text.trim();

    if (name.isEmpty ||
        phone.isEmpty ||
        houseStreet.isEmpty ||
        selectedRegion == null ||
        selectedProvince == null ||
        selectedCity == null ||
        selectedBarangay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please complete all address fields.'),
          backgroundColor: LumearColors.action,
        ),
      );
      return;
    }

    final regionName = getSelectedName(regions, selectedRegion);

    final provinceName = getSelectedName(provinces, selectedProvince);

    final cityName = getSelectedName(cities, selectedCity);

    final barangayName = getSelectedName(barangays, selectedBarangay);

    if (regionName == null ||
        provinceName == null ||
        cityName == null ||
        barangayName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a valid address.'),
          backgroundColor: LumearColors.action,
        ),
      );
      return;
    }

    if (AddressManager.instance.connected &&
        !RegExp(r'^\d{4}$').hasMatch(postalCodeController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a four-digit postal code.')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      if (widget.existingAddress == null) {
        final address = SavedAddress(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          label: selectedLabel,
          fullName: name,
          phone: phone,
          region: regionName,
          province: provinceName,
          cityMunicipality: cityName,
          barangay: barangayName,
          houseStreet: houseStreet,
          postalCode: postalCodeController.text.trim(),
        );
        final saved = await AddressManager.instance.addAddress(address);
        if (mounted) Navigator.pop(context, saved);
      } else {
        final old = widget.existingAddress!;

        final updated = SavedAddress(
          id: old.id,
          label: selectedLabel,
          fullName: name,
          phone: phone,
          region: regionName,
          province: provinceName,
          cityMunicipality: cityName,
          barangay: barangayName,
          houseStreet: houseStreet,
          isDefault: old.isDefault,
          postalCode: postalCodeController.text.trim(),
        );
        await AddressManager.instance.updateAddress(updated);
        if (mounted) Navigator.pop(context, updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  // ============================================================
  // BUILD FORM
  // ============================================================

  @override
  Widget build(BuildContext context) {
    LumearAppearance.watch(context);
    final editing = widget.existingAddress != null;

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: cream,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: darkMaroon,
            size: 20,
          ),
        ),
        title: Text(
          editing ? 'Edit Address' : 'Add New Address',
          style: TextStyle(
            color: darkMaroon,
            fontFamily: 'CormorantGaramond',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================================================
            // CONTACT INFORMATION
            // ==================================================

            sectionTitle(Icons.person_outline_rounded, 'Contact Information'),

            const SizedBox(height: 12),

            buildTextField(
              controller: nameController,
              label: 'Full Name',
              hint: 'Enter your full name',
              icon: Icons.person_outline_rounded,
            ),

            const SizedBox(height: 12),

            buildTextField(
              controller: phoneController,
              label: 'Phone Number',
              hint: '09XXXXXXXXX',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 25),

            // ==================================================
            // ADDRESS
            // ==================================================
            sectionTitle(Icons.location_on_outlined, 'Address'),
            if (AddressManager.instance.connected)
              buildTextField(
                controller: postalCodeController,
                label: 'Postal code',
                hint: 'Four-digit postal code',
                icon: Icons.local_post_office_outlined,
                keyboardType: TextInputType.number,
              ),

            const SizedBox(height: 12),

            buildDropdown(
              label: 'Region',
              value: selectedRegion,
              items: regions,
              loading: loadingRegions,
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  selectedRegion = value;
                });

                loadProvinces(value);
              },
            ),

            const SizedBox(height: 12),

            buildDropdown(
              label: 'Province',
              value: selectedProvince,
              items: provinces,
              loading: loadingProvinces,
              enabled: selectedRegion != null,
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  selectedProvince = value;
                });

                loadCities(value);
              },
            ),

            const SizedBox(height: 12),

            buildDropdown(
              label: 'City / Municipality',
              value: selectedCity,
              items: cities,
              loading: loadingCities,
              enabled: selectedProvince != null,
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  selectedCity = value;
                });

                loadBarangays(value);
              },
            ),

            const SizedBox(height: 12),

            buildDropdown(
              label: 'Barangay',
              value: selectedBarangay,
              items: barangays,
              loading: loadingBarangays,
              enabled: selectedCity != null,
              onChanged: (value) {
                setState(() {
                  selectedBarangay = value;
                });
              },
            ),

            const SizedBox(height: 12),

            buildTextField(
              controller: houseStreetController,
              label: 'House No. / Street',
              hint: 'House no., street name, subdivision, etc.',
              icon: Icons.home_outlined,
            ),

            const SizedBox(height: 25),

            // ==================================================
            // ADDRESS LABEL
            // ==================================================
            sectionTitle(Icons.label_outline_rounded, 'Address Label'),

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                buildLabelChoice('Home'),
                buildLabelChoice('School'),
                buildLabelChoice('Work'),
                buildLabelChoice('Other'),
              ],
            ),

            const SizedBox(height: 30),

            // ==================================================
            // SAVE BUTTON
            // ==================================================
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: saving ? null : saveAddress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: LumearColors.action,
                  foregroundColor: LumearColors.ivory,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Text(
                  editing ? 'SAVE CHANGES' : 'SAVE ADDRESS',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: darkText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(color: darkText, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: lightMaroon, fontSize: 12),
            prefixIcon: Icon(icon, color: maroon, size: 20),
            filled: true,
            fillColor: LumearColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: LumearColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: LumearColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: maroon, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DROPDOWN
  // ============================================================

  Widget buildDropdown({
    required String label,
    required String? value,
    required List<Map<String, dynamic>> items,
    required bool loading,
    bool enabled = true,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: darkText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: ValueKey(value),
          initialValue: items.any((item) => _getCode(item) == value)
              ? value
              : null,
          isExpanded: true,
          onChanged: enabled && !loading ? onChanged : null,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: maroon),
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled ? LumearColors.surface : LumearColors.field,
            prefixIcon: Icon(
              Icons.location_on_outlined,
              color: maroon,
              size: 20,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 4,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: LumearColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: LumearColors.border),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: LumearColors.border),
            ),
          ),
          hint: Text(
            loading
                ? 'Loading...'
                : enabled
                ? 'Select $label'
                : 'Select previous field first',
            style: TextStyle(color: lightMaroon, fontSize: 12),
          ),
          items: items.map((item) {
            final code = _getCode(item);
            final name = _getName(item);

            return DropdownMenuItem<String>(
              value: code,
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: darkText, fontSize: 12),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ============================================================
  // LABEL CHOICE
  // ============================================================

  Widget buildLabelChoice(String label) {
    final selected = selectedLabel == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedLabel = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? LumearColors.action : LumearColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? maroon : LumearColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : darkText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: maroon, size: 21),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: darkMaroon,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
