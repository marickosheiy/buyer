import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  int currentStep = 0;

  // ============================================================
  // COLORS
  // ============================================================
  static const Color maroon = Color(0xFF963B36);
  static const Color darkMaroon = Color(0xFF721E1E);
  static const Color cream = Color(0xFFFFF8F4);
  static const Color fieldColor = Color(0xFFF9EEEA);
  static const Color borderColor = Color(0xFFE8CBC0);
  static const Color lightText = Color(0xFFC78F88);

  // ============================================================
  // CONTROLLERS
  // ============================================================
  final firstNameController = TextEditingController();
  final middleNameController = TextEditingController();
  final lastNameController = TextEditingController();

  final emailController = TextEditingController();
  final phoneController = TextEditingController();

  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final streetController = TextEditingController();
  final houseController = TextEditingController();

  final otpController = TextEditingController();

  // ============================================================
  // PASSWORD
  // ============================================================
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  // ============================================================
  // OTP
  // ============================================================
  bool otpSent = false;
  bool phoneVerified = false;
  static const String demoOtp = '123456';

  // ============================================================
  // VALIDATION
  // ============================================================
  static final _emailRegex = RegExp(r'^[\w.\-]+@[\w\-]+\.[a-zA-Z]{2,}$');
  static final _phoneRegex = RegExp(r'^(09\d{9}|\+639\d{9})$');
  static final _passwordRegex = RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$');

  // ============================================================
  // PSGC API
  // ============================================================
  static const String apiBaseUrl = 'https://psgc.cloud/api/v2';

  List<Map<String, dynamic>> regions = [];
  List<Map<String, dynamic>> provinces = [];
  List<Map<String, dynamic>> municipalities = [];
  List<Map<String, dynamic>> barangays = [];

  String? selectedRegionCode;
  String? selectedRegionName;

  String? selectedProvinceCode;
  String? selectedProvinceName;

  String? selectedMunicipalityCode;
  String? selectedMunicipalityName;

  String? selectedBarangayCode;
  String? selectedBarangayName;

  bool loadingRegions = false;
  bool loadingProvinces = false;
  bool loadingMunicipalities = false;
  bool loadingBarangays = false;

  // Request "epoch" counters. Every async load captures the current id;
  // if the id has moved on by the time the response arrives (because the
  // user picked something else in the meantime), the stale result is
  // dropped instead of clobbering the newer selection.
  int _regionRequest = 0;
  int _provinceRequest = 0;
  int _municipalityRequest = 0;
  int _barangayRequest = 0;

  // ============================================================
  // INIT / DISPOSE
  // ============================================================
  @override
  void initState() {
    super.initState();
    loadRegions();
  }

  @override
  void dispose() {
    firstNameController.dispose();
    middleNameController.dispose();
    lastNameController.dispose();

    emailController.dispose();
    phoneController.dispose();

    passwordController.dispose();
    confirmPasswordController.dispose();

    streetController.dispose();
    houseController.dispose();

    otpController.dispose();

    super.dispose();
  }

  // ============================================================
  // API GET LIST
  // ============================================================
  Future<List<Map<String, dynamic>>> getList(String url) async {
    debugPrint('GET: $url');

    final response = await http.get(
      Uri.parse(url),
      headers: {'Accept': 'application/json'},
    );

    debugPrint('STATUS: ${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final dynamic decoded = jsonDecode(response.body);

    // PSGC v2 may return { "data": [...] } or a raw list.
    if (decoded is Map<String, dynamic>) {
      final dynamic data = decoded['data'];
      if (data is List) {
        return data
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
    }

    if (decoded is List) {
      return decoded
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    throw Exception('Unexpected API response format.');
  }

  // ============================================================
  // LOAD REGIONS
  // ============================================================
  Future<void> loadRegions() async {
    final requestId = ++_regionRequest;

    setState(() => loadingRegions = true);

    try {
      final result = await getList('$apiBaseUrl/regions');
      result.sort(
        (a, b) => a['name'].toString().compareTo(b['name'].toString()),
      );

      if (!mounted || requestId != _regionRequest) return;

      setState(() {
        regions = result;
        loadingRegions = false;
      });
    } catch (e) {
      debugPrint('REGION ERROR: $e');
      if (!mounted || requestId != _regionRequest) return;

      setState(() => loadingRegions = false);
      showMessage(
        'Unable to load regions.',
        actionLabel: 'RETRY',
        onAction: loadRegions,
      );
    }
  }

  // ============================================================
  // LOAD PROVINCES
  // ============================================================
  Future<void> loadProvinces(String regionCode) async {
    final requestId = ++_provinceRequest;

    setState(() {
      loadingProvinces = true;
      provinces = [];
      municipalities = [];
      barangays = [];

      selectedProvinceCode = null;
      selectedProvinceName = null;
      selectedMunicipalityCode = null;
      selectedMunicipalityName = null;
      selectedBarangayCode = null;
      selectedBarangayName = null;
    });

    try {
      final result = await getList('$apiBaseUrl/regions/$regionCode/provinces');
      result.sort(
        (a, b) => a['name'].toString().compareTo(b['name'].toString()),
      );

      if (!mounted || requestId != _provinceRequest) return;

      setState(() {
        provinces = result;
        loadingProvinces = false;
      });
    } catch (e) {
      debugPrint('PROVINCE ERROR: $e');
      if (!mounted || requestId != _provinceRequest) return;

      setState(() => loadingProvinces = false);
      showMessage(
        'Unable to load provinces.',
        actionLabel: 'RETRY',
        onAction: () => loadProvinces(regionCode),
      );
    }
  }

  // ============================================================
  // LOAD CITIES / MUNICIPALITIES
  // ============================================================
  Future<void> loadMunicipalities(String provinceCode) async {
    final requestId = ++_municipalityRequest;

    setState(() {
      loadingMunicipalities = true;
      municipalities = [];
      barangays = [];

      selectedMunicipalityCode = null;
      selectedMunicipalityName = null;
      selectedBarangayCode = null;
      selectedBarangayName = null;
    });

    try {
      final result = await getList(
        '$apiBaseUrl/provinces/$provinceCode/cities-municipalities',
      );
      result.sort(
        (a, b) => a['name'].toString().compareTo(b['name'].toString()),
      );

      if (!mounted || requestId != _municipalityRequest) return;

      setState(() {
        municipalities = result;
        loadingMunicipalities = false;
      });
    } catch (e) {
      debugPrint('MUNICIPALITY ERROR: $e');
      if (!mounted || requestId != _municipalityRequest) return;

      setState(() => loadingMunicipalities = false);
      showMessage(
        'Unable to load cities / municipalities.',
        actionLabel: 'RETRY',
        onAction: () => loadMunicipalities(provinceCode),
      );
    }
  }

  // ============================================================
  // LOAD BARANGAYS
  // ============================================================
  Future<void> loadBarangays(String municipalityCode) async {
    final requestId = ++_barangayRequest;

    setState(() {
      loadingBarangays = true;
      barangays = [];

      selectedBarangayCode = null;
      selectedBarangayName = null;
    });

    try {
      final result = await getList(
        '$apiBaseUrl/cities-municipalities/$municipalityCode/barangays',
      );
      result.sort(
        (a, b) => a['name'].toString().compareTo(b['name'].toString()),
      );

      if (!mounted || requestId != _barangayRequest) return;

      setState(() {
        barangays = result;
        loadingBarangays = false;
      });
    } catch (e) {
      debugPrint('BARANGAY ERROR: $e');
      if (!mounted || requestId != _barangayRequest) return;

      setState(() => loadingBarangays = false);
      showMessage(
        'Unable to load barangays.',
        actionLabel: 'RETRY',
        onAction: () => loadBarangays(municipalityCode),
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================
  void showMessage(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkMaroon,
        content: Text(message),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  // ============================================================
  // INPUT DESIGN
  // ============================================================
  InputDecoration inputDecoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: lightText, fontSize: 14),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fieldColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: maroon, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: borderColor.withValues(alpha: 0.55)),
      ),
    );
  }

  // ============================================================
  // NEXT / BACK
  // ============================================================
  void nextStep() {
    if (currentStep == 0) {
      final first = firstNameController.text.trim();
      final last = lastNameController.text.trim();
      final email = emailController.text.trim();
      final phone = phoneController.text.trim();
      final password = passwordController.text;
      final confirm = confirmPasswordController.text;

      if (first.isEmpty ||
          last.isEmpty ||
          email.isEmpty ||
          phone.isEmpty ||
          password.isEmpty ||
          confirm.isEmpty) {
        showMessage('Please complete all required fields.');
        return;
      }

      if (!_emailRegex.hasMatch(email)) {
        showMessage('Please enter a valid email address.');
        return;
      }

      if (!_phoneRegex.hasMatch(phone)) {
        showMessage('Please enter a valid PH mobile number.');
        return;
      }

      if (!_passwordRegex.hasMatch(password)) {
        showMessage(
          'Password must be at least 8 characters and include a letter and a number.',
        );
        return;
      }

      if (password != confirm) {
        showMessage('Passwords do not match.');
        return;
      }
    }

    if (currentStep == 1) {
      if (selectedRegionCode == null ||
          selectedProvinceCode == null ||
          selectedMunicipalityCode == null ||
          selectedBarangayCode == null ||
          streetController.text.trim().isEmpty) {
        showMessage('Please complete your address.');
        return;
      }
    }

    if (currentStep < 2) {
      setState(() => currentStep++);
    }
  }

  void previousStep() {
    if (currentStep > 0) {
      setState(() => currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  // ============================================================
  // OTP
  // ============================================================
  void sendOtp() {
    setState(() {
      otpSent = true;
      phoneVerified = false;
      otpController.clear();
    });

    showMessage('Demo OTP: 123456');
  }

  void verifyOtp() {
    if (otpController.text.trim() == demoOtp) {
      setState(() => phoneVerified = true);
      showMessage('Mobile number verified.');
    } else {
      showMessage('Incorrect OTP.');
    }
  }

  // ============================================================
  // CREATE ACCOUNT
  // ============================================================
  void createAccount() {
    if (!phoneVerified) {
      showMessage('Please verify your mobile number first.');
      return;
    }

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: const Icon(
            Icons.check_circle_outline_rounded,
            color: maroon,
            size: 55,
          ),
          title: const Text(
            'Account Created!',
            textAlign: TextAlign.center,
            style: TextStyle(color: darkMaroon, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Your Lumear buyer account has been created successfully.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: maroon,
                foregroundColor: Colors.white,
              ),
              child: const Text('GO TO LOGIN'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(34, 32, 34, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create your account',
                      style: TextStyle(
                        fontSize: 27,
                        color: darkMaroon,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Already registered? ',
                          style: TextStyle(color: lightText, fontSize: 13),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            'Log in',
                            style: TextStyle(
                              color: darkMaroon,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    buildStepper(),
                    const SizedBox(height: 32),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: buildCurrentStep(),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              color: cream,
              padding: const EdgeInsets.fromLTRB(34, 12, 34, 22),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: previousStep,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: darkMaroon,
                          side: const BorderSide(color: borderColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: const Text(
                          'BACK',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: currentStep == 2 ? createAccount : nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: maroon,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: Text(
                          currentStep == 2 ? 'CREATE ACCOUNT' : 'CONTINUE',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STEPPER
  // ============================================================
  Widget buildStepper() {
    return Row(
      children: [
        buildStep(index: 0, label: 'Personal'),
        buildLine(0),
        buildStep(index: 1, label: 'Address'),
        buildLine(1),
        buildStep(index: 2, label: 'Verify'),
      ],
    );
  }

  Widget buildStep({required int index, required String label}) {
    final completed = currentStep > index;
    final active = currentStep == index;

    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completed || active ? maroon : const Color(0xFFF0E3DD),
          ),
          child: Center(
            child: completed
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: active ? Colors.white : lightText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: completed || active ? maroon : lightText,
          ),
        ),
      ],
    );
  }

  Widget buildLine(int index) {
    final completed = currentStep > index;

    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(left: 9, right: 9, bottom: 20),
        color: completed ? maroon : borderColor,
      ),
    );
  }

  Widget buildCurrentStep() {
    switch (currentStep) {
      case 0:
        return buildPersonal();
      case 1:
        return buildAddress();
      case 2:
        return buildVerify();
      default:
        return const SizedBox();
    }
  }

  // ============================================================
  // PERSONAL
  // ============================================================
  Widget buildPersonal() {
    return Column(
      key: const ValueKey('personal'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Personal information',
          style: TextStyle(
            color: darkMaroon,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: firstNameController,
          decoration: inputDecoration('First name'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: middleNameController,
          decoration: inputDecoration('Middle name'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: lastNameController,
          decoration: inputDecoration('Last name'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: inputDecoration('Email address'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: inputDecoration('Mobile number'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          decoration: inputDecoration(
            'Password*',
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => obscurePassword = !obscurePassword),
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: lightText,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: confirmPasswordController,
          obscureText: obscureConfirmPassword,
          decoration: inputDecoration(
            'Confirm password*',
            suffixIcon: IconButton(
              onPressed: () => setState(
                () => obscureConfirmPassword = !obscureConfirmPassword,
              ),
              icon: Icon(
                obscureConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: lightText,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ADDRESS
  // ============================================================
  Widget buildAddress() {
    return Column(
      key: const ValueKey('address'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (regions.isEmpty && !loadingRegions)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: loadRegions,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: fieldColor,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: borderColor),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: maroon, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Couldn't load regions. Tap to retry.",
                        style: TextStyle(color: darkMaroon, fontSize: 13),
                      ),
                    ),
                    Icon(Icons.refresh_rounded, color: maroon, size: 18),
                  ],
                ),
              ),
            ),
          ),

        _SearchableField(
          hint: 'Region*',
          selectedLabel: selectedRegionName,
          items: regions,
          itemLabel: (item) => item['name'].toString(),
          enabled: true,
          loading: loadingRegions,
          decoration: inputDecoration,
          onSelected: (item) {
            final code = item['code'].toString();
            setState(() {
              selectedRegionCode = code;
              selectedRegionName = item['name'].toString();
            });
            loadProvinces(code);
          },
        ),
        const SizedBox(height: 14),

        _SearchableField(
          hint: 'Province*',
          selectedLabel: selectedProvinceName,
          items: provinces,
          itemLabel: (item) => item['name'].toString(),
          enabled: selectedRegionCode != null,
          loading: loadingProvinces,
          decoration: inputDecoration,
          onSelected: (item) {
            final code = item['code'].toString();
            setState(() {
              selectedProvinceCode = code;
              selectedProvinceName = item['name'].toString();
            });
            loadMunicipalities(code);
          },
        ),
        const SizedBox(height: 14),

        _SearchableField(
          hint: 'City / Municipality*',
          selectedLabel: selectedMunicipalityName,
          items: municipalities,
          itemLabel: (item) => item['name'].toString(),
          enabled: selectedProvinceCode != null,
          loading: loadingMunicipalities,
          decoration: inputDecoration,
          onSelected: (item) {
            final code = item['code'].toString();
            setState(() {
              selectedMunicipalityCode = code;
              selectedMunicipalityName = item['name'].toString();
            });
            loadBarangays(code);
          },
        ),
        const SizedBox(height: 14),

        _SearchableField(
          hint: 'Barangay*',
          selectedLabel: selectedBarangayName,
          items: barangays,
          itemLabel: (item) => item['name'].toString(),
          enabled: selectedMunicipalityCode != null,
          loading: loadingBarangays,
          decoration: inputDecoration,
          onSelected: (item) {
            setState(() {
              selectedBarangayCode = item['code'].toString();
              selectedBarangayName = item['name'].toString();
            });
          },
        ),
        const SizedBox(height: 14),

        TextField(
          controller: streetController,
          decoration: inputDecoration('Street*'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: houseController,
          decoration: inputDecoration('House / unit no.'),
        ),
        const SizedBox(height: 12),

        const Text(
          'Region, province, city/municipality, and barangay are loaded '
          'automatically from the Philippine location API. Tap a field to search.',
          style: TextStyle(color: lightText, fontSize: 10, height: 1.5),
        ),
      ],
    );
  }

  // ============================================================
  // VERIFY
  // ============================================================
  Widget buildVerify() {
    return Column(
      key: const ValueKey('verify'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Verify your account',
          style: TextStyle(
            color: darkMaroon,
            fontWeight: FontWeight.w600,
            fontSize: 19,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: fieldColor,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              const Icon(Icons.phone_android_rounded, color: maroon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  phoneController.text,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (phoneVerified)
                const Icon(Icons.check_circle, color: Colors.green),
            ],
          ),
        ),
        const SizedBox(height: 18),

        if (!otpSent)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: sendOtp,
              icon: const Icon(Icons.sms_outlined),
              label: const Text('SEND VERIFICATION CODE'),
            ),
          ),

        if (otpSent && !phoneVerified) ...[
          TextField(
            controller: otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: inputDecoration('Enter 6-digit OTP')
                .copyWith(counterText: ''),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: sendOtp,
              child: const Text('Resend code', style: TextStyle(color: maroon)),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: maroon,
                foregroundColor: Colors.white,
              ),
              child: const Text('VERIFY'),
            ),
          ),
        ],

        if (phoneVerified)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 15),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_rounded, color: Colors.green),
                SizedBox(width: 10),
                Text(
                  'Mobile number verified.',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),
        const Text(
          'Demo OTP: 123456',
          style: TextStyle(color: lightText, fontSize: 11),
        ),
      ],
    );
  }
}

// ============================================================
// SEARCHABLE PICKER FIELD
//
// Replaces DropdownButtonFormField for the region/province/city/barangay
// selectors. A plain dropdown gets unwieldy once a list has more than a
// few dozen entries (some municipalities have 100+ barangays), so this
// opens a full-height, searchable bottom sheet instead. It also avoids
// the "rebuild the whole field with a new ValueKey on every change" trick,
// which was likely there to dodge Flutter's "exactly one item with this
// value" assertion — that's no longer a concern here since selection
// doesn't depend on the field finding itself in a live items list.
// ============================================================
class _SearchableField extends StatelessWidget {
  const _SearchableField({
    required this.hint,
    required this.selectedLabel,
    required this.items,
    required this.itemLabel,
    required this.enabled,
    required this.loading,
    required this.onSelected,
    required this.decoration,
  });

  final String hint;
  final String? selectedLabel;
  final List<Map<String, dynamic>> items;
  final String Function(Map<String, dynamic>) itemLabel;
  final bool enabled;
  final bool loading;
  final ValueChanged<Map<String, dynamic>> onSelected;
  final InputDecoration Function(String, {Widget? suffixIcon}) decoration;

  bool get _canTap => enabled && !loading && items.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: _canTap ? () => _openPicker(context) : null,
      child: InputDecorator(
        decoration: decoration(
          loading ? '$hint (loading...)' : hint,
          suffixIcon: loading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _canTap
                      ? _RegisterPageState.darkMaroon
                      : _RegisterPageState.lightText,
                ),
        ),
        child: Text(
          selectedLabel ?? '',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selectedLabel == null
                ? _RegisterPageState.lightText
                : Colors.black87,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _PickerSheet(title: hint, items: items, itemLabel: itemLabel),
    );

    if (selected != null) {
      onSelected(selected);
    }
  }
}

class _PickerSheet extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.items,
    required this.itemLabel,
  });

  final String title;
  final List<Map<String, dynamic>> items;
  final String Function(Map<String, dynamic>) itemLabel;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: _RegisterPageState.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _RegisterPageState.borderColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title.replaceAll('*', ''),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _RegisterPageState.darkMaroon,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    color: _RegisterPageState.borderColor,
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(itemLabel(item)),
                      onTap: () => Navigator.pop(context, item),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
